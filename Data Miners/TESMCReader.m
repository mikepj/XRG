/*
 * Apple System Management Control (SMC) Tool 
 * Copyright (C) 2006 devnull 
 * Converted 2007 by Thomas Engelmeier
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>
#import "TESMCReader.h"
// #import <CarbonCore/CarbonCore.h>

/* internal defines: */ 

#define KERNEL_INDEX_SMC      2

#define SMC_CMD_READ_BYTES    5
#define SMC_CMD_WRITE_BYTES   6
#define SMC_CMD_READ_INDEX    8
#define SMC_CMD_READ_KEYINFO  9
#define SMC_CMD_READ_PLIMIT   11
#define SMC_CMD_READ_VERS     12

#define DATATYPE_SP78         "sp78"
#define DATATYPE_FPE2         "fpe2"
#define DATATYPE_UINT8        "ui8 "
#define DATATYPE_UINT16       "ui16"
#define DATATYPE_UINT32       "ui32"

typedef struct {
    char                  major;
    char                  minor;
    char                  build;
    char                  reserved[1]; 
    UInt16                release;
} SMCKeyData_vers_t;

typedef struct {
    UInt16                version;
    UInt16                length;
    UInt32                cpuPLimit;
    UInt32                gpuPLimit;
    UInt32                memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    UInt32                dataSize;
    UInt32                dataType;
    char                  dataAttributes;
} SMCKeyData_keyInfo_t;

typedef char              SMCBytes_t[32]; 

typedef struct {
  UInt32                  key; 
  SMCKeyData_vers_t       vers; 
  SMCKeyData_pLimitData_t pLimitData;
  SMCKeyData_keyInfo_t    keyInfo;
  char                    result;
  char                    status;
  char                    data8;
  UInt32                  data32;
  SMCBytes_t              bytes;
} SMCKeyData_t;

typedef char              UInt32Char_t[5];

typedef struct {
  UInt32Char_t            key;
  UInt32                  dataSize;
  UInt32Char_t            dataType;
  SMCBytes_t              bytes;
} SMCVal_t;

/******* end of defines *******/ 

static	NSMutableArray *sCachedTemperatureNames = nil; // init-time buildt collection with "meaningfull" names 
static 	NSMutableArray *sCachedSMCTemperatureLocations = nil; // init-time buildt array with the four-byte SMC keys
static 	NSMutableArray *sCachedSMCUnknownTemperatureLocations = nil; // init-time buildt array with the four-byte SMC keys
static  SMCKeyData_t *sCachedSMCTemperatureKeyData; 

/* plain C functions  */ 

static UInt32 _strtoul(char *str, int size, int base)
{
    UInt32 total = 0;
    int i;

    for (i = 0; i < size; i++)
    {
        if (base == 16)
            total += str[i] << (size - 1 - i) * 8;
        else
           total += ((unsigned char)str[i] << (size - 1 - i) * 8);
	}
	
    return total;
}

static void _ultostr(char *str, UInt32 val)
{
    str[0] = '\0';
    sprintf(str, "%c%c%c%c", 
            (unsigned int) val >> 24,
            (unsigned int) val >> 16,
            (unsigned int) val >> 8,
            (unsigned int) val);
}

kern_return_t SMCOpen( io_connect_t *conn )
{
    kern_return_t result;
    mach_port_t   masterPort;
    io_iterator_t iterator;
    io_object_t   device;

    IOMasterPort(MACH_PORT_NULL, &masterPort);

    CFMutableDictionaryRef matchingDictionary = IOServiceMatching("AppleSMC");
    result = IOServiceGetMatchingServices(masterPort, matchingDictionary, &iterator);
    if (result != kIOReturnSuccess)
    {
        printf("Error: IOServiceGetMatchingServices() = %08x\n", result);
        return 1;
    }

    device = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (device == 0)
    {
        //printf("Error: no SMC found\n");
        return 1;
    }

    result = IOServiceOpen(device, mach_task_self(), 0, conn);
    IOObjectRelease(device);
    if (result != kIOReturnSuccess)
    {
        printf("Error: IOServiceOpen() = %08x\n", result);
        return 1;
    }

    return kIOReturnSuccess;
}

kern_return_t SMCClose( io_connect_t conn )
{
    return IOServiceClose(conn);
}


kern_return_t SMCCall( io_connect_t conn, uint32_t index, SMCKeyData_t *inputStructure, SMCKeyData_t *outputStructure)
{
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
	size_t outStructCount = sizeof(SMCKeyData_t);
	return IOConnectCallStructMethod(conn,
									 index,
									 inputStructure,
									 sizeof(SMCKeyData_t),
									 outputStructure,
									 &outStructCount);
//		return IOConnectCallMethod(conn, index, NULL, 0, inputStructure, structureInputSize, NULL, 0, outputStructure, &structureOutputSize);
#else
    IOItemCount   structureInputSize;
    size_t   structureOutputSize;

    structureInputSize = sizeof(SMCKeyData_t);
    structureOutputSize = sizeof(SMCKeyData_t);
    
    return IOConnectMethodStructureIStructureO(conn,
											   index,
											   structureInputSize,
											   &structureOutputSize,
											   inputStructure,
											   outputStructure);
#endif
	
	/*
	 From:  http://lists.apple.com/archives/Darwin-drivers/2008/Mar/msg00007.html
	 These are deprecated in favor of the IOConnectCall* family of functions.
	 
	 For example, you can go from IOConnectMethodStructureIStructureO to IOConnectCallMethod by doing the following:
	 
	 1. The connect argument becomes the connection argument.
	 2. The index argument becomes the selector argument.
	 3. The input argument becomes an array of the input scalars (NULL in this case).
	 4. inputCnt becomes the number of arguments input.
	 4. The inputStruct argument becomes an array of structs as input
	 5. The inputStructCount argument becomes the number of structs in inputStruct.
	 6. The output argument becomes an array of allocated output scalars.
	 7. The outputCnt argument becomes the number of elements in output.
	 8. The outputStruct argument becomes an array of allocated output structs.
	 9. The outputStructCnt argument is a ptr to the size of the outputStruct input, and is set by the Userclient code to how many structs were placed into outputStruct.
	 
	 IOConnectCallMethod has a number of friends that map to all the deprecated functions; you can find them in IOKitLib.h. In order to use the array method of passing in scalars to these functions, I just create an automatic array of the size of the argument list, and pass it into the functions.
	*/
}

/* refactored SMCReadKey - potentially more efficent caching */ 

kern_return_t SMCPrepareKey( io_connect_t conn, UInt32Char_t key, SMCKeyData_t *outputStructureP)
{
    kern_return_t result;
    SMCKeyData_t  inputStructure;

    memset(&inputStructure, 0, sizeof(SMCKeyData_t));
    memset(outputStructureP, 0, sizeof(SMCKeyData_t));
    // memset(val, 0, sizeof(SMCVal_t));

    inputStructure.key = _strtoul(key, 4, 16);
    // sprintf(val->key, key);
    inputStructure.data8 = SMC_CMD_READ_KEYINFO;    

    result = SMCCall( conn, KERNEL_INDEX_SMC, &inputStructure, outputStructureP );
	outputStructureP->key = inputStructure.key;
	outputStructureP->data8 = SMC_CMD_READ_BYTES;
    // if (result != kIOReturnSuccess)
	return result;
}

kern_return_t SMCReadPreparedKey( io_connect_t conn, SMCKeyData_t *inputStructureP, SMCVal_t *val)
{
    kern_return_t result;
    SMCKeyData_t  outputStructure;
	memset(&outputStructure, 0, sizeof(SMCKeyData_t));
    memset(val, 0, sizeof(SMCVal_t));

    snprintf(val->key, 4, "%s", (char *)&inputStructureP->key);
  
    val->dataSize = inputStructureP->keyInfo.dataSize;
    _ultostr(val->dataType, inputStructureP->keyInfo.dataType);
    
    result = SMCCall(conn, KERNEL_INDEX_SMC, inputStructureP, &outputStructure);
    if (result != kIOReturnSuccess)
        return result;

    memcpy(val->bytes, outputStructure.bytes, sizeof(outputStructure.bytes));

    return kIOReturnSuccess;
}


kern_return_t SMCReadKey( io_connect_t conn, UInt32Char_t key, SMCVal_t *val)
{
    kern_return_t result;
    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;

    memset(&inputStructure, 0, sizeof(SMCKeyData_t));
    memset(&outputStructure, 0, sizeof(SMCKeyData_t));
    memset(val, 0, sizeof(SMCVal_t));

    inputStructure.key = _strtoul(key, 4, 16);
    sprintf(val->key, "%s", key);
    inputStructure.data8 = SMC_CMD_READ_KEYINFO;    

    result = SMCCall( conn, KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
    if (result != kIOReturnSuccess)
        return result;

    val->dataSize = outputStructure.keyInfo.dataSize;
    _ultostr(val->dataType, outputStructure.keyInfo.dataType);
    inputStructure.keyInfo.dataSize = val->dataSize;
    inputStructure.data8 = SMC_CMD_READ_BYTES;

    result = SMCCall(conn, KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
    if (result != kIOReturnSuccess)
        return result;

    memcpy(val->bytes, outputStructure.bytes, sizeof(outputStructure.bytes));

    return kIOReturnSuccess;
}

kern_return_t SMCWriteKey(io_connect_t conn, SMCVal_t writeVal)
{
    kern_return_t result;
    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;

    SMCVal_t      readVal;

    result = SMCReadKey(conn, writeVal.key, &readVal);
    if (result != kIOReturnSuccess) 
        return result;

    if (readVal.dataSize != writeVal.dataSize)
        return kIOReturnError;

    memset(&inputStructure, 0, sizeof(SMCKeyData_t));
    memset(&outputStructure, 0, sizeof(SMCKeyData_t));

    inputStructure.key = _strtoul(writeVal.key, 4, 16);
    inputStructure.data8 = SMC_CMD_WRITE_BYTES;    
    inputStructure.keyInfo.dataSize = writeVal.dataSize;
    memcpy(inputStructure.bytes, writeVal.bytes, sizeof(writeVal.bytes));

    result = SMCCall(conn, KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
    if (result != kIOReturnSuccess)
        return result;
 
    return kIOReturnSuccess;
}

UInt32 SMCReadIndexCount( io_connect_t conn )
{
    SMCVal_t val;
    SMCReadKey(conn, "#KEY", &val);
	
    UInt32 retval = _strtoul(val.bytes, val.dataSize, 10);
	return retval;
}

/*
// array with all known values
static NSArray *sKnownSMCTemperatureValues;
static NSDictionary *sKnownTemperatureLocations;
// array with temperatures that have no known name 
static NSArray *sUnknownSMCTemperatureValues;
*/

@implementation TESMCReader

- (void) buildTemperatureCache {
	kern_return_t result;
    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;

    int           i;
    UInt32Char_t  key;
    SMCVal_t      val;	
		
	if( sCachedTemperatureNames || sCachedSMCTemperatureLocations || sCachedSMCUnknownTemperatureLocations )
		return;
		
	sCachedTemperatureNames = [[NSMutableArray alloc] init];
	sCachedSMCTemperatureLocations = [[NSMutableArray alloc] init];
	sCachedSMCUnknownTemperatureLocations = [[NSMutableArray alloc] init];
	free( (void *) sCachedSMCTemperatureKeyData );

	int smcKeyCount = SMCReadIndexCount( conn );

	// traverse the available keys, prepare them for sorting
	NSMutableArray *sortedKeys = [NSMutableArray arrayWithCapacity:smcKeyCount];
	for(i = 0; i < smcKeyCount; i++) {
		memset(&outputStructure, 0, sizeof(SMCKeyData_t));
        memset(&val, 0, sizeof(SMCVal_t));

        inputStructure.data8 = SMC_CMD_READ_INDEX;
        inputStructure.data32 = i;

        result = SMCCall(conn, KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
        if (result != kIOReturnSuccess) {
			NSLog(@"error result: %d", result);
            continue;
		}

        _ultostr(key, outputStructure.key); 
	
		NSString *smcKeyString = [NSString stringWithCString:key encoding: NSMacOSRomanStringEncoding];
		[sortedKeys addObject:smcKeyString];
	}	
	[sortedKeys sortUsingSelector:@selector(compare:)];
	
	//NSLog(@"Sorted Keys: %@", sortedKeys);
	
	// now they are sorted. distribute them to the arrays of known and unknown keynames  
	for (i = 0; i < [sortedKeys count]; i++) {
		NSString *currentKey = [sortedKeys objectAtIndex:i];

		char keyChar[5];
		[currentKey getCString:keyChar maxLength:5 encoding:NSMacOSRomanStringEncoding];
		
		NSData *smcKeyData = [NSData dataWithBytes:keyChar length:4];
		
		NSString *smcLocationName = nil;
		int keyIndex;
		
		if (keyChar[0] != 'T') { continue; /* Optimization */ }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TA?P"])) { smcLocationName = @"Ambient "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TB?T"])) { smcLocationName = @"Bottom Sensor "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TC?D"])) { smcLocationName = @"CPU Die "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TC?H"])) { smcLocationName = @"CPU Die "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TC?P"])) { smcLocationName = @"Memory Controller "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TG?D"])) { smcLocationName = @"GPU Diode "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TG?H"])) { smcLocationName = @"GPU Heatsink "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TG?P"])) { smcLocationName = @"GPU "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TH?P"])) { smcLocationName = @"Hard Drive "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"Th?H"])) { smcLocationName = @"Heatsink "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TM?P"])) { smcLocationName = @"Memory "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TM?S"])) { smcLocationName = @"Memory "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"Tm?P"])) { smcLocationName = @"Memory "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TMA?"])) { smcLocationName = @"DIMM A"; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TMB?"])) { smcLocationName = @"DIMM B"; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TN?D"])) { smcLocationName = @"Northbridge Diode "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TN?H"])) { smcLocationName = @"Northbridge Heatsink "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TN?P"])) { smcLocationName = @"Northbridge "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TO?P"])) { smcLocationName = @"Optical Drive "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"Tp?C"])) { smcLocationName = @"Power Supply "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"Tp?P"])) { smcLocationName = @"Power Supply "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TS?C"])) { smcLocationName = @"Expansion Slots "; }
		else if (0 <= (keyIndex = [self c4String:keyChar matchesPattern:"TW?P"])) { smcLocationName = @"Airport "; }
		
		if (smcLocationName) {
			// Figure out if we should add a digit (only if there are more than one with this name).
			BOOL appendDigit = NO;
			if (keyIndex < 100)	{
				if ([currentKey rangeOfString:@"0"].location != NSNotFound) {
					NSMutableString *nextKey = [NSMutableString stringWithString:currentKey];
					[nextKey replaceOccurrencesOfString:@"0" withString:@"1" options:0 range:NSMakeRange(0, [nextKey length])];
					if ([sortedKeys containsObject:nextKey]) {
						appendDigit = YES;
					}
				}
				else {
					appendDigit = YES;
				}
			}

			if (appendDigit) smcLocationName = [NSString stringWithFormat:@"%@%i", smcLocationName, keyIndex];
			else if ([smcLocationName hasSuffix:@" "]) smcLocationName = [smcLocationName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			
			[sCachedSMCTemperatureLocations addObject:smcKeyData];
			[sCachedTemperatureNames addObject:smcLocationName];
		}
		else {
			[sCachedSMCUnknownTemperatureLocations addObject:smcKeyData];
		}
	}
	
	// another cache addition: add keydata structs to retrieve more efficient..
	sCachedSMCTemperatureKeyData = calloc( [sCachedSMCTemperatureLocations count], sizeof( SMCKeyData_t ));
	for( i = 0; i < [sCachedSMCTemperatureLocations count]; ++i  )
	{
		SMCKeyData_t *keyData = sCachedSMCTemperatureKeyData + i;
		SMCPrepareKey( conn,(char *)[[sCachedSMCTemperatureLocations objectAtIndex:i] bytes], keyData );
	}	
}

// Returns -1 if no match, 100 if match, and 0-9 if a pattern digit is matched.  Input strings better be 4 characters long!
- (int) c4String:(char *)string matchesPattern:(char *)pattern {
	int retVal = -1;
	int length = 4;
	if (strlen(string) != length || strlen(pattern) != length) return -1;

	retVal = 100;
	int i;
	for (i = 0; i < length; i++) {
		if (pattern[i] == '?') {
			// Found a wildard, set the ret val and go on to the next index.
			if (string[i] >= '0' && string[i] <= '9') retVal = string[i] - '0';
			else if (string[i] >= 'a' && string[i] <= 'f') retVal = string[i] - 'a';
			else if (string[i] >= 'A' && string[i] <= 'F') retVal = string[i] - 'A';
			else return -1;
			continue;
		}
		else if (pattern[i] == string[i]) {
			// Character matched, go on to the next index.
			continue;
		}
		else {
			// This character didn't match.
			return -1;
		}
	}
	
	return retVal;
}

- (id) init
{
	self = [super init];
	
	if( self )
	{
		SMCOpen( &conn );
		[self buildTemperatureCache];	
	}
	return self;
}

- (void) dealloc
{
	SMCClose( conn );
	[super dealloc];
}

- (void) reset {
	SMCClose(conn);
	SMCOpen(&conn);
}

- (NSNumber *)floatNumberFromSP78:(SMCVal_t) val
{
	float temp = ((val.bytes[0] * 256 + val.bytes[1]) >> 2)/64.; 	
	return [NSNumber numberWithFloat:temp];  
}

- (NSNumber *)floatNumberFromFPE2:(SMCVal_t) val
{
	int e = 2; // exponent
    float total = 0;
    int i;

    for (i = 0; i < val.dataSize; i++)
    {
        if (i == (val.dataSize - 1))
           total += (val.bytes[i] & 0xff) >> e;
        else
           total += val.bytes[i] << (val.dataSize - 1 - i) * (8 - e);
    }

    return [NSNumber numberWithFloat:total];
}

 
- (NSNumber *)intNumberFromSMC:(SMCVal_t) val
{
    return [NSNumber numberWithUnsignedInt:(unsigned int) _strtoul(val.bytes, val.dataSize, 10)];
}

- (NSData *)dataFromSMC:(SMCVal_t) val
{
	return [NSData dataWithBytes:val.bytes length:val.dataSize];
}

- (id) objectForValue:(SMCVal_t) val
{
	id result = nil;
	 if (val.dataSize > 0)
    {
        if ((strcmp(val.dataType, DATATYPE_UINT8) == 0) ||
            (strcmp(val.dataType, DATATYPE_UINT16) == 0) ||
            (strcmp(val.dataType, DATATYPE_UINT32) == 0))
            result = [self intNumberFromSMC:val];
        else if (strcmp(val.dataType, DATATYPE_FPE2) == 0)
			result = [self floatNumberFromFPE2:val];
		else if (strcmp(val.dataType, DATATYPE_SP78) == 0)
			result = [self floatNumberFromSP78:val];
		else
			result = [self dataFromSMC:val];
        // printBytesHex(val);
    }
    else
    {
            printf("no data\n");
    }
	return result;

}
- (void) addValue:(SMCVal_t) val toDictionary:(NSMutableDictionary *) dict 
{
	NSString *key = [NSString stringWithFormat:@"%-4s", val.key ];
	[dict setValue:[self objectForValue:val] forKey:key];
}



- (UInt32) SMCReadIndexCount
{
    SMCVal_t val;

    SMCReadKey(conn, "#KEY", &val);
    return _strtoul(val.bytes, val.dataSize, 10);
}

- (NSDictionary *)allValues
{
    kern_return_t result;
    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;

    int           totalKeys, i;
    UInt32Char_t  key;
    SMCVal_t      val;

	SMCOpen(&conn);
	
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    totalKeys = [self SMCReadIndexCount];
    for (i = 0; i < totalKeys; i++)
    {
        memset(&inputStructure, 0, sizeof(SMCKeyData_t));
        memset(&outputStructure, 0, sizeof(SMCKeyData_t));
        memset(&val, 0, sizeof(SMCVal_t));

        inputStructure.data8 = SMC_CMD_READ_INDEX;
        inputStructure.data32 = i;

        result = SMCCall(conn, KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
        if (result != kIOReturnSuccess)
            continue;

        _ultostr(key, outputStructure.key); 

        SMCReadKey(conn, key, &val);
		[self addValue:val toDictionary:dict]; 
      //   printVal(val);
    }
	SMCClose( conn);

    return dict;
}

- (NSDictionary *) sensorValues
{ // try to gather the motion sensor values:
  // see some linux on mac sources
	SMCVal_t      val;
	NSMutableDictionary *values = [NSMutableDictionary dictionary];

	SMCReadKey(conn, "ALV0", &val); 
	if( val.dataSize )
		[values setObject:[self objectForValue:val] forKey:@"LightSensor Left"];
	
	SMCReadKey(conn, "ALV1", &val); 
	if( val.dataSize )
		[values setObject:[self objectForValue:val] forKey:@"LightSensor Right"];
	
// #define BACKLIGHT_KEY 		"LKSB" /* w-o */

	SMCReadKey(conn, "MSLD", &val); 
	if( val.dataSize )
		[values setObject:[self objectForValue:val] forKey:@"Clamshell"];

	SMCReadKey(conn, "MO_X", &val); 
	if( val.dataSize )
		[values setObject:[self objectForValue:val] forKey:@"Motion-X"];
	
	SMCReadKey(conn, "MO_Y", &val); 
	if( val.dataSize )
		[values setObject:[self objectForValue:val] forKey:@"Motion-Y"];

	SMCReadKey(conn, "MO_Z", &val); 
	if( val.dataSize )
		[values setObject:[self objectForValue:val] forKey:@"Motion-Z"];
	
	SMCReadKey(conn, "MOCN", &val); 
	if( val.dataSize )	
		[values setObject:[self objectForValue:val] forKey:@"Motion"];
	return values;
}

- (NSDictionary *) temperatureValuesExtended:(BOOL) includeUnknownSensors
{
	SMCVal_t      val;
	// NSString	  *key; 
	NSMutableDictionary *values = nil;
	NSMutableArray *temperatures = [NSMutableArray arrayWithCapacity:[sCachedSMCTemperatureLocations count]];
	int i;
	
	for( i = 0; i < [sCachedSMCTemperatureLocations count]; ++i  )
	{
		SMCReadPreparedKey(conn, sCachedSMCTemperatureKeyData + i, &val );
		[temperatures addObject:[self objectForValue:val]];
	}
	
	values = [[[NSMutableDictionary alloc] initWithObjects:temperatures forKeys:sCachedTemperatureNames] autorelease];
	
	if( includeUnknownSensors )
	{
		for ( i = 0; i < [sCachedSMCUnknownTemperatureLocations count]; ++i) {
			NSData *currentKey = [sCachedSMCUnknownTemperatureLocations objectAtIndex:i];
			SMCReadKey(conn, (char *)[currentKey bytes], &val);
			
			NSString *vkey = [[[NSString alloc] initWithBytes:[currentKey bytes] length:4 encoding:NSASCIIStringEncoding] autorelease];
			[values setObject:[self objectForValue:val] forKey:vkey];
		}
	}

	return values;
}



- (NSDictionary *) fanValues
{
    kern_return_t result;
    SMCVal_t      val;
    UInt32Char_t  smc_key;
    int           totalFans, i;
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	
    result = SMCReadKey(conn, "FNum", &val);
    if (result != kIOReturnSuccess)
        return nil;

    totalFans = _strtoul(val.bytes, val.dataSize, 10); 
    //NSLog(@"Total fans in system: %d\n", totalFans);

    for (i = 0; i < totalFans; i++)
    {
		NSMutableString *key = [NSString stringWithFormat:@"Fan%d", i];
		NSMutableDictionary *values = [NSMutableDictionary dictionaryWithCapacity:5];
		
		int fanNum = i;
		char fanNumChar = (fanNum >= 10) ? 'A' + fanNum - 10 : '0' + fanNum;
		
		sprintf(smc_key, "F%cAc", fanNumChar);
        SMCReadKey(conn, smc_key, &val); 
		[values setObject:[self floatNumberFromFPE2:val] forKey:@"Speed"];
		
        sprintf(smc_key, "F%cMn", fanNumChar); 
        SMCReadKey(conn, smc_key, &val);
		[values setObject:[self floatNumberFromFPE2:val] forKey:@"MinSpeed"];
		
        sprintf(smc_key, "F%cMx", fanNumChar);   
        SMCReadKey(conn, smc_key, &val);
		[values setObject:[self floatNumberFromFPE2:val] forKey:@"MaxSpeed"];       
		
		sprintf(smc_key, "F%cSf", fanNumChar);   
        SMCReadKey(conn, smc_key, &val);
		[values setObject:[self floatNumberFromFPE2:val] forKey:@"SafeSpeed"]; 
		      
        sprintf(smc_key, "F%cTg", fanNumChar);   
        SMCReadKey(conn, smc_key, &val);
		[values setObject:[self floatNumberFromFPE2:val] forKey:@"TargetSpeed"];       

        SMCReadKey(conn, "FS! ", &val);
		Boolean isAutomatic = ((_strtoul(val.bytes, 2, 16) & (1 << i)) == 0);
		[values setObject:[NSNumber numberWithBool:!isAutomatic] forKey:@"ForcedSpeed"];    
		[dict setObject:values forKey:key];   
    }

    return dict;
}

@end
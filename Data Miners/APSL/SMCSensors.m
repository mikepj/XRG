/*
 * Copyright (c) 2012 CodeExchange All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */


#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#import <Cocoa/Cocoa.h>
#import "SMCSensors.h"
#import "SMCInterface.h"

@interface SMCSensors()
- (int) c4String:(char *)string matchesPattern:(const char *)pattern;
- (void) buildKeyCache;
- (BOOL) readSMCValues:(NSSet *) smcKeys toDictionary:(NSMutableDictionary *) destDict;
- (NSString *) dictKeyFromInt:(uint32_t) key;
- (uint32_t) keyFromString:(NSString *) key;
@end

typedef NS_ENUM(int, DescriptionMatch_t) {
    kNoMatch = -1,
    kDirectMatch = 0x100
}; 

@implementation SMCSensors

- (instancetype) init
{
	self = [super init];
	
	if( self )
	{
		smc_ = [[SMCInterface alloc] init];
		
		// see <http://www.parhelia.ch/blog/statics/k3_keys.html>
		self.sKnownDescriptions = @{
									@"TA?P": @"Ambient",
									@"TB?T": @"Bottom Sensor",
									@"TC?D": @"CPU Die",
									@"TC?H": @"CPU Heatsink",
									@"TC?P": @"CPU Proximity",
									@"TG?D": @"GPU Die",
									@"TG?H": @"GPU Heatsink",
									@"TG?P": @"GPU Proximity",
									@"TH?P": @"HD Proximity",
									@"Th?H": @"Heatsink",
									@"TI?P": @"Thunderbolt",
									@"TL?P": @"LCD Proximity",
									@"TM?P": @"Memory Proximity",
									@"TM?S": @"Memory",
									@"Tm?P": @"Misc. local",
									@"TMA?": @"DIMM A",
									@"TMB?": @"DIMM B",
									@"TN?D": @"Northbridge Die",
									@"TN?H": @"Northbridge Heatsink",
									@"TN?P": @"Northbridge Proximity",
									@"TO?P": @"Optical Drive",
									@"TL?P": @"LCD",
									@"Tp?C": @"Power Supply",
									@"Tp?P": @"Power Supply",
									@"Ts?P": @"Palm Rest",
									@"TS?C": @"Expansion Slot",
									@"TW?P": @"Airport",
									// sensors:
									@"ALV0": @"Ambient Light Left",
									@"ALV1": @"Ambient Light Right",
									@"MSLD": @"Clamshell",
									@"MO_X": @"Motion-X",
									@"MO_Y": @"Motion-Y",
									@"MO_Z": @"Motion-Z",
									@"MOCN": @"Motion",
									// Noise: (sourced from http://www.assembla.com/spaces/fakesmc/wiki/Known_SMC_Keys/history )
									@"dBA?": @"Noise near Fan",
									@"dBAH": @"Noise near HD",
									@"dBAT": @"Total Noise",
									// Fans:
									@"F?Ac": @"Fan Speed",
									@"F?Mn": @"Fan Minimum Speed",
									@"F?Mx": @"Fan Maximum Speed",
									@"F?Sf": @"Fan Safe Speed",
									@"F?Mt": @"Fan Maximum Target",
									@"F?Tg": @"Fan Target Speed",
									@"FS! ": @"Fan Forced Speed",
									};
		
		[self buildKeyCache];
	}
	return self;
}



- (NSString *) humanReadableNameForKey:(NSString *)key {
    NSString *result = [keyDescriptions_ valueForKey:key];
    return result ? result : key;
}

- (NSDictionary *) temperatureValuesExtended:(BOOL) includeUnknownSensors
{
	NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];
    [self readSMCValues:knownTemperatureKeys_ toDictionary:resultDict];
    if( includeUnknownSensors ) {
        [self readSMCValues:unknownTemperatureKeys_ toDictionary:resultDict];
    }
    return resultDict;
}

- (NSDictionary *) fanValues
{
    uint32_t      forcedBits;
    NSError *error = nil;
    
	NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];
	// totalFans = [[smc_ readValue:'FNum' error:&error] intValue];
    
    forcedBits = [[smc_ readValue:'FS! ' error:&error] intValue]; // Value is base 16!?!
    
    for( NSString *fanIndexString in [fanDescriptions_ allKeys] ) {
        int fanIndex = [fanIndexString intValue];
        NSMutableDictionary *fanDict = [NSMutableDictionary dictionary];
        [resultDict setValue:fanDict forKey:[NSString stringWithFormat:@"Fan #%d", fanIndex]];
        
        NSSet *smcKeys = fanDescriptions_[fanIndexString];
        [self readSMCValues:smcKeys toDictionary:fanDict];
        fanDict[@"Forced"] = [NSNumber numberWithBool:(forcedBits & (1 << fanIndex))];
    }
    return resultDict;
}

- (NSDictionary *)allValues
{
    NSInteger     totalKeys, i;
    uint32_t      key;
  
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    totalKeys = [smc_ keyCount];
    for (i = 0; i < totalKeys; i++)
    {
        key = [smc_ keyAtIndex:i];
        id value = [smc_ readValue:key error:nil];
        if( value )
            [dict setValue:value forKey:[self dictKeyFromInt:key]]; 
    }    
    return dict;
}


- (NSDictionary *) sensorValues
{ // try to gather the motion sensor values:

	NSMutableDictionary *values = [NSMutableDictionary dictionary];
    NSError *error;
    
    [values setValue:[smc_ readValue:'ALV0' error:&error] forKey:@"ALV0"];
	[values setValue:[smc_ readValue:'ALV1' error:&error] forKey:@"ALV1"];
	[values setValue:[smc_ readValue:'MSLD' error:&error] forKey:@"MSLD"];
    [values setValue:[smc_ readValue:'MO_X' error:&error] forKey:@"MO_X"];
    [values setValue:[smc_ readValue:'MO_Y' error:&error] forKey:@"MO_Y"];
    [values setValue:[smc_ readValue:'MO_Z' error:&error] forKey:@"MO_Z"];
    [values setValue:[smc_ readValue:'MOCN' error:&error] forKey:@"MOCN"];
	return values;
}

#pragma mark -
#pragma mark internal

- (void) buildKeyCache {
    int           i;
		
    NSMutableDictionary *descriptions = [NSMutableDictionary dictionary];
    NSMutableDictionary *fanDescriptions = [NSMutableDictionary dictionary];
    NSMutableSet *unknownTempKeys = [NSMutableSet set];
    NSMutableSet *knownTempKeys = [NSMutableSet set];
    
	NSInteger smcKeyCount = [smc_ keyCount];
    NSMutableSet *availableKeys = [NSMutableSet setWithCapacity:smcKeyCount];

	// traverse the available keys, prepare them for sorting
	for(i = 0; i < smcKeyCount; i++) {
        uint32_t key = [smc_ keyAtIndex:i];
			
		NSString *smcKeyString = [self dictKeyFromInt:key];
		[availableKeys addObject:smcKeyString];
	}	
    
    // now set up description lookup:
    for( NSString *currentKey in availableKeys ) {
		char keyChar[5] = "";
        NSString *smcLocationName = nil;
		int keyIndex;
        BOOL isFanKey, isTemperatureKey;
        
		[currentKey getCString:keyChar maxLength:5 encoding:NSASCIIStringEncoding];
        
        isFanKey = keyChar[0] == 'F' && isdigit( keyChar[1] );
        isTemperatureKey = keyChar[0] == 'T';
		
		for (NSString *key in [self.sKnownDescriptions allKeys]) {
			keyIndex = [self c4String:keyChar matchesPattern:[key UTF8String]];
			if (keyIndex != kNoMatch) {
				smcLocationName = self.sKnownDescriptions[key];
				break;
			}
		}
		
		if (smcLocationName) {
			// Figure out if we should add a digit (only if there are more than one with this name).
			BOOL appendIndexToDescription = NO;
            if ( !isFanKey ) {
                if (keyIndex == 0  )	{
                    // if the key is of form XXX0, see if there is also XXX1
                    if ([currentKey rangeOfString:@"0"].location != NSNotFound) { // should assert on that...
                        NSMutableString *keyForNextItem = [NSMutableString stringWithString:currentKey];
                        [keyForNextItem replaceOccurrencesOfString:@"0" withString:@"1" options:0 range:NSMakeRange(0, [keyForNextItem length])];
                        if ([availableKeys containsObject:keyForNextItem]) {
                            appendIndexToDescription = YES;
                        }
                    } 
                    
                } else if (keyIndex != kDirectMatch) {
                    appendIndexToDescription = YES;
                }
            }
			if (appendIndexToDescription) smcLocationName = [NSString stringWithFormat:@"%@ #%d", smcLocationName, keyIndex];
		}
        
        if( smcLocationName ) {
            [descriptions setValue:smcLocationName forKey:currentKey];
        }
        
        if( isTemperatureKey ) {
            if( smcLocationName ) {
                [knownTempKeys addObject:currentKey];
            } else {
                [unknownTempKeys addObject:currentKey];
            }
        } else if ( isFanKey ) {
            NSString *fanKey = [NSString stringWithFormat:@"%c", keyChar[1]];
            NSMutableArray *fanValues = fanDescriptions[fanKey];
            if( !fanValues ) {
                fanValues = [NSMutableArray arrayWithCapacity:5];
                [fanDescriptions setValue:fanValues forKey:fanKey];
            }
            [fanValues addObject:currentKey];
        }
	}	
    
    keyDescriptions_ = descriptions;
    unknownTemperatureKeys_ = unknownTempKeys;
    knownTemperatureKeys_ = knownTempKeys;
    fanDescriptions_ = fanDescriptions;
}

- (NSString *) dictKeyFromInt:(uint32_t) key {
    return [NSString stringWithFormat:@"%c%c%c%c", 
            ((key >> 24) & 0xff), 
            ((key >> 16) & 0xff), 
            ((key >> 8) & 0xff),  
            (key & 0xff)];
}

- (uint32_t) keyFromString:(NSString *) key {
    uint32_t result = 0L;
    for( int i = 0; i < 4; ++i ) {
        result <<= 8;
        result += [key characterAtIndex:i];
    }
    return result;
}

// Returns 
// - kNoMatch if no match, 
// - kDirectMatch if match, 
// - 0-15 if a pattern digit is matched.  Input strings better be 4 characters long!

- (int) c4String:(char *)string matchesPattern:(const char *)pattern {
	DescriptionMatch_t retVal = kNoMatch;
	int length = 4;
	if (strlen(string) != length || strlen(pattern) != length) 
        return kNoMatch;

	retVal = kDirectMatch;
	int i;
	for (i = 0; i < length; i++) {
		if (pattern[i] == '?') {
			// Found a wildard, set the ret val and go on to the next index.
			if (string[i] >= '0' && string[i] <= '9') 
                retVal = string[i] - '0';
			else if (string[i] >= 'a' && string[i] <= 'f') 
                retVal = string[i] - 'a' + 10;
			else if (string[i] >= 'A' && string[i] <= 'F') 
                retVal = string[i] - 'A' + 10;
			else 
                return kNoMatch;
			continue;
		}
		else if (pattern[i] == string[i]) {
			// Character matched, go on to the next index.
			continue;
		}
		else {
			// This character didn't match.
			return kNoMatch;
		}
	}
	return retVal;
}

- (BOOL) readSMCValues:(NSSet *) smcKeys toDictionary:(NSMutableDictionary *) destDict
{
    NSError *error = nil; 
    BOOL success = YES;
    
    for( NSString *aKey in smcKeys  ) {
        id value = [smc_ readValue:[self keyFromString:aKey] error:&error];
        if( !error ) {
            destDict[aKey] = value;
        } else {
            success = NO;
        }
    }
    return success;
}

@end
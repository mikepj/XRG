/*
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2012 Gaucho Software, LLC.
 * You can view the complete license in the LICENSE file in the root
 * of the source tree.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 */

//
//  XRGGraphicsMiner.m
//

#import "XRGGPUMiner.h"
#import <IOKit/graphics/IOGraphicsLib.h>

@implementation XRGGPUMiner

- (instancetype)init {
	self = [super init];
	if (self) {
		_totalVRAMDataSets = nil;
		_freeVRAMDataSets = nil;
		_cpuWaitDataSets = nil;
		self.numSamples = 0;
		self.numberOfGPUs = 0;
		
		[self setNumberOfGPUs:1];
		[self getLatestGraphicsInfo];
	}
	
	return self;
}


- (void)setDataSize:(NSInteger)newNumSamples {
	if (newNumSamples < 0) return;
	
	for (XRGDataSet *values in self.totalVRAMDataSets) {
		[values resize:newNumSamples];
	}
	for (XRGDataSet *values in self.freeVRAMDataSets) {
		[values resize:newNumSamples];
	}
	for (XRGDataSet *values in self.cpuWaitDataSets) {
		[values resize:newNumSamples];
	}
	
	self.numSamples = newNumSamples;
}

- (void)setNumberOfGPUs:(NSInteger)newNumGPUs {
	if ((self.totalVRAMDataSets.count == newNumGPUs) &&
		(self.freeVRAMDataSets.count == newNumGPUs) &&
		(self.cpuWaitDataSets.count == newNumGPUs))
	{
		return;
	}
	
	NSMutableArray *newTotal = [NSMutableArray array];
	NSMutableArray *newFree = [NSMutableArray array];
	NSMutableArray *newCPUWait = [NSMutableArray array];
	
	if (self.totalVRAMDataSets.count) [newTotal addObjectsFromArray:self.totalVRAMDataSets];
	if (self.freeVRAMDataSets.count) [newFree addObjectsFromArray:self.freeVRAMDataSets];
	if (self.cpuWaitDataSets.count) [newCPUWait addObjectsFromArray:self.cpuWaitDataSets];
	
	// Make sure we want at least 1 sample.
	self.numSamples = MAX(1, self.numSamples);
	
	// Add new XRGDataSets if needed.
	for (NSInteger i = 0; i < newNumGPUs; i++) {
		if (newTotal.count <= i) {
			XRGDataSet *s = [[XRGDataSet alloc] init];
			[s resize:self.numSamples];
			[newTotal addObject:s];
		}
		if (newFree.count <= i) {
			XRGDataSet *s = [[XRGDataSet alloc] init];
			[s resize:self.numSamples];
			[newFree addObject:s];
		}
		if (newCPUWait.count <= i) {
			XRGDataSet *s = [[XRGDataSet alloc] init];
			[s resize:self.numSamples];
			[newCPUWait addObject:s];
		}
	}

	// Remove extra XRGDataSets if needed.
	if (newTotal.count > newNumGPUs) {
		newTotal = [NSMutableArray arrayWithArray:[newTotal subarrayWithRange:NSMakeRange(0, newNumGPUs)]];
	}
	if (newFree.count > newNumGPUs) {
		newFree = [NSMutableArray arrayWithArray:[newFree subarrayWithRange:NSMakeRange(0, newNumGPUs)]];
	}
	if (newCPUWait.count > newNumGPUs) {
		newCPUWait = [NSMutableArray arrayWithArray:[newCPUWait subarrayWithRange:NSMakeRange(0, newNumGPUs)]];
	}
	
	_totalVRAMDataSets = newTotal;
	_freeVRAMDataSets = newFree;
	_cpuWaitDataSets = newCPUWait;
	
	self.numberOfGPUs = newNumGPUs;
}

- (void)getLatestGraphicsInfo {
	// Create an iterator
	io_iterator_t iterator;
	
	NSMutableArray *accelerators = [NSMutableArray array];
	NSMutableArray *pciDevices = [NSMutableArray array];
	
	if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(kIOAcceleratorClassName), &iterator) == kIOReturnSuccess) {
		// Iterator for devices found
		io_registry_entry_t regEntry;
		
		while ((regEntry = IOIteratorNext(iterator))) {
			// Put this services object into a dictionary object.
			CFMutableDictionaryRef serviceDictionary;
			if (IORegistryEntryCreateCFProperties(regEntry, &serviceDictionary, kCFAllocatorDefault, kNilOptions) != kIOReturnSuccess) {
				// Service dictionary creation failed.
				IOObjectRelease(regEntry);
				continue;
			}
			
			[accelerators addObject:[(__bridge NSDictionary *)serviceDictionary copy]];
			
			CFRelease(serviceDictionary);
			IOObjectRelease(regEntry);
		}
		IOObjectRelease(iterator);
	}
	
	if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOPCIDevice"), &iterator) == kIOReturnSuccess) {
		io_registry_entry_t serviceObject;
		while ((serviceObject = IOIteratorNext(iterator))) {
			// Put this services object into a CF Dictionary object.
			CFMutableDictionaryRef serviceDictionary;
			if (IORegistryEntryCreateCFProperties(serviceObject, &serviceDictionary, kCFAllocatorDefault, kNilOptions) != kIOReturnSuccess) {
				IOObjectRelease(serviceObject);
				continue;
			}
			
			// Check if this is a GPU listing.
			const void *model = CFDictionaryGetValue(serviceDictionary, @"model");
			if (model != nil) {
				if (CFGetTypeID(model) == CFDataGetTypeID()) {
					[pciDevices addObject:[(__bridge NSDictionary *)serviceDictionary copy]];
				}
			}
			
			CFRelease(serviceDictionary);
			IOObjectRelease(serviceObject);
		}
		
		IOObjectRelease(iterator);
	}
	
	NSInteger numValues = MIN(pciDevices.count, accelerators.count);

	NSMutableArray *graphicsCards = [NSMutableArray array];		// An array of XRGGraphicsCard objects.
	NSMutableIndexSet *pciIndicesUsed = [[NSMutableIndexSet alloc] init];
	NSMutableIndexSet *accelIndicesUsed = [[NSMutableIndexSet alloc] init];
	for (NSInteger i = 0; i < numValues; i++) {
		// Most of the time, pciDevices[i] will match accelerators[i].  But sometimes this isn't the case.
		// Try to detect if this is happening and compensate for it.
		NSDictionary *pciD = pciDevices[i];
		NSDictionary *accelD = accelerators[i];
		if ([XRGGraphicsCard matchingPCIDevice:pciD accelerator:accelD]) {
			// Matched.  Let's go with it.
			XRGGraphicsCard *card = [[XRGGraphicsCard alloc] initWithPCIDevice:pciD accelerator:accelD];
			if (card) [graphicsCards addObject:card];
			[pciIndicesUsed addIndex:i];
			[accelIndicesUsed addIndex:i];
		}
		else {
			// Mismatch was detected.  Try finding a different accelerator dictionary that does match the current pci dictionary.
			for (NSInteger j = 0; j < accelerators.count; j++) {
				if ([accelIndicesUsed containsIndex:j]) continue;
				
				if ([XRGGraphicsCard matchingPCIDevice:pciD accelerator:accelerators[j]]) {
					// Found a match.
					XRGGraphicsCard *card = [[XRGGraphicsCard alloc] initWithPCIDevice:pciD accelerator:accelerators[j]];
					if (card) [graphicsCards addObject:card];
					[pciIndicesUsed addIndex:i];
					[accelIndicesUsed addIndex:j];
					break;
				}
			}
			
			// It's possible to fall out of this loop without finding a matching accelerator for the pci device.
		}
	}
	
	// Now that we've parsed all the data, set the next values for our data sets.
	[self setNumberOfGPUs:graphicsCards.count];
	for (NSInteger i = 0; i < graphicsCards.count; i++) {
		[self.totalVRAMDataSets[i] setNextValue:[graphicsCards[i] totalVRAM]];
		[self.freeVRAMDataSets[i] setNextValue:[graphicsCards[i] freeVRAM]];
		[self.cpuWaitDataSets[i] setNextValue:[graphicsCards[i] cpuWait]];
	}
}

@end

@implementation XRGGraphicsCard

+ (BOOL)matchingPCIDevice:(NSDictionary *)pciDictionary accelerator:(NSDictionary *)acceleratorDictionary {
	id pciVendor = pciDictionary[@"vendor-id"];
	UInt32 pciVendorInt = 0xFFFF;
	if ([pciVendor isKindOfClass:[NSData class]]) {
		NSData *pciVendorData = pciVendor;
		if (pciVendorData.length >= 4) {
			UInt32 *vendorInt = (UInt32 *)pciVendorData.bytes;
			pciVendorInt = *vendorInt;
		}
	}
	id pciDevice = pciDictionary[@"device-id"];
	UInt32 pciDeviceInt = 0xFFFF;
	if ([pciDevice isKindOfClass:[NSData class]]) {
		NSData *pciDeviceData = pciDevice;
		if (pciDeviceData.length >= 4) {
			UInt32 *deviceInt = (UInt32 *)pciDeviceData.bytes;
			pciDeviceInt = *deviceInt;
		}
	}
	
	if (pciVendorInt != 0xFFFF) {
		id pciMatch = [acceleratorDictionary[@"IOPCIMatch"] uppercaseString];

		if (pciDeviceInt != 0xFFFF) {
			// We have a vendor and a device.  Check both.
			UInt32 pciComboInt = (pciDeviceInt << 16) | pciVendorInt;
			NSString *checkString = [[NSString stringWithFormat:@"%x", pciComboInt] uppercaseString];
			if ([pciMatch containsString:checkString]) {
				return YES;
			}
		}
		else {
			// Only have a vendor, check what we can.
			NSString *checkString = [[NSString stringWithFormat:@"%x", pciVendorInt] uppercaseString];
			NSString *checkStringWithSpace = [checkString stringByAppendingString:@" "];
			if ([pciMatch containsString:checkStringWithSpace] || [pciMatch hasSuffix:checkString]) {
				return YES;
			}
		}
	}
	
	return NO;
}

- (instancetype)initWithPCIDevice:(NSDictionary *)pciDictionary accelerator:(NSDictionary *)acceleratorDictionary {
	if (self = [super init]) {
		// Vendor.
		id pciVendor = pciDictionary[@"vendor-id"];
		if ([pciVendor isKindOfClass:[NSData class]]) {
			NSData *pciVendorData = pciVendor;
			if (pciVendorData.length >= 4) {
				UInt32 *vendorInt = (UInt32 *)pciVendorData.bytes;
				self.vendor = *vendorInt;
			}
		}

		// The VRAM and other stats gathered.
		// Not all VRAM stats will be populated from the GPU data.
		// We'll hope for 2 out of 3 so the third can be calculated.

		id perf_properties = acceleratorDictionary[@"PerformanceStatistics"];
		if ([perf_properties isKindOfClass:[NSDictionary class]]) {
			NSDictionary *perf = (NSDictionary *)perf_properties;
			
			id freeVram = perf[@"vramFreeBytes"];
			id usedVram = perf[@"vramUsedBytes"];
			id cpuWait = perf[@"hardwareWaitTime"];
			
			self.freeVRAM = [freeVram isKindOfClass:[NSNumber class]] ? [freeVram longLongValue] : -1;
			self.usedVRAM = [usedVram isKindOfClass:[NSNumber class]] ? [usedVram longLongValue] : -1;
			self.cpuWait = [cpuWait isKindOfClass:[NSNumber class]] ? [cpuWait longLongValue] : 0;
		}
		
		id vramTotal = pciDictionary[@"VRAM,totalMB"];
		if ([vramTotal isKindOfClass:[NSNumber class]]) {
			self.totalVRAM = [vramTotal longLongValue] * 1024ll * 1024ll;
		}
		else {
			id memsize = pciDictionary[@"ATY,memsize"];
			if ([memsize isKindOfClass:[NSNumber class]]) {
				self.totalVRAM = [memsize longLongValue];
			}
			else {
				self.totalVRAM = -1;
			}
		}
		
		// Do a check for our VRAM values.
		BOOL okay = NO;
		if ((self.totalVRAM == -1) && (self.usedVRAM != -1) && (self.freeVRAM != -1)) {
			self.totalVRAM = self.usedVRAM + self.freeVRAM;
			okay = YES;
		}
		else if ((self.totalVRAM != -1) && (self.usedVRAM == -1) && (self.freeVRAM != -1)) {
			if (self.freeVRAM == 0) {
				self.usedVRAM = 0;		// Our one exception, free being 0 is more often an error instead of really being the case.
				self.freeVRAM = self.totalVRAM - self.usedVRAM;
			}
			else {
				self.usedVRAM = self.totalVRAM - self.freeVRAM;
			}
			okay = YES;
		}
		else if ((self.totalVRAM != -1) && (self.usedVRAM != -1) && (self.freeVRAM == -1)) {
			self.freeVRAM = self.totalVRAM - self.usedVRAM;
			okay = YES;
		}
		else if ((self.totalVRAM != -1) && (self.usedVRAM != -1) && (self.freeVRAM != -1)) {
			okay = YES;
		}
		else {
			// Couldn't get data for this GPU.
			okay = NO;
		}
		
		if (!okay) {
			self.totalVRAM = 0;
			self.freeVRAM = 0;
			self.usedVRAM = 0;
		}
	}

	return self;
}

@end

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
#import "XRGDataSet.h"
#import <IOKit/graphics/IOGraphicsLib.h>

@implementation XRGGPUMiner

- (instancetype)init {
	self = [super init];
	if (self) {
		_totalVRAMDataSets = nil;
		_freeVRAMDataSets = nil;
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
	
	self.numSamples = newNumSamples;
}

- (void)setNumberOfGPUs:(NSInteger)newNumGPUs {
	if ((self.totalVRAMDataSets.count == newNumGPUs) && (self.freeVRAMDataSets.count == newNumGPUs)) {
		return;
	}
	
	NSMutableArray *newTotal = [NSMutableArray array];
	NSMutableArray *newFree = [NSMutableArray array];
	
	if (self.totalVRAMDataSets.count) [newTotal addObjectsFromArray:self.totalVRAMDataSets];
	if (self.freeVRAMDataSets.count) [newFree addObjectsFromArray:self.freeVRAMDataSets];
	
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
	}

	// Remove extra XRGDataSets if needed.
	if (newTotal.count > newNumGPUs) {
		newTotal = [NSMutableArray arrayWithArray:[newTotal subarrayWithRange:NSMakeRange(0, newNumGPUs)]];
	}
	if (newFree.count > newNumGPUs) {
		newFree = [NSMutableArray arrayWithArray:[newFree subarrayWithRange:NSMakeRange(0, newNumGPUs)]];
	}
	
	_totalVRAMDataSets = newTotal;
	_freeVRAMDataSets = newFree;
	
	self.numberOfGPUs = newNumGPUs;
}


- (void)getLatestGraphicsInfo {
	// Create an iterator
	io_iterator_t iterator;
	
	// Not all of these will be populated from the GPU data.  We'll hope for 2 out of 3 so the third can be calculated.
	NSMutableArray *usedVRAMArray = [NSMutableArray array];
	NSMutableArray *freeVRAMArray = [NSMutableArray array];
	NSMutableArray *totalVRAMArray = [NSMutableArray array];
	
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
			
			CFMutableDictionaryRef perf_properties = (CFMutableDictionaryRef) CFDictionaryGetValue( serviceDictionary, CFSTR("PerformanceStatistics") );
			if (perf_properties) {
				NSDictionary *perf = (__bridge NSDictionary *)(perf_properties);
				id freeVram = perf[@"vramFreeBytes"];
				id usedVram = perf[@"vramUsedBytes"];
				NSLog(@"CPU Wait for GPU: %@", perf[@"hardwareWaitTime"]);
				
				if ([freeVram isKindOfClass:[NSNumber class]]) [freeVRAMArray addObject:freeVram];
				else [freeVRAMArray addObject:@(-1)];
				if ([usedVram isKindOfClass:[NSNumber class]]) [usedVRAMArray addObject:usedVram];
				else [usedVRAMArray addObject:@(-1)];
			}
			
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
					NSDictionary *service = (NSDictionary *)CFBridgingRelease(serviceDictionary);
					
					id vramTotal = service[@"VRAM,totalMB"];
					if ([vramTotal isKindOfClass:[NSNumber class]]) {
						[totalVRAMArray addObject:@([vramTotal longLongValue] * 1024 * 1024)];
					}
					else {
						id memsize = service[@"ATY,memsize"];
						if ([memsize isKindOfClass:[NSNumber class]]) {
							[totalVRAMArray addObject:memsize];
						}
						else {
							[totalVRAMArray addObject:@(-1)];
						}
					}
				}
			}
			
			IOObjectRelease(serviceObject);
		}
		
		IOObjectRelease(iterator);
	}
	
	NSInteger numValues = MIN(usedVRAMArray.count, freeVRAMArray.count);
	numValues = MIN(numValues, totalVRAMArray.count);
	[self setNumberOfGPUs:numValues];

	
	for (NSInteger i = 0; i < numValues; i++) {
		long long total = [totalVRAMArray[i] longLongValue];
		long long used = [usedVRAMArray[i] longLongValue];
		long long free = [freeVRAMArray[i] longLongValue];
		
		BOOL okay = NO;
		if ((total == -1) && (used != -1) && (free != -1)) {
			total = used + free;
			okay = YES;
		}
		else if ((total != -1) && (used == -1) && (free != -1)) {
			if (free == 0) {
				used = 0;		// Our one exception, free is never really 0.
				free = total - used;
			}
			else {
				used = total - free;
			}
			okay = YES;
		}
		else if ((total != -1) && (used != -1) && (free == -1)) {
			free = total - used;
			okay = YES;
		}
		else if ((total != -1) && (used != -1) && (free != -1)) {
			okay = YES;
		}
		else {
			// Couldn't get data for this GPU.
			okay = NO;
		}
		
		if (okay) {
			[self.totalVRAMDataSets[i] setNextValue:total];
			[self.freeVRAMDataSets[i] setNextValue:free];
		}
	}
}

@end

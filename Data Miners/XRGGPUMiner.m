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
		totalVRAMValues = nil;
		freeVRAMValues = nil;
		numSamples = 0;
		numGPUs = 0;
		
		[self setNumGPUs:1];
		[self getLatestGraphicsInfo];
	}
	
	return self;
}


- (void)setDataSize:(NSInteger)newNumSamples {
	if (newNumSamples < 0) return;
	
	for (XRGDataSet *values in totalVRAMValues) {
		[values resize:newNumSamples];
	}
	for (XRGDataSet *values in freeVRAMValues) {
		[values resize:newNumSamples];
	}
	
	numSamples  = newNumSamples;
}

- (void)setNumGPUs:(NSInteger)newNumGPUs {
	if (!totalVRAMValues) totalVRAMValues = [[NSMutableArray alloc] init];
	if (!freeVRAMValues) freeVRAMValues = [[NSMutableArray alloc] init];
	
	if (newNumGPUs == 0) {
		[totalVRAMValues removeAllObjects];
		[freeVRAMValues removeAllObjects];
	}
	
	// Make sure we want at least 1 sample.
	numSamples = MAX(1, numSamples);
	
	// Add new XRGDataSets if needed.
	for (NSInteger i = 0; i < newNumGPUs; i++) {
		if (totalVRAMValues.count <= i) {
			XRGDataSet *s = [[XRGDataSet alloc] init];
			[s resize:numSamples];
			[totalVRAMValues addObject:s];
		}
		if (freeVRAMValues.count <= i) {
			XRGDataSet *s = [[XRGDataSet alloc] init];
			[s resize:numSamples];
			[freeVRAMValues addObject:s];
		}
	}

	// Remove extra XRGDataSets if needed.
	if (totalVRAMValues.count > newNumGPUs) {
		totalVRAMValues = [NSMutableArray arrayWithArray:[totalVRAMValues subarrayWithRange:NSMakeRange(0, newNumGPUs)]];
	}
	if (freeVRAMValues.count > newNumGPUs) {
		freeVRAMValues = [NSMutableArray arrayWithArray:[freeVRAMValues subarrayWithRange:NSMakeRange(0, newNumGPUs)]];
	}
	
	numGPUs = newNumGPUs;
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
				NSDictionary *perf = (NSDictionary *)perf_properties;
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
					NSDictionary *service = (NSDictionary *)serviceDictionary;
					
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
			
			CFRelease(serviceDictionary);
			IOObjectRelease(serviceObject);
		}
		
		IOObjectRelease(iterator);
	}
	
	NSInteger numValues = MIN(usedVRAMArray.count, freeVRAMArray.count);
	numValues = MIN(numValues, totalVRAMArray.count);
	[self setNumGPUs:numValues];

	
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
			[totalVRAMValues[i] setNextValue:total];
			[freeVRAMValues[i] setNextValue:free];
		}
	}
}

- (NSArray *)totalVRAMDataSets {
	return [[totalVRAMValues copy] autorelease];
}

- (NSArray *)freeVRAMDataSets {
	return [[freeVRAMValues copy] autorelease];
}

@end

/*
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2022 Gaucho Software, LLC.
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
//  XRGGraphicsMiner.h
//

#import <Foundation/Foundation.h>
#import "XRGDataSet.h"

typedef NS_ENUM(UInt32, XRGPCIVendor) {
	XRGPCIVendorIntel = 0x8086,
	XRGPCIVendorAMD = 0x1002,
	XRGPCIVendorNVidia = 0x10de,
    XRGPCIVendorApple = 0x106b
};

@interface XRGGPUMiner : NSObject

/// Represents the number of samples in each XRGDataSet object.
@property NSInteger numSamples;

/// Represents the number of XRGDataSet objects in each of the following arrays.
@property (nonatomic) NSInteger numberOfGPUs;

/// Values are XRGDataSet objects representing total memory for each GPU.
@property (readonly) NSArray *totalVRAMDataSets;
/// Values are XRGDataSet objects representing free memory for each GPU.
@property (readonly) NSArray *freeVRAMDataSets;
/// Values are XRGDataSet objects representing the CPU wait time for the GPU (units: nanoseconds).
@property (readonly) NSArray *cpuWaitDataSets;
/// Values are XRGDataSet objects representing the device utilization for the GPU (units: %)
@property (readonly) NSArray *utilizationDataSets;
/// Values are NSString objects representing vendor names.
@property (readonly) NSArray *vendorNames;

- (void)getLatestGraphicsInfo;
- (void)setDataSize:(NSInteger)newNumSamples;

@end


@interface XRGGraphicsCard : NSObject

// The PCI vendor id for this card.
@property XRGPCIVendor vendor;

/// The total memory of the GPU in bytes.
@property long long totalVRAM;
/// The used memory of the GPU in bytes.
@property long long usedVRAM;
/// The free memory of the GPU in bytes.
@property long long freeVRAM;
/// The time in nanosecods the CPU waits for the GPU.
@property long long cpuWait;
/// The device utilization in %.
@property int deviceUtilization;

/// Returns YES if the PCI device matches the accelerator.  To test for a match, we detect the PCI device ID (if present) and the PCI vendor ID from the pciDictionary and make sure that the combined value is present in the IOPCIMatch key of the accelerator dictionary.
+ (BOOL)matchingPCIDevice:(NSDictionary *)pciDictionary accelerator:(NSDictionary *)acceleratorDictionary;

/// Initializes the properties using the given PCI dictionary and accelerator.  It is assumed that the client has checked for a match with matchingPCIDevice:accelerator: previously.
- (instancetype)initWithPCIDevice:(NSDictionary *)pciDictionary accelerator:(NSDictionary *)acceleratorDictionary;

/// Returns a string representing the vendor of the GPU.
- (NSString *)vendorString;

@end

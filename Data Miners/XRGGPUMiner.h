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
//  XRGGraphicsMiner.h
//

#import <Foundation/Foundation.h>

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

- (void)getLatestGraphicsInfo;
- (void)setDataSize:(NSInteger)newNumSamples;

@end

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
//  XRGBatteryMiner.h
//

#import <Foundation/Foundation.h>
#import "XRGDataSet.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, XRGBatteryStatus) {
    XRGBatteryStatusUnknown = 0,
    XRGBatteryStatusRunningOnBattery = 1,
    XRGBatteryStatusCharging = 2,
    XRGBatteryStatusCharged = 3,
    XRGBatteryStatusOnHold = 4,
    XRGBatteryStatusNoBattery = 5
};

@interface XRGBatteryInfo: NSObject

@property NSInteger currentCharge;
@property NSInteger totalCapacity;
@property CGFloat voltage;
@property CGFloat amperage;
@property NSInteger minutesRemaining;
@property BOOL isCharging;
@property BOOL isFullyCharged;
@property BOOL isPluggedIn;

- (CGFloat)percentCharged;

@end

@interface XRGBatteryMiner : NSObject

@property (nonnull) NSArray<XRGBatteryInfo *> *batteries;
@property (nonnull) XRGDataSet *chargeWatts;
@property (nonnull) XRGDataSet *dischargeWatts;
@property NSInteger numSamples;

- (void)setDataSize:(NSInteger)newNumSamples;
- (void)graphUpdate:(nullable NSTimer *)aTimer;
- (void)reset;

- (XRGBatteryStatus)batteryStatus;
- (NSInteger)minutesRemaining;
- (NSInteger)totalCharge;
- (NSInteger)totalCapacity;
- (NSInteger)chargePercent;

@end

NS_ASSUME_NONNULL_END

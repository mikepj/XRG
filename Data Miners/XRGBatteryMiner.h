//
//  XRGBatteryMiner.h
//  XRG
//
//  Created by Mike Piatek-Jimenez on 11/3/21.
//  Copyright © 2021 Gaucho Software. All rights reserved.
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

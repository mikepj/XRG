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
//  XRGBatteryMiner.m
//

#import "XRGBatteryMiner.h"

@implementation XRGBatteryInfo

- (instancetype)initWithBatteryDictionary:(NSDictionary *)batteryDictionary {
    if (self = [super init]) {
        self.totalCapacity = [batteryDictionary[@"AppleRawMaxCapacity"] integerValue];
        self.currentCharge = [batteryDictionary[@"AppleRawCurrentCapacity"] integerValue];
        self.amperage = (CGFloat)[batteryDictionary[@"Amperage"] integerValue] / 1000;
        self.voltage = (CGFloat)[batteryDictionary[@"Voltage"] integerValue] / 1000;
        self.minutesRemaining = [batteryDictionary[@"TimeRemaining"] integerValue];
        self.isCharging = [batteryDictionary[@"IsCharging"] boolValue];
        self.isFullyCharged = [batteryDictionary[@"FullyCharged"] boolValue];
        self.isPluggedIn = [batteryDictionary[@"ExternalConnected"] boolValue];
    }
    
    return self;
}

- (CGFloat)percentCharged {
    return (CGFloat)self.currentCharge / (CGFloat)self.totalCapacity;
}

@end

@implementation XRGBatteryMiner

- (instancetype)init {
    self = [super init];
    if (self) {
        self.batteries = @[];
        self.chargeWatts = [[XRGDataSet alloc] init];
        self.dischargeWatts = [[XRGDataSet alloc] init];
        self.numSamples = 0;
    }
    return self;
}

- (void)setDataSize:(NSInteger)newNumSamples {
    [self.chargeWatts resize:newNumSamples];
    [self.dischargeWatts resize:newNumSamples];
    
    self.numSamples = newNumSamples;
}

- (void)graphUpdate:(NSTimer *)aTimer {
    NSMutableArray *newBatteries = [NSMutableArray array];
    
    io_iterator_t ioObjects = 0;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                    IOServiceMatching("IOPMPowerSource"),
                                                    &ioObjects);
    if (kr != KERN_SUCCESS) return;

    io_object_t ioService = 0;
    while ((ioService = IOIteratorNext(ioObjects))) {
        CFMutableDictionaryRef serviceProperties = NULL;
        kr = IORegistryEntryCreateCFProperties(ioService, &serviceProperties, NULL, 0);
        if (kr == KERN_SUCCESS && serviceProperties) {
            NSDictionary *batteryDictionary = CFBridgingRelease(serviceProperties);

            XRGBatteryInfo *batteryInfo = [[XRGBatteryInfo alloc] initWithBatteryDictionary:batteryDictionary];
            [newBatteries addObject:batteryInfo];
        }
        
        IOObjectRelease(ioService);
    }
    
    self.batteries = newBatteries;
    
    // Save the watts being used.
    CGFloat chargeWattsSum = 0;
    CGFloat dischargeWattsSum = 0;
    for (XRGBatteryInfo *battery in self.batteries) {
        CGFloat watts = battery.amperage * battery.voltage;
        if (watts < 0) {
            dischargeWattsSum += -watts;
        }
        else {
            chargeWattsSum += watts;
        }
    }
    
    [self.chargeWatts setNextValue:chargeWattsSum];
    [self.dischargeWatts setNextValue:dischargeWattsSum];
}

- (void)reset {
    [self.chargeWatts reset];
    [self.dischargeWatts reset];
}

- (XRGBatteryStatus)batteryStatus {
    if (self.batteries.count) {
        // We just use the first battery.
        XRGBatteryInfo *firstBattery = self.batteries[0];
        
        if (firstBattery.isPluggedIn && firstBattery.isFullyCharged) {
            return XRGBatteryStatusCharged;
        }
        else if (firstBattery.isPluggedIn && firstBattery.isCharging) {
            return XRGBatteryStatusCharging;
        }
        else if (firstBattery.isPluggedIn && !firstBattery.isCharging) {
            return XRGBatteryStatusOnHold;
        }
        else {
            return XRGBatteryStatusRunningOnBattery;
        }
    }
    else {
        return XRGBatteryStatusNoBattery;
    }
}

- (NSInteger)minutesRemaining {
    NSInteger maxMinutesRemaining = 0;
    for (XRGBatteryInfo *battery in self.batteries) {
        maxMinutesRemaining = MAX(maxMinutesRemaining, battery.minutesRemaining);
    }
    
    return maxMinutesRemaining;
}

- (NSInteger)totalCharge {
    NSInteger totalCharge = 0;
    for (XRGBatteryInfo *battery in self.batteries) {
        totalCharge += battery.currentCharge;
    }
    return totalCharge;
}

- (NSInteger)totalCapacity {
    NSInteger totalCapacity = 0;
    for (XRGBatteryInfo *battery in self.batteries) {
        totalCapacity += battery.totalCapacity;
    }
    return totalCapacity;
}

- (NSInteger)chargePercent {
    return ([self totalCharge] > 0 && [self totalCapacity] > 0) ? (NSInteger)(100.0 * [self totalCharge] / [self totalCapacity] + 0.5) : 0;
}

@end

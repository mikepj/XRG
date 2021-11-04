//
//  XRGBatteryMiner.m
//  XRG
//
//  Created by Mike Piatek-Jimenez on 11/3/21.
//  Copyright © 2021 Gaucho Software. All rights reserved.
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
    return (NSInteger)(100.0 * [self totalCharge] / [self totalCapacity] + 0.5);
}

@end

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
//  XRGAppleSiliconSensorMiner.h
//

// This code is based on https://github.com/yujitach/MenuMeters/
// which was in turn based on https://github.com/fermion-star/apple_sensors/blob/master/temp_sensor.m
// which followed https://github.com/freedomtan/sensors/blob/master/sensors/sensors.m
// whose detail can be found in https://www2.slideshare.net/kstan2/exploring-thermal-related-stuff-in-idevices-using-opensource-tool

#import "XRGAppleSiliconSensorMiner.h"
#import <Foundation/Foundation.h>
#import "IOHIDEventTypes.h"
#import "AppleHIDUsageTables.h"
#include "TargetConditionals.h"

#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>

typedef struct __IOHIDEvent *IOHIDEventRef;

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t, int32_t, int64_t);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

@implementation XRGAppleSiliconSensorMiner

+ (NSDictionary *)sensorData {
#if TARGET_CPU_ARM64
    CFStringRef productKey = CFSTR("Product");
    
    IOHIDEventSystemClientRef eventSystemClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);;
    IOHIDEventSystemClientSetMatching(eventSystemClient, (__bridge CFDictionaryRef)@{
        @"PrimaryUsagePage": @(kHIDPage_AppleVendor),
        @"PrimaryUsage": @(kHIDUsage_AppleVendor_TemperatureSensor)
    });

    CFArrayRef hidServices = IOHIDEventSystemClientCopyServices(eventSystemClient);
    if (!hidServices) return nil;
    
    NSMutableDictionary *sensorDictionary = [NSMutableDictionary dictionary];
    CFIndex count = CFArrayGetCount(hidServices);
    for (int i = 0; i < count; i++) {
        IOHIDServiceClientRef serviceRef = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(hidServices, i);
        
        NSString *name = CFBridgingRelease(IOHIDServiceClientCopyProperty(serviceRef, productKey));
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(serviceRef, kIOHIDEventTypeTemperature, 0, 0);
        
        if (name && event) {
            IOHIDFloat temperature = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
            sensorDictionary[name] = @(temperature);
        }
        
        if (event) CFRelease(event);
    }
    
    CFRelease(hidServices);
    CFRelease(eventSystemClient);
    
    return sensorDictionary;
#else
    return nil;
#endif
}

@end

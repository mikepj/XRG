/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2016 Gaucho Software, LLC.
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
//  XRGTemperatureMiner.h
//

#import <Foundation/Foundation.h>
#import "XRGDataSet.h"
#import "SMCSensors.h"

@class SMCSensors;

#pragma mark - XRGFan
@interface XRGFan: NSObject

@property (nullable) NSString *name;
@property (nonnull) NSString *key;
@property NSInteger actualSpeed;
@property NSInteger targetSpeed;
@property NSInteger minimumSpeed;
@property NSInteger maximumSpeed;

@end

#pragma mark - XRGSensorData
@interface XRGSensorData: NSObject

@property (nullable) NSString *humanReadableName;
@property (nullable) NSString *units;
@property (nonnull) NSString *key;

@property double currentValue;
@property (nonnull) XRGDataSet *dataSet;

@property BOOL isEnabled;

- (nonnull instancetype)initWithSensorKey:(nonnull NSString *)key;

- (nonnull NSString *)label;

@end


#pragma mark - XRGTemperatureMiner
@interface XRGTemperatureMiner : NSObject {
    host_name_port_t			host;
    host_basic_info_data_t		hostInfo;
    NSInteger                   numCPUs;
}

@property (nonnull) SMCSensors *smcSensors;

+ (nonnull instancetype)shared;

- (void)setDataSize:(NSInteger)newNumSamples;
- (void)reset;
- (NSInteger)numberOfCPUs;

- (void)updateCurrentTemperatures;

- (nonnull NSArray<NSString *> *)locationKeysIncludingUnknown:(BOOL)includeUnknown;
- (nonnull NSArray<NSString *> *)allSensorKeys;
- (void)regenerateLocationKeyOrder;
- (void)setCurrentValue:(float)value andUnits:(nullable NSString *)units forLocation:(nonnull NSString *)location;

- (nullable XRGSensorData *)sensorForLocation:(nonnull NSString *)location;
- (BOOL)isFanSensor:(nonnull XRGSensorData *)sensor;

- (nonnull NSArray<XRGFan *> *)fanValues;
- (NSInteger)maxSpeedForFan:(nonnull XRGSensorData *)sensor;

@end


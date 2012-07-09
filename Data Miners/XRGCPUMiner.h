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
//  XRGCPUMiner.h
//

#import <Foundation/Foundation.h>
#import "XRGDataSet.h"
#import "XRGTemperatureMiner.h"

@interface XRGCPUMiner : NSObject {
@private
    BOOL                        temperature;
    BOOL                        loadAverage;
    BOOL                        uptime;

    NSInteger					numSamples;
    NSInteger					numCPUs;

    NSInteger					*fastValues;
    NSMutableArray              *userValues;
    NSMutableArray              *systemValues;
    NSMutableArray              *niceValues;
    CGFloat						*immediateUser;
    CGFloat						*immediateSystem;
    CGFloat						*immediateNice;
    CGFloat                     *immediateTotal;
    CGFloat                     *immediateTemperatureC;
    CGFloat						currentLoadAverage;
    NSInteger                   uptimeDays;
    NSInteger                   uptimeHours;
    NSInteger                   uptimeMinutes;
    NSInteger                   uptimeSeconds;
    NSMutableDictionary         *temperatureKeys;
    XRGTemperatureMiner         *TemperatureMiner;

    processor_cpu_load_info_t   lastSlowCPUInfo;
    processor_cpu_load_info_t   lastFastCPUInfo;
    
    host_name_port_t		host;
}
- (void)setTemperature:(BOOL)yesNo;
- (void)setLoadAverage:(BOOL)yesNo;
- (void)setUptime:(BOOL)yesNo;
- (void)setTemperatureMiner:(XRGTemperatureMiner *)miner;
- (XRGTemperatureMiner *)temperatureMiner;

- (void)graphUpdate:(NSTimer *)aTimer;
- (void)fastUpdate:(NSTimer *)aTimer;
- (NSInteger)calculateCPUUsageForCPUs:(processor_cpu_load_info_t *)lastCPUInfo count:(NSInteger)count;
- (NSInteger)getNumCPUs;
- (CGFloat)getLoadAverage;

- (void)setCurrentTemperatures;

- (void)setCurrentUptime;
- (void)setDataSize:(NSInteger)newNumSamples;

- (CGFloat *)currentTemperatureC;
- (CGFloat *)currentTotalUsage;
- (CGFloat *)currentUserUsage;
- (CGFloat *)currentSystemUsage;
- (CGFloat *)currentNiceUsage;
- (NSInteger *)fastValues;
- (CGFloat)currentLoadAverage;
- (NSInteger)uptimeDays;
- (NSInteger)uptimeHours;
- (NSInteger)uptimeMinutes;
- (NSInteger)uptimeSeconds;
- (NSArray *)dataForCPU:(NSInteger)cpuNumber;
- (NSArray *)combinedData;

- (NSInteger)numberOfCPUs;
@end

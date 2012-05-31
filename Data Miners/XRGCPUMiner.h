/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2009 Gaucho Software, LLC.
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
    bool                        temperature;
    bool                        loadAverage;
    bool                        uptime;

    int							numSamples;
    int							numCPUs;

    int							*fastValues;
    NSMutableArray              *userValues;
    NSMutableArray              *systemValues;
    NSMutableArray              *niceValues;
    float						*immediateUser;
    float						*immediateSystem;
    float						*immediateNice;
    float                       *immediateTotal;
    float                       *immediateTemperatureC;
    float						currentLoadAverage;
    int                         uptimeDays;
    int                         uptimeHours;
    int                         uptimeMinutes;
    int                         uptimeSeconds;
    NSMutableDictionary         *temperatureKeys;
    XRGTemperatureMiner         *TemperatureMiner;

    processor_cpu_load_info_t   lastSlowCPUInfo;
    processor_cpu_load_info_t   lastFastCPUInfo;
    
    host_name_port_t		host;
}
- (void)setTemperature:(bool)yesNo;
- (void)setLoadAverage:(bool)yesNo;
- (void)setUptime:(bool)yesNo;
- (void)setTemperatureMiner:(XRGTemperatureMiner *)miner;
- (XRGTemperatureMiner *)temperatureMiner;

- (void)graphUpdate:(NSTimer *)aTimer;
- (void)fastUpdate:(NSTimer *)aTimer;
- (int)calculateCPUUsageForCPUs:(processor_cpu_load_info_t *)lastCPUInfo count:(int)count;
- (int)getNumCPUs;
- (float)getLoadAverage;

- (void)setCurrentTemperatures;

- (void)setCurrentUptime;
- (void)setDataSize:(int)newNumSamples;

- (float *)currentTemperatureC;
- (float *)currentTotalUsage;
- (float *)currentUserUsage;
- (float *)currentSystemUsage;
- (float *)currentNiceUsage;
- (int *)fastValues;
- (float)currentLoadAverage;
- (int)uptimeDays;
- (int)uptimeHours;
- (int)uptimeMinutes;
- (int)uptimeSeconds;
- (NSArray *)dataForCPU:(int)cpuNumber;
- (NSArray *)combinedData;

- (int)numberOfCPUs;
@end

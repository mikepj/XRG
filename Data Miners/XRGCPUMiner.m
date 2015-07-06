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
//  XRGCPUMiner.m
//


#import "XRGCPUMiner.h"

#include <assert.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#import <mach/mach_host.h>
#import <mach/vm_map.h>

#undef DEBUG_2_CPUS

@implementation XRGCPUMiner
- (instancetype)init {
    host = mach_host_self();
    
    unsigned int count = HOST_BASIC_INFO_COUNT;
    host_basic_info_data_t info;
    host_info(host, HOST_BASIC_INFO, (host_info_t)&info, &count);
        
    temperature = NO;
    loadAverage = YES;
    TemperatureMiner = nil;
    
    currentLoadAverage = 0.00;
    
    // Set the number of CPUs
    numCPUs = [self getNumCPUs];
    // Debug 2 CPUs
    #ifdef DEBUG_2_CPUS
    numCPUs = 2;
    #endif
    
    // Initialize all the variables that depend on the number of processors
    immediateSystem       = malloc(numCPUs * sizeof(CGFloat));
    immediateUser         = malloc(numCPUs * sizeof(CGFloat));
    immediateNice         = malloc(numCPUs * sizeof(CGFloat));
    immediateTotal        = malloc(numCPUs * sizeof(CGFloat));
    fastValues            = malloc(numCPUs * sizeof(NSInteger));
    immediateTemperatureC = malloc(numCPUs * sizeof(CGFloat));
    lastSlowCPUInfo       = malloc(numCPUs * sizeof(*lastSlowCPUInfo));
    lastFastCPUInfo       = malloc(numCPUs * sizeof(*lastFastCPUInfo));
    
    temperatureKeys = [NSMutableDictionary dictionary];

    for (NSInteger i = 0; i < numCPUs; i++) {
        immediateSystem[i]       = 0;
        immediateUser[i]         = 0;
        immediateNice[i]         = 0;
        immediateTotal[i]        = 0;
        fastValues[i]            = 0;
        immediateTemperatureC[i] = 0;
    }
    userValues = systemValues = niceValues = nil;

    // flush out the first spike
    [self calculateCPUUsageForCPUs:&lastSlowCPUInfo count:numCPUs];

    return self;
}

- (void)setTemperature:(BOOL)yesNo {
    temperature = yesNo;
}

- (void)setLoadAverage:(BOOL)yesNo {
    loadAverage = yesNo;
}

- (void)setUptime:(BOOL)yesNo {
    uptime = yesNo;
}

- (void)setTemperatureMiner:(XRGTemperatureMiner *)miner {
	TemperatureMiner = miner;
}

- (XRGTemperatureMiner *)temperatureMiner {
    return TemperatureMiner;
}

- (void)setDataSize:(NSInteger)newNumSamples {
    NSInteger i;

    if (newNumSamples < 0) return;
    
    if(userValues && systemValues && niceValues) {
        for (i = 0; i < numCPUs; i++) {
            [userValues[i] resize:(size_t)newNumSamples];
            [systemValues[i] resize:(size_t)newNumSamples];
            [niceValues[i] resize:(size_t)newNumSamples];
        }
    }
    else {
        userValues = [NSMutableArray arrayWithCapacity:numCPUs];
        systemValues = [NSMutableArray arrayWithCapacity:numCPUs];
        niceValues = [NSMutableArray arrayWithCapacity:numCPUs];
        
        for (i = 0; i < numCPUs; i++) {
            XRGDataSet *tmpDataSet = [[XRGDataSet alloc] init];
            [tmpDataSet resize:(size_t)newNumSamples];
            [userValues addObject:tmpDataSet];
            
            tmpDataSet = [[XRGDataSet alloc] init];
            [tmpDataSet resize:(size_t)newNumSamples];
            [systemValues addObject:tmpDataSet];
            
            tmpDataSet = [[XRGDataSet alloc] init];
            [tmpDataSet resize:(size_t)newNumSamples];
            [niceValues addObject:tmpDataSet];
        }
    }
        
    numSamples  = newNumSamples;
}

- (void)graphUpdate:(NSTimer *)aTimer {
    [self calculateCPUUsageForCPUs:&lastSlowCPUInfo count:numCPUs];
	
    for (NSInteger i = 0; i < numCPUs; i++) {
        [userValues[i]   setNextValue:immediateUser[i]];
        [systemValues[i] setNextValue:immediateSystem[i]];
        [niceValues[i]   setNextValue:immediateNice[i]];
    }

    // Debug 2 CPUs
    #ifdef DEBUG_2_CPUS
    [[userValues objectAtIndex:1] setNextValue:immediateUser[0]];
    [[systemValues objectAtIndex:1] setNextValue:immediateSystem[0]];
    [[niceValues objectAtIndex:1] setNextValue:immediateNice[0]];
    #endif
                
    if (temperature) [self setCurrentTemperatures];
    if (uptime) [self setCurrentUptime];
    if (loadAverage) currentLoadAverage = [self getLoadAverage];
}

- (void)fastUpdate:(NSTimer *)aTimer {
    [self calculateCPUUsageForCPUs:&lastFastCPUInfo count:numCPUs];

    for (NSInteger i = 0; i < numCPUs; i++) {
		CGFloat difference = fastValues[i] - (immediateUser[i] + immediateSystem[i] + immediateNice[i]);
		
		if (difference < 5. && difference > -5.) {
			fastValues[i] = immediateUser[i] + immediateSystem[i] + immediateNice[i];
		}
		else {
			fastValues[i] = fastValues[i] + (0.25 * (immediateUser[i] + immediateSystem[i] + immediateNice[i] - fastValues[i]));
		}
		
		if (fastValues[i] < 0 || fastValues[i] > 100) {
			CGFloat sum = immediateUser[i] + immediateSystem[i] + immediateNice[i];
			
			if (sum < 0) sum = 0;
			if (sum > 100) sum = 100;
			
			fastValues[i] = sum;
		}
    }
}

- (NSInteger)calculateCPUUsageForCPUs:(processor_cpu_load_info_t *)lastCPUInfo count:(NSInteger)count {
    processor_cpu_load_info_t		newCPUInfo;
    kern_return_t					kr;
    unsigned int					processor_count;
    mach_msg_type_number_t			load_count;
    NSInteger						totalCPUTicks;

    kr = host_processor_info(host, 
                             PROCESSOR_CPU_LOAD_INFO, 
                             &processor_count, 
                             (processor_info_array_t *)&newCPUInfo, 
                             &load_count);
    if(kr != KERN_SUCCESS) {
        return 0;
    }
    else {
        for (NSInteger i = 0; i < processor_count; i++) {
            if (i >= count) break;
        
            totalCPUTicks = 0;
            
            for (NSInteger j = 0; j < CPU_STATE_MAX; j++) {
                totalCPUTicks += newCPUInfo[i].cpu_ticks[j] - (*lastCPUInfo)[i].cpu_ticks[j];
            }
            
            immediateUser[i]   = (totalCPUTicks == 0) ? 0 : (CGFloat)(newCPUInfo[i].cpu_ticks[CPU_STATE_USER] - (*lastCPUInfo)[i].cpu_ticks[CPU_STATE_USER]) / (CGFloat)totalCPUTicks * 100.;
            immediateSystem[i] = (totalCPUTicks == 0) ? 0 : (CGFloat)(newCPUInfo[i].cpu_ticks[CPU_STATE_SYSTEM] - (*lastCPUInfo)[i].cpu_ticks[CPU_STATE_SYSTEM]) / (CGFloat)totalCPUTicks * 100.;
            immediateNice[i]   = (totalCPUTicks == 0) ? 0 : (CGFloat)(newCPUInfo[i].cpu_ticks[CPU_STATE_NICE] - (*lastCPUInfo)[i].cpu_ticks[CPU_STATE_NICE]) / (CGFloat)totalCPUTicks * 100.;
            
            immediateTotal[i] = immediateUser[i] + immediateSystem[i] + immediateNice[i];

            for(NSInteger j = 0; j < CPU_STATE_MAX; j++)
                (*lastCPUInfo)[i].cpu_ticks[j] = newCPUInfo[i].cpu_ticks[j];
        }
        
        vm_deallocate(mach_task_self(), 
                      (vm_address_t)newCPUInfo, 
                      (vm_size_t)(load_count * sizeof(*newCPUInfo)));
                      
        return (NSInteger)processor_count;
    }
}

- (NSInteger)getNumCPUs {
    processor_cpu_load_info_t		newCPUInfo;
    kern_return_t			kr;
    unsigned int			processor_count;
    mach_msg_type_number_t		load_count;

    kr = host_processor_info(host, 
                             PROCESSOR_CPU_LOAD_INFO, 
                             &processor_count, 
                             (processor_info_array_t *)&newCPUInfo, 
                             &load_count);
    if(kr != KERN_SUCCESS) {
        return 0;
    }
    else {
        vm_deallocate(mach_task_self(), 
                      (vm_address_t)newCPUInfo, 
                      (vm_size_t)(load_count * sizeof(*newCPUInfo)));
                      
        return (NSInteger)processor_count;
    }
}

- (CGFloat)getLoadAverage {
    host_load_info_data_t loadData;
    mach_msg_type_number_t count = HOST_LOAD_INFO_COUNT;
    
    if (host_statistics(host, HOST_LOAD_INFO, (host_info_t)&loadData, &count) == KERN_SUCCESS)
        return (CGFloat)loadData.avenrun[0] / (CGFloat)LOAD_SCALE;
    else 
        return -1;
}

- (void)setCurrentUptime {
    time_t         currentTime;
    time_t         uptimeInSeconds = 0;
    struct timeval bootTime;
    size_t         size = sizeof(bootTime);
    int mib[2] = { CTL_KERN, KERN_BOOTTIME };    

    (void)time(&currentTime);
        
    if ((sysctl(mib, 2, &bootTime, &size, NULL, 0) != -1) && (bootTime.tv_sec != 0)) {
        uptimeInSeconds = currentTime - bootTime.tv_sec;

        uptimeDays = uptimeInSeconds / (60 * 60 * 24);
        uptimeInSeconds %= (60 * 60 * 24);
        
        uptimeHours = uptimeInSeconds / (60 * 60);
        uptimeInSeconds %= (60 * 60);
        
        uptimeMinutes = uptimeInSeconds / 60;
        uptimeInSeconds %= 60;
        
        uptimeSeconds = uptimeInSeconds;
    }
    else {
        uptimeDays = uptimeHours = uptimeMinutes = uptimeSeconds = 0;
    }
}

- (void)setCurrentTemperatures {

    if (TemperatureMiner != nil) {
        float *temps = [TemperatureMiner currentCPUTemperature];
        
        for (NSInteger i = 0; i < [TemperatureMiner numberOfCPUs]; i++) {
            immediateTemperatureC[i] = temps[i];
        }
    }
}

- (CGFloat *)currentTemperatureC {
    return immediateTemperatureC;
}

- (CGFloat *)currentTotalUsage {
    return immediateTotal;
}

- (CGFloat *)currentUserUsage {
    return immediateUser;
}

- (CGFloat *)currentSystemUsage {
    return immediateSystem;
}

- (CGFloat *)currentNiceUsage {
    return immediateNice;
}

- (NSInteger *)fastValues {
    return fastValues;
}

- (CGFloat)currentLoadAverage {
    return currentLoadAverage;
}

- (NSInteger)uptimeDays {
    return uptimeDays;
}

- (NSInteger)uptimeHours {
    return uptimeHours;
}

- (NSInteger)uptimeMinutes {
    return uptimeMinutes;
}

- (NSInteger)uptimeSeconds {
    return uptimeSeconds;
}

// Returns an NSArray of XRGDataSet objects.  
// The first XRGDataSet is system cpu usage, the second is user cpu usage, and the third is nice cpu usage.
- (NSArray *)dataForCPU:(NSInteger)cpuNumber {
	if (cpuNumber >= [systemValues count] || cpuNumber >= [userValues count] || cpuNumber >= [niceValues count]) return nil;
	
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:3];
    
	XRGDataSet *sys = systemValues[cpuNumber];
	if (sys) [a addObject:sys];
	else return nil;
	
	XRGDataSet *usr = userValues[cpuNumber];
    if (usr) [a addObject:usr];
	else return nil;
	
    XRGDataSet *nice = niceValues[cpuNumber];
	if (nice) [a addObject:nice];
	else return nil;
    
    return a;
}

// Return an array of 3 XRGDataSets with combined data for all the CPUs.
- (NSArray *)combinedData {
	if (![systemValues count] || ![userValues count] || ![niceValues count]) return nil;
	
	XRGDataSet *tmpSystem = [[XRGDataSet alloc] initWithContentsOfOtherDataSet:systemValues[0]];
	XRGDataSet *tmpUser = [[XRGDataSet alloc] initWithContentsOfOtherDataSet:userValues[0]];
	XRGDataSet *tmpNice = [[XRGDataSet alloc] initWithContentsOfOtherDataSet:niceValues[0]];
	
	for (NSInteger i = 1; i < numCPUs; i++) {
		[tmpSystem addOtherDataSetValues:systemValues[i]];
		[tmpUser addOtherDataSetValues:userValues[i]];
		[tmpNice addOtherDataSetValues:niceValues[i]];
	}
	
	[tmpSystem divideAllValuesBy:numCPUs];
	[tmpUser divideAllValuesBy:numCPUs];
	[tmpNice divideAllValuesBy:numCPUs];
	
	if (tmpSystem == nil || tmpUser == nil || tmpNice == nil) return nil;
	
	NSArray *a = @[tmpSystem, tmpUser, tmpNice];
	return a;
}

- (NSInteger)numberOfCPUs {
    return numCPUs;
}

@end

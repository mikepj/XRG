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
//  XRGCPUMiner.m
//


#import "XRGCPUMiner.h"

#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#import <mach/mach_host.h>
#import <mach/vm_map.h>

#undef DEBUG_2_CPUS

@implementation XRGCPUMiner
- (id)init {
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
    immediateSystem       = malloc(numCPUs * sizeof(float));
    immediateUser         = malloc(numCPUs * sizeof(float));
    immediateNice         = malloc(numCPUs * sizeof(float));
    immediateTotal        = malloc(numCPUs * sizeof(float));
    fastValues            = malloc(numCPUs * sizeof(int));
    immediateTemperatureC = malloc(numCPUs * sizeof(float));
    lastSlowCPUInfo       = malloc(numCPUs * sizeof(*lastSlowCPUInfo));
    lastFastCPUInfo       = malloc(numCPUs * sizeof(*lastFastCPUInfo));
    
    temperatureKeys = [[NSMutableDictionary dictionaryWithCapacity:20] retain];

    int i;
    for (i = 0; i < numCPUs; i++) {
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

- (void)setTemperature:(bool)yesNo {
    temperature = yesNo;
}

- (void)setLoadAverage:(bool)yesNo {
    loadAverage = yesNo;
}

- (void)setUptime:(bool)yesNo {
    uptime = yesNo;
}

- (void)setTemperatureMiner:(XRGTemperatureMiner *)miner {
    if (TemperatureMiner != nil) {
        [TemperatureMiner autorelease];
        TemperatureMiner = nil;
    }
    
    if (miner != nil) {
        TemperatureMiner = [miner retain];
    }
}

- (XRGTemperatureMiner *)temperatureMiner {
    return TemperatureMiner;
}

- (void)setDataSize:(int)newNumSamples {
    int i;

    if (newNumSamples < 0) return;
    
    if(userValues && systemValues && niceValues) {
        for (i = 0; i < numCPUs; i++) {
            [[userValues objectAtIndex:i] resize:(size_t)newNumSamples];
            [[systemValues objectAtIndex:i] resize:(size_t)newNumSamples];
            [[niceValues objectAtIndex:i] resize:(size_t)newNumSamples];
        }
    }
    else {
        if (userValues) {
            [userValues release];
            userValues = nil;
        }
        if (systemValues) {
            [systemValues release];
            systemValues = nil;
        }
        if (niceValues) {
            [niceValues release];
            niceValues = nil;
        }
        
        userValues = [[NSMutableArray arrayWithCapacity:numCPUs] retain];
        systemValues = [[NSMutableArray arrayWithCapacity:numCPUs] retain];
        niceValues = [[NSMutableArray arrayWithCapacity:numCPUs] retain];
        
        for (i = 0; i < numCPUs; i++) {
            XRGDataSet *tmpDataSet = [[XRGDataSet alloc] init];
            [tmpDataSet resize:(size_t)newNumSamples];
            [userValues addObject:tmpDataSet];
            [tmpDataSet release];
            
            tmpDataSet = [[XRGDataSet alloc] init];
            [tmpDataSet resize:(size_t)newNumSamples];
            [systemValues addObject:tmpDataSet];
            [tmpDataSet release];
            
            tmpDataSet = [[XRGDataSet alloc] init];
            [tmpDataSet resize:(size_t)newNumSamples];
            [niceValues addObject:tmpDataSet];
            [tmpDataSet release];
        }
    }
        
    numSamples  = newNumSamples;
}

- (void)graphUpdate:(NSTimer *)aTimer {
    [self calculateCPUUsageForCPUs:&lastSlowCPUInfo count:numCPUs];
	
    int i;
    for (i = 0; i < numCPUs; i++) {
        [[userValues objectAtIndex:i]   setNextValue:immediateUser[i]];
        [[systemValues objectAtIndex:i] setNextValue:immediateSystem[i]];
        [[niceValues objectAtIndex:i]   setNextValue:immediateNice[i]];
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

    int i;
    for (i = 0; i < numCPUs; i++) {
		float difference = fastValues[i] - (immediateUser[i] + immediateSystem[i] + immediateNice[i]);
		
		if (difference < 5. && difference > -5.) {
			fastValues[i] = immediateUser[i] + immediateSystem[i] + immediateNice[i];
		}
		else {
			fastValues[i] = fastValues[i] + (0.25 * (immediateUser[i] + immediateSystem[i] + immediateNice[i] - fastValues[i]));
		}
		
		if (fastValues[i] < 0 || fastValues[i] > 100) {
			float sum = immediateUser[i] + immediateSystem[i] + immediateNice[i];
			
			if (sum < 0) sum = 0;
			if (sum > 100) sum = 100;
			
			fastValues[i] = sum;
		}
    }
}

- (int)calculateCPUUsageForCPUs:(processor_cpu_load_info_t *)lastCPUInfo count:(int)count {
    processor_cpu_load_info_t		newCPUInfo;
    kern_return_t					kr;
    unsigned int					processor_count;
    mach_msg_type_number_t			load_count;
    int								i;
    int								totalCPUTicks;

    kr = host_processor_info(host, 
                             PROCESSOR_CPU_LOAD_INFO, 
                             &processor_count, 
                             (processor_info_array_t *)&newCPUInfo, 
                             &load_count);
    if(kr != KERN_SUCCESS) {
        return 0;
    }
    else {
        for (i = 0; i < processor_count; i++) {
            if (i >= count) break;
        
            totalCPUTicks = 0;
            
            int j;
            for (j = 0; j < CPU_STATE_MAX; j++) {
                totalCPUTicks += newCPUInfo[i].cpu_ticks[j] - (*lastCPUInfo)[i].cpu_ticks[j];
            }
            
            immediateUser[i]   = (totalCPUTicks == 0) ? 0 : (float)(newCPUInfo[i].cpu_ticks[CPU_STATE_USER] - (*lastCPUInfo)[i].cpu_ticks[CPU_STATE_USER]) / (float)totalCPUTicks * 100.;
            immediateSystem[i] = (totalCPUTicks == 0) ? 0 : (float)(newCPUInfo[i].cpu_ticks[CPU_STATE_SYSTEM] - (*lastCPUInfo)[i].cpu_ticks[CPU_STATE_SYSTEM]) / (float)totalCPUTicks * 100.;
            immediateNice[i]   = (totalCPUTicks == 0) ? 0 : (float)(newCPUInfo[i].cpu_ticks[CPU_STATE_NICE] - (*lastCPUInfo)[i].cpu_ticks[CPU_STATE_NICE]) / (float)totalCPUTicks * 100.;
            
            immediateTotal[i] = immediateUser[i] + immediateSystem[i] + immediateNice[i];

            for(j = 0; j < CPU_STATE_MAX; j++)
                (*lastCPUInfo)[i].cpu_ticks[j] = newCPUInfo[i].cpu_ticks[j];
        }
        
        vm_deallocate(mach_task_self(), 
                      (vm_address_t)newCPUInfo, 
                      (vm_size_t)(load_count * sizeof(*newCPUInfo)));
                      
        return (int)processor_count;
    }
}

- (int)getNumCPUs {
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
                      
        return (int)processor_count;
    }
}

- (float)getLoadAverage {
    host_load_info_data_t loadData;
    mach_msg_type_number_t count = HOST_LOAD_INFO_COUNT;
    
    if (host_statistics(host, HOST_LOAD_INFO, (host_info_t)&loadData, &count) == KERN_SUCCESS)
        return (float)loadData.avenrun[0] / (float)LOAD_SCALE;
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
    int i;

    if (TemperatureMiner != nil) {
        float *temps = [TemperatureMiner currentCPUTemperature];
        
        for (i = 0; i < [TemperatureMiner numberOfCPUs]; i++) {
            immediateTemperatureC[i] = temps[i];
        }
    }
}

- (float *)currentTemperatureC {
    return immediateTemperatureC;
}

- (float *)currentTotalUsage {
    return immediateTotal;
}

- (float *)currentUserUsage {
    return immediateUser;
}

- (float *)currentSystemUsage {
    return immediateSystem;
}

- (float *)currentNiceUsage {
    return immediateNice;
}

- (int *)fastValues {
    return fastValues;
}

- (float)currentLoadAverage {
    return currentLoadAverage;
}

- (int)uptimeDays {
    return uptimeDays;
}

- (int)uptimeHours {
    return uptimeHours;
}

- (int)uptimeMinutes {
    return uptimeMinutes;
}

- (int)uptimeSeconds {
    return uptimeSeconds;
}

// Returns an NSArray of XRGDataSet objects.  
// The first XRGDataSet is system cpu usage, the second is user cpu usage, and the third is nice cpu usage.
- (NSArray *)dataForCPU:(int)cpuNumber {
	if (cpuNumber >= [systemValues count] || cpuNumber >= [userValues count] || cpuNumber >= [niceValues count]) return nil;
	
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:3];
    
	XRGDataSet *sys = [systemValues objectAtIndex:cpuNumber];
	if (sys) [a addObject:sys];
	else return nil;
	
	XRGDataSet *usr = [userValues objectAtIndex:cpuNumber];
    if (usr) [a addObject:usr];
	else return nil;
	
    XRGDataSet *nice = [niceValues objectAtIndex:cpuNumber];
	if (nice) [a addObject:nice];
	else return nil;
    
    return a;
}

// Return an array of 3 XRGDataSets with combined data for all the CPUs.
- (NSArray *)combinedData {
	if (![systemValues count] || ![userValues count] || ![niceValues count]) return nil;
	
	XRGDataSet *tmpSystem = [[[XRGDataSet alloc] initWithContentsOfOtherDataSet:[systemValues objectAtIndex:0]] autorelease];
	XRGDataSet *tmpUser = [[[XRGDataSet alloc] initWithContentsOfOtherDataSet:[userValues objectAtIndex:0]] autorelease];
	XRGDataSet *tmpNice = [[[XRGDataSet alloc] initWithContentsOfOtherDataSet:[niceValues objectAtIndex:0]] autorelease];
	
	int i;
	for (i = 1; i < numCPUs; i++) {
		[tmpSystem addOtherDataSetValues:[systemValues objectAtIndex:i]];
		[tmpUser addOtherDataSetValues:[userValues objectAtIndex:i]];
		[tmpNice addOtherDataSetValues:[niceValues objectAtIndex:i]];
	}
	
	[tmpSystem divideAllValuesBy:numCPUs];
	[tmpUser divideAllValuesBy:numCPUs];
	[tmpNice divideAllValuesBy:numCPUs];
	
	if (tmpSystem == nil || tmpUser == nil || tmpNice == nil) return nil;
	
	NSArray *a = [NSArray arrayWithObjects:tmpSystem, tmpUser, tmpNice, nil];
	return a;
}

- (int)numberOfCPUs {
    return numCPUs;
}

@end

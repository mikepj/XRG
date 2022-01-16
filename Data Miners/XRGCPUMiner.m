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
//  XRGCPUMiner.m
//


#import "XRGCPUMiner.h"

#include <assert.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#import <mach/mach_host.h>
#import <mach/vm_map.h>

@implementation XRGCPUMiner

+ (NSString *)systemModelIdentifier {
    NSString *modelString = nil;

    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    if (len) {
        char *model = malloc(len*sizeof(char));
        sysctlbyname("hw.model", model, &len, NULL, 0);
        modelString = @(model);
        free(model);
    }

    return modelString;
}

- (instancetype)init {
    host = mach_host_self();
    
    unsigned int count = HOST_BASIC_INFO_COUNT;
    host_basic_info_data_t info;
    host_info(host, HOST_BASIC_INFO, (host_info_t)&info, &count);
        
    self.loadAverage = YES;
    
    self.currentLoadAverage = 0.00;
    
    // Set the number of CPUs
    self.numberOfCPUs = [self getNumCPUs];
	
    // Initialize all the variables that depend on the number of processors
    immediateSystem       = malloc(self.numberOfCPUs * sizeof(CGFloat));
    immediateUser         = malloc(self.numberOfCPUs * sizeof(CGFloat));
    immediateNice         = malloc(self.numberOfCPUs * sizeof(CGFloat));
    immediateTotal        = malloc(self.numberOfCPUs * sizeof(CGFloat));
    self.fastValues       = malloc(self.numberOfCPUs * sizeof(NSInteger));
    lastSlowCPUInfo       = malloc(self.numberOfCPUs * sizeof(*lastSlowCPUInfo));
    lastFastCPUInfo       = malloc(self.numberOfCPUs * sizeof(*lastFastCPUInfo));
    
    temperatureKeys = [NSMutableDictionary dictionary];

    for (NSInteger i = 0; i < self.numberOfCPUs; i++) {
        immediateSystem[i]       = 0;
        immediateUser[i]         = 0;
        immediateNice[i]         = 0;
        immediateTotal[i]        = 0;
        self.fastValues[i]       = 0;
    }
	self.userValues = nil;
	self.systemValues = nil;
	self.niceValues = nil;

    // flush out the first spike
    [self calculateCPUUsageForCPUs:&lastSlowCPUInfo count:self.numberOfCPUs];

    return self;
}

- (void)setDataSize:(NSInteger)newNumSamples {
    NSInteger i;

    if (newNumSamples < 0) return;
    
    if(self.userValues && self.systemValues && self.niceValues) {
        for (i = 0; i < self.numberOfCPUs; i++) {
            [self.userValues[i] resize:(size_t)newNumSamples];
            [self.systemValues[i] resize:(size_t)newNumSamples];
            [self.niceValues[i] resize:(size_t)newNumSamples];
        }
    }
    else {
        self.userValues = [NSMutableArray array];
        self.systemValues = [NSMutableArray array];
        self.niceValues = [NSMutableArray array];
        
        for (i = 0; i < self.numberOfCPUs; i++) {
            XRGDataSet *tmpDataSet = [[XRGDataSet alloc] init];
            [tmpDataSet resize:(size_t)newNumSamples];
            [self.userValues addObject:tmpDataSet];
            
            tmpDataSet = [[XRGDataSet alloc] init];
            [tmpDataSet resize:(size_t)newNumSamples];
            [self.systemValues addObject:tmpDataSet];
            
            tmpDataSet = [[XRGDataSet alloc] init];
            [tmpDataSet resize:(size_t)newNumSamples];
            [self.niceValues addObject:tmpDataSet];
        }
    }
        
    numSamples  = newNumSamples;
}

- (void)graphUpdate:(NSTimer *)aTimer {
    [self calculateCPUUsageForCPUs:&lastSlowCPUInfo count:self.numberOfCPUs];
	
    for (NSInteger i = 0; i < self.numberOfCPUs; i++) {
        [self.userValues[i]   setNextValue:immediateUser[i]];
        [self.systemValues[i] setNextValue:immediateSystem[i]];
        [self.niceValues[i]   setNextValue:immediateNice[i]];
    }
                
    if (self.uptime) [self setCurrentUptime];
    if (self.loadAverage) self.currentLoadAverage = [self getLoadAverage];
}

- (void)fastUpdate:(NSTimer *)aTimer {
    [self calculateCPUUsageForCPUs:&lastFastCPUInfo count:self.numberOfCPUs];

    for (NSInteger i = 0; i < self.numberOfCPUs; i++) {
		CGFloat difference = _fastValues[i] - (immediateUser[i] + immediateSystem[i] + immediateNice[i]);
		
		if (difference < 5. && difference > -5.) {
			_fastValues[i] = immediateUser[i] + immediateSystem[i] + immediateNice[i];
		}
		else {
			_fastValues[i] = _fastValues[i] + (0.25 * (immediateUser[i] + immediateSystem[i] + immediateNice[i] - _fastValues[i]));
		}
		
		if (_fastValues[i] < 0 || _fastValues[i] > 100) {
			CGFloat sum = immediateUser[i] + immediateSystem[i] + immediateNice[i];
			
			if (sum < 0) sum = 0;
			if (sum > 100) sum = 100;
			
			_fastValues[i] = sum;
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

- (void)reset {
    for (XRGDataSet *set in self.userValues) {
        [set reset];
    }

    for (XRGDataSet *set in self.systemValues) {
        [set reset];
    }

    for (XRGDataSet *set in self.niceValues) {
        [set reset];
    }
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

        self.uptimeDays = uptimeInSeconds / (60 * 60 * 24);
        uptimeInSeconds %= (60 * 60 * 24);
        
        self.uptimeHours = uptimeInSeconds / (60 * 60);
        uptimeInSeconds %= (60 * 60);
        
        self.uptimeMinutes = uptimeInSeconds / 60;
        uptimeInSeconds %= 60;
        
        self.uptimeSeconds = uptimeInSeconds;
    }
    else {
		self.uptimeDays = 0;
		self.uptimeHours = 0;
		self.uptimeMinutes = 0;
		self.uptimeSeconds = 0;
    }
}

// Returns an NSArray of XRGDataSet objects.
// The first XRGDataSet is system cpu usage, the second is user cpu usage, and the third is nice cpu usage.
- (NSArray *)dataForCPU:(NSInteger)cpuNumber {
	if ((cpuNumber >= self.systemValues.count) || (cpuNumber >= self.userValues.count) || (cpuNumber >= self.niceValues.count)) {
		return nil;
	}
	
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:3];
    
	XRGDataSet *sys = self.systemValues[cpuNumber];
	if (sys) [a addObject:sys];
	else return nil;
	
	XRGDataSet *usr = self.userValues[cpuNumber];
    if (usr) [a addObject:usr];
	else return nil;
	
    XRGDataSet *nice = self.niceValues[cpuNumber];
	if (nice) [a addObject:nice];
	else return nil;
    
    return a;
}

// Return an array of 3 XRGDataSets with combined data for all the CPUs.
- (NSArray *)combinedData {
	if (!self.systemValues.count || !self.userValues.count || !self.niceValues.count) return nil;
	
	XRGDataSet *tmpSystem = [[XRGDataSet alloc] initWithContentsOfOtherDataSet:self.systemValues[0]];
	XRGDataSet *tmpUser = [[XRGDataSet alloc] initWithContentsOfOtherDataSet:self.userValues[0]];
	XRGDataSet *tmpNice = [[XRGDataSet alloc] initWithContentsOfOtherDataSet:self.niceValues[0]];
	
	for (NSInteger i = 1; i < self.numberOfCPUs; i++) {
		[tmpSystem addOtherDataSetValues:self.systemValues[i]];
		[tmpUser addOtherDataSetValues:self.userValues[i]];
		[tmpNice addOtherDataSetValues:self.niceValues[i]];
	}
	
	[tmpSystem divideAllValuesBy:self.numberOfCPUs];
	[tmpUser divideAllValuesBy:self.numberOfCPUs];
	[tmpNice divideAllValuesBy:self.numberOfCPUs];
	
	if (tmpSystem == nil || tmpUser == nil || tmpNice == nil) return nil;
	
	NSArray *a = @[tmpSystem, tmpUser, tmpNice];
	return a;
}

@end

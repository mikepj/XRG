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
//  XRGMemoryMiner.m
//

#import "XRGMemoryMiner.h"
#include <sys/sysctl.h>

@implementation XRGMemoryMiner

- (instancetype)init {
	self = [super init];
	if (self) {
		host = mach_host_self();
	   
		values1 = [[XRGDataSet alloc] init];
		values2 = [[XRGDataSet alloc] init];
		values3 = [[XRGDataSet alloc] init];
		
		self.usedSwap = 0;
		self.totalSwap = 0;
		
		int mib[2] = { CTL_HW, HW_PAGESIZE };
		size_t sz = sizeof(pageSize);
		if (-1 == sysctl(mib, 2, &pageSize, &sz, NULL, 0))
			pageSize = vm_page_size;
		
		[self getLatestMemoryInfo];
	}
    
    return self;
}

- (void)setDataSize:(int)newNumSamples {
    if (newNumSamples < 0) return;
    
    if(values1 && values2 && values3) {
        [values1 resize:(size_t)newNumSamples];
        [values2 resize:(size_t)newNumSamples];
        [values3 resize:(size_t)newNumSamples];
    }
    else {
        values1 = [[XRGDataSet alloc] init];
        values2 = [[XRGDataSet alloc] init];
        values3 = [[XRGDataSet alloc] init];
        
        [values1 resize:(size_t)newNumSamples];
        [values2 resize:(size_t)newNumSamples];
        [values3 resize:(size_t)newNumSamples];
    }
            
    numSamples  = newNumSamples;
}

- (void)reset {
    [values1 reset];
    [values2 reset];
    [values3 reset];
}

- (void)getLatestMemoryInfo {
    kern_return_t kr;
    vm_statistics_data_t stats;
    unsigned int numBytes = HOST_VM_INFO_COUNT;
    
    kr = host_statistics(host, HOST_VM_INFO, (host_info_t)&stats, &numBytes);
    if (kr != KERN_SUCCESS) {
        return;
    }
    else {
        currentDiffs.free_count      = (stats.free_count - lastStats.free_count);
        currentDiffs.active_count    = (stats.active_count - lastStats.active_count);
        currentDiffs.inactive_count  = (stats.inactive_count - lastStats.inactive_count);
        currentDiffs.wire_count      = (stats.wire_count - lastStats.wire_count);
        currentDiffs.faults          = (stats.faults - lastStats.faults);
        currentDiffs.pageins         = (stats.pageins - lastStats.pageins);
        currentDiffs.pageouts        = (stats.pageouts - lastStats.pageouts);
            
        lastStats.free_count         = stats.free_count;
        lastStats.active_count       = stats.active_count;
        lastStats.inactive_count     = stats.inactive_count;
        lastStats.wire_count         = stats.wire_count;
        lastStats.faults             = stats.faults;
        lastStats.pageins            = stats.pageins;
        lastStats.pageouts           = stats.pageouts;
        lastStats.lookups            = stats.lookups;
        lastStats.hits               = stats.hits;
    }

    if (values1) [values1 setNextValue:currentDiffs.faults];
    if (values2) [values2 setNextValue:currentDiffs.pageins];
    if (values3) [values3 setNextValue:currentDiffs.pageouts];
	
	// Swap space monitoring.
	int vmmib[2] = { CTL_VM, VM_SWAPUSAGE };
    struct xsw_usage swapInfo;
    size_t swapLength = sizeof(swapInfo);
    if (sysctl(vmmib, 2, &swapInfo, &swapLength, NULL, 0) >= 0) {
		self.usedSwap = swapInfo.xsu_used;
		self.totalSwap = swapInfo.xsu_total;
//		NSLog(@"Used: %d (%3.2fM)    Total: %d (%3.2fM)", usedSwap, (float)usedSwap / 1024. / 1024., totalSwap, (float)totalSwap / 1024. / 1024.);
    }
}

// actually kilobytes, not bytes
- (UInt64)freeBytes {
    return (NSUInteger)lastStats.free_count * pageSize;
}

- (UInt64)activeBytes {
    return (NSUInteger)lastStats.active_count * pageSize;
}

- (UInt64)inactiveBytes {
    return (NSUInteger)lastStats.inactive_count * pageSize;
}

- (UInt64)wiredBytes {
    return (NSUInteger)lastStats.wire_count * pageSize;
}

- (UInt32)totalFaults {
    return lastStats.faults;
}

- (UInt32)recentFaults {
    return currentDiffs.faults;
}

- (UInt32)totalPageIns {
    return lastStats.pageins;
}

- (UInt32)recentPageIns {
    return currentDiffs.pageins;
}

- (UInt32)totalPageOuts {
    return lastStats.pageouts;
}

- (UInt32)recentPageOuts {
    return currentDiffs.pageouts;
}

- (UInt32)totalCacheLookups {
    return lastStats.lookups;
}

- (UInt32)totalCacheHits {
    return lastStats.hits;
}

- (XRGDataSet *)faultData {
    return values1;
}

- (XRGDataSet *)pageInData {
    return values2;
}

- (XRGDataSet *)pageOutData {
    return values3;
}

@end

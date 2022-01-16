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
//  XRGMemoryMiner.h
//

#import <Foundation/Foundation.h>
#import <mach/host_info.h>
#import <mach/mach_host.h>
#import "XRGDataSet.h"

@interface XRGMemoryMiner : NSObject {
@private
    int							numSamples;

    XRGDataSet                  *values1;
    XRGDataSet                  *values2;
    XRGDataSet                  *values3;
    
    host_name_port_t			host;
    vm_statistics_data_t		currentDiffs;
    vm_statistics_data_t		lastStats;
	
	unsigned long				pageSize;
}

@property UInt64 usedSwap;
@property UInt64 totalSwap;

- (void)getLatestMemoryInfo;
- (void)setDataSize:(int)newNumSamples;
- (void)reset;

// actually kilobytes, not bytes - limited to 4TB with 32bit
- (UInt64)freeBytes;
- (UInt64)activeBytes;
- (UInt64)inactiveBytes;
- (UInt64)wiredBytes;
- (UInt32)totalFaults;
- (UInt32)recentFaults;
- (UInt32)totalPageIns;
- (UInt32)recentPageIns;
- (UInt32)totalPageOuts;
- (UInt32)recentPageOuts;
- (UInt32)totalCacheLookups;
- (UInt32)totalCacheHits;
- (XRGDataSet *)faultData;
- (XRGDataSet *)pageInData;
- (XRGDataSet *)pageOutData;

@end

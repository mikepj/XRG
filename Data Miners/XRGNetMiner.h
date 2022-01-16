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
//  XRGNetMiner.h
//

#import <Foundation/Foundation.h>
#import "definitions.h"
#import "XRGDataSet.h"

@interface XRGNetMiner : NSObject {
    @private
    io_stats                i_net, o_net;
    NSInteger               pppInterfaceNum;
    NSInteger               sendBytes;
    NSInteger               recvBytes;
    int                     mib[6];
    char                    *buf;
    size_t                  alloc;
    
    BOOL                    firstTimeStats;
    
    NSMutableArray          *networkInterfaces;
}

@property UInt64 totalBytesSinceBoot;
@property UInt64 totalBytesSinceLoad;

@property NSString *monitorNetworkInterface;

@property (readonly) NSInteger numInterfaces;
@property (readonly) network_interface_stats *interfaceStats;

@property (readonly) XRGDataSet *rxValues;
@property (readonly) XRGDataSet *txValues;
@property (readonly) XRGDataSet *totalValues;          // rxValues + txValues

- (void)getLatestNetInfo;
- (void)setDataSize:(NSInteger)newNumSamples;
- (CGFloat)maxBandwidth;
- (CGFloat)currentTX;
- (CGFloat)currentRX;
- (void)reset;

- (NSArray *)networkInterfaces;

@end

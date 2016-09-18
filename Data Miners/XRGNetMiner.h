//
//  XRGNetMiner.h
//  XRG
//
//  Created by Mike Piatek-Jimenez on 9/17/16.
//  Copyright © 2016 Gaucho Software. All rights reserved.
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

- (NSArray *)networkInterfaces;

@end

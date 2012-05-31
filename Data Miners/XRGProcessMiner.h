//
//  XRGProcessMiner.h
//  XRG
//
//  Created by Mike Piatek-Jimenez on 7/1/07.
//  Copyright 2007-2009 Gaucho Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define XRGProcessPercentCPU			@"%cpu"
#define XRGProcessResidentMemorySize	@"rss"
#define XRGProcessVirtualMemorySize		@"vsz"
#define XRGProcessTotalSwaps			@"nswap"
#define XRGProcessUser					@"user"
#define XRGProcessID					@"pid"
#define XRGProcessCommand				@"command"

@interface XRGProcessMiner : NSObject {
	NSArray			*processes;
}

- (void) graphUpdate:(NSTimer *)aTimer;

- (NSArray *) processesSortedByCPUUsage;
- (NSArray *) processesSortedByMemoryUsage;

- (NSArray *) processes;
- (void) setProcesses:(NSArray *)values;

@end

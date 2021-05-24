/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2016 Gaucho Software, LLC.
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
//  XRGBatteryView.h
//

#import <Cocoa/Cocoa.h>
#import "definitions.h"
#import "XRGGenericView.h"

typedef NS_ENUM(NSInteger, XRGBatteryStatus) {
    XRGBatteryStatusUnknown = 0,
    XRGBatteryStatusRunningOnBattery = 1,
    XRGBatteryStatusCharging = 2,
    XRGBatteryStatusCharged = 3,
    XRGBatteryStatusOnHold = 4,
    XRGBatteryStatusNoBattery = 5
};

#define SMALL				0
#define NORMAL				1
#define WIDE				2

@interface XRGBatteryView : XRGGenericView {
@private
    NSSize                  graphSize;
    NSInteger               numSamples;
    XRGModule               *m;
    
    // Cache Variables
    //NSMutableDictionary     *textWidthCache;
    CGFloat                 NBF_WIDE;
    CGFloat                 NBF_NORMAL;
    CGFloat                 PERCENT_WIDE;
    CGFloat                 CHARGED_WIDE;
    CGFloat                 ESTIMATING_WIDE;
    CGFloat                 ESTIMATING_NORMAL;
    CGFloat                 POWER_WIDE;
    CGFloat                 CURRENT_WIDE;
    CGFloat                 CURRENT_NORMAL;
    CGFloat                 CAPACITY_WIDE;
    CGFloat                 CAPACITY_NORMAL;
    CGFloat                 NBIF_WIDE;
    CGFloat                 NBIF_NORMAL;
    CGFloat                 MAH_STRING;
    
    NSInteger               *current;
    NSInteger               *capacity;
    NSInteger               *charge;
    NSInteger               *voltage;
    NSInteger               *amperage;
    
    NSInteger               currentPercent;
    NSInteger               chargeSum;
    NSInteger               capacitySum;
    NSInteger               voltageAverage;
    NSInteger               amperageAverage;
    
    NSInteger               maxVolts;
    NSInteger               maxAmps;
	NSInteger               minAmps;
    
    XRGBatteryStatus        powerStatus;
    NSInteger               lastPowerStatus;
    NSInteger               numBatteries;
    NSInteger               displayMode;
    NSInteger               minutesRemaining;
    NSInteger               tripleCount;
    
    NSInteger               graphPixelTimeFrame;
    NSInteger               statsUpdateTimeFrame;
    CGFloat                 currentPixelTime;
    CGFloat                 currentStatsTime;
}

@property XRGDataSet        *chargeWatts;
@property XRGDataSet        *dischargeWatts;

- (void)setGraphSize:(NSSize)newSize;
- (void)setWidth:(int)newWidth;
- (void)updateMinSize;
- (void)graphUpdate:(NSTimer *)aTimer;

@end

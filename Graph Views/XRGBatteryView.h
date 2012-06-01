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
//  XRGBatteryView.h
//

#import <Cocoa/Cocoa.h>
#import "definitions.h"
#import "XRGGenericView.h"

#define UNKNOWN				0
#define RUNNING_ON_BATTERY	1
#define CHARGING			2
#define CHARGED				3
#define NO_BATTERY			4

#define SMALL				0
#define NORMAL				1
#define WIDE				2

@interface XRGBatteryView : XRGGenericView {
@private
    NSSize                  graphSize;
    int                     numSamples;
    XRGModule               *m;
    
    // Cache Variables
    //NSMutableDictionary     *textWidthCache;
    float                   NBF_WIDE;
    float                   NBF_NORMAL;
    float                   PERCENT_WIDE;
    float                   CHARGED_WIDE;
    float                   ESTIMATING_WIDE;
    float                   ESTIMATING_NORMAL;
    float                   VOLTAGE_WIDE;
    float                   VOLTAGE_NORMAL;
    float                   AMPERAGE_WIDE;
    float                   AMPERAGE_NORMAL;
    float                   CURRENT_WIDE;
    float                   CURRENT_NORMAL;
    float                   CAPACITY_WIDE;
    float                   CAPACITY_NORMAL;
    float                   NBIF_WIDE;
    float                   NBIF_NORMAL;
    float                   MAH_STRING;
    
    int                     *values;
    int                     currentIndex;
    int                     maxVal;
    
    int                     *current;
    int                     *capacity;
    int                     *charge;
    int                     *voltage;
    int                     *amperage;
    
    int                     currentPercent;
    int                     chargeSum;
    int                     capacitySum;
    int                     voltageAverage;
    int                     amperageAverage;
    
    int                     maxVolts;
    int                     maxAmps;
	int						minAmps;
    
    int                     powerStatus;
    int                     lastPowerStatus;
    int                     numBatteries;
    int                     displayMode;
    int                     minutesRemaining;
    int                     tripleCount;
    
    int                     graphPixelTimeFrame;
    int                     statsUpdateTimeFrame;
    float                   currentPixelTime;
    float                   currentStatsTime;
}
- (void)setGraphSize:(NSSize)newSize;
- (void)setWidth:(int)newWidth;
- (void)updateMinSize;
- (void)graphUpdate:(NSTimer *)aTimer;

@end

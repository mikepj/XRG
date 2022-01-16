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
//  XRGBatteryView.h
//

#import <Cocoa/Cocoa.h>
#import "definitions.h"
#import "XRGGenericView.h"
#import "XRGBatteryMiner.h"

#define SMALL				0
#define NORMAL				1
#define WIDE				2

@interface XRGBatteryView : XRGGenericView {
@private
    NSSize                  graphSize;
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
            
    NSInteger               lastPowerStatus;
    NSInteger               displayMode;
    NSInteger               tripleCount;
    
    NSInteger               graphPixelTimeFrame;
    NSInteger               statsUpdateTimeFrame;
    CGFloat                 currentPixelTime;
    CGFloat                 currentStatsTime;
}

@property XRGBatteryMiner   *batteryMiner;

- (void)setGraphSize:(NSSize)newSize;
- (void)setWidth:(NSInteger)newWidth;
- (void)updateMinSize;
- (void)graphUpdate:(NSTimer *)aTimer;

@end

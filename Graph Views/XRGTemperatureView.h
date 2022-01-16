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
//  XRGTemperatureView.h
//

#import <Cocoa/Cocoa.h>
#import "XRGGenericView.h"
#import "XRGTemperatureMiner.h"

@interface XRGTemperatureView : XRGGenericView
{
    NSSize                      graphSize;
    
    float                       temperatureWidth;
    float                       rpmWidth;
    NSInteger                   graphWidth;
    NSMutableDictionary			*locationSizeCache;
    
    XRGModule                   *m;
    
    NSInteger                   numSamples;
    BOOL                        showFanSpeed;
    NSInteger                   updateCounter;
}

+ (BOOL)showUnknownSensors;

- (void)setGraphSize:(NSSize)newSize;
- (void)setWidth:(NSInteger)newWidth;
- (void)updateMinSize;
//- (int) getWidthForLabel:(NSString *)label;

- (void)graphUpdate:(NSTimer *)aTimer;
- (void)openTemperaturePreferences:(NSEvent *)theEvent;

@end

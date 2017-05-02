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
//  XRGGenericView.h
//


#import <AppKit/AppKit.h>
#define NOVALUE -1000

#define XRG_MINI_HEIGHT ([appSettings textRectHeight])

#import "XRGModule.h"
#import "XRGSettings.h"
#import "XRGModuleManager.h"
#import "XRGAppDelegate.h"
#import "XRGDataSet.h"

@interface XRGGenericView : NSView {
@protected
    XRGSettings         *appSettings;
    XRGModuleManager    *moduleManager;
    id                  parentWindow;
}

- (void) drawGraphWithData:(CGFloat *)samples size:(NSInteger)nSamples currentIndex:(NSInteger)cIndex maxValue:(CGFloat)max inRect:(NSRect)rect flipped:(BOOL)flipped color:(NSColor *)color;

- (void) drawGraphWithDataFromDataSet:(XRGDataSet *)dataSet maxValue:(CGFloat)max inRect:(NSRect)rect flipped:(BOOL)flipped filled:(BOOL)filled color:(NSColor *)color;

- (void) drawRangedGraphWithData:(CGFloat *)samples size:(NSInteger)nSamples currentIndex:(NSInteger)cIndex upperBound:(CGFloat)max lowerBound:(CGFloat)min inRect:(NSRect)rect flipped:(BOOL)flipped filled:(BOOL)filled color:(NSColor *)color;

- (void) drawRangedGraphWithDataFromDataSet:(XRGDataSet *)dataSet upperBound:(CGFloat)max lowerBound:(CGFloat)min inRect:(NSRect)rect flipped:(BOOL)flipped filled:(BOOL)filled color:(NSColor *)color;

- (void) drawMiniGraphWithValues:(NSArray<NSNumber *> *)values upperBound:(double)max lowerBound:(double)min leftLabel:(NSString *)leftLabel printValueBytes:(UInt64)printValue printValueIsRate:(BOOL)isRate;

- (void) drawMiniGraphWithValues:(NSArray<NSNumber *> *)values upperBound:(double)max lowerBound:(double)min leftLabel:(NSString *)leftLabel rightLabel:(NSString *)rightLabel;

- (void) fillRect:(NSRect)rect withColor:(NSColor *)color;

- (void)drawLeftText:(NSString *)leftText centerText:(NSString *)centerText rightText:(NSString *)rightText inRect:(CGRect)rect;

- (BOOL)shouldDrawMiniGraph;
- (NSRect)paddedTextRect;

// The following methods are to be implemented in subclasses.
- (void) setGraphSize:(NSSize)newSize;
- (void) updateMinSize;
- (void) graphUpdate:(NSTimer *)aTimer;
- (void) fastUpdate:(NSTimer *)aTimer;
- (void) min5Update:(NSTimer *)aTimer;
- (void) min30Update:(NSTimer *)aTimer;

@end

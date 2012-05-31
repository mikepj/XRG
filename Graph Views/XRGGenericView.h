/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2009 Gaucho Software, LLC.
 * XRGGenericView created by Anthony Hodsdon on Mon Apr 28 2003.
 *
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
    bool                isHidden;
}

-(void)drawGraphWithData: (float *)samples Size:(int)nSamples CurrentIndex:(int)cIndex MaxValue:(float)max InRect:(NSRect)rect Flipped:(BOOL)flipped Color:(NSColor *)color;

-(void)drawGraphWithDataFromDataSet:(XRGDataSet *)dataSet MaxValue:(float)max InRect:(NSRect)rect Flipped:(BOOL)flipped Filled:(BOOL)filled Color:(NSColor *)color;

-(void)drawRangedGraphWithData:(float *)samples Size:(int)nSamples CurrentIndex:(int)cIndex UpperBound:(float)max LowerBound:(float)min InRect:(NSRect)rect Flipped:(BOOL)flipped Filled:(BOOL)filled Color:(NSColor *)color;

-(void)drawRangedGraphWithDataFromDataSet:(XRGDataSet *)dataSet UpperBound:(float)max LowerBound:(float)min InRect:(NSRect)rect Flipped:(BOOL)flipped Filled:(BOOL)filled Color:(NSColor *)color;

-(void)fillRect:(NSRect)rect withColor:(NSColor *)color;

-(BOOL)isHidden;
-(void)setHidden:(bool)yesNo;

// The following methods are to be implemented in subclasses.
- (void)setGraphSize:(NSSize)newSize;
- (void)updateMinSize;
- (void)graphUpdate:(NSTimer *)aTimer;
- (void)fastUpdate:(NSTimer *)aTimer;
- (void)min5Update:(NSTimer *)aTimer;
- (void)min30Update:(NSTimer *)aTimer;

@end

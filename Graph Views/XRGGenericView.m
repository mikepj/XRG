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
//  XRGGenericView.m
//

#import "XRGGenericView.h"


@implementation XRGGenericView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

-(void)drawGraphWithData:(float *)samples Size:(int)nSamples CurrentIndex:(int)cIndex MaxValue:(float)max InRect:(NSRect)rect Flipped:(BOOL)flipped Color:(NSColor *)color
{
    // call drawRangedGraphWithData to avoid a lot of code duplication.
    [self drawRangedGraphWithData:samples Size:nSamples CurrentIndex:cIndex UpperBound:max LowerBound:0 InRect:rect Flipped:flipped Filled:YES Color:color];
}

-(void)drawGraphWithDataFromDataSet:(XRGDataSet *)dataSet MaxValue:(float)max InRect:(NSRect)rect Flipped:(BOOL)flipped Filled:(BOOL)filled Color:(NSColor *)color
{
    size_t numVals = [dataSet numValues];
    CGFloat *values = alloca(numVals * sizeof(CGFloat));
    [dataSet valuesInOrder:values];

    // call drawRangedGraphWithData to avoid a lot of code duplication.
    [self drawRangedGraphWithData:values Size:numVals CurrentIndex:numVals - 1 UpperBound:max LowerBound:0 InRect:rect Flipped:flipped Filled:filled Color:color];
}


// Adapted from original drawGraphWithData, but added UpperBound and LowerBound in place of Max, and Filled
-(void)drawRangedGraphWithData:(float *)samples Size:(int)nSamples CurrentIndex:(int)cIndex UpperBound:(float)max LowerBound:(float)min InRect:(NSRect)rect Flipped:(BOOL)flipped Filled:(BOOL)filled Color:(NSColor *)color;
{
    int filledOffset = 0;
    int currentPointIndex;

    NSPoint origin = rect.origin;
    if (flipped)
        origin.y += rect.size.height;

    NSPoint *points;
    if (filled) {
        // Allocate points on to the stack, so we don't have to free (also much cheaper than malloc)
        points = (NSPoint *)alloca((nSamples+2)*sizeof(NSPoint));

        points[0] = origin;
        points[nSamples+1] = NSMakePoint(origin.x + rect.size.width, origin.y);
    }
    else {
        // Allocate points on to the stack, so we don't have to free (also much cheaper than malloc)
        points = (NSPoint *)alloca(nSamples * sizeof(NSPoint));
        filledOffset = 1;
    }

    int i, j;
    float height;
    float height_scaled;
    float dx = rect.size.width / nSamples;
    float x;

    float scale = rect.size.height / (max - min);
    if (flipped)
        scale *= -1.0f;

    for (i = currentPointIndex = 1 - filledOffset, x= origin.x; i <= nSamples - filledOffset; ++i, x+=dx)
    {
        j = (i + cIndex + filledOffset) % nSamples;
        
        if (samples[j] != NOVALUE) {
            height = samples[j] - min;
            height_scaled = (height >=  0.0f ? height * scale : 0.0f);

            if (height_scaled + origin.y < rect.origin.y) {
                points[currentPointIndex++] = NSMakePoint(x, rect.origin.y);
            }
            else if (height_scaled + origin.y > rect.origin.y + rect.size.height) {
                points[currentPointIndex++] = NSMakePoint(x, rect.origin.y + rect.size.height);
            }
            else {
                points[currentPointIndex++] = NSMakePoint(x, height_scaled + origin.y);
            }
        }
    }
    // close any gap at the edge of the graph resulting from floating point rounding of dx
    points[currentPointIndex - 1].x = origin.x + rect.size.width;
    
    if (filled) {
        points[currentPointIndex] = NSMakePoint(origin.x + rect.size.width, origin.y);
    }

    [color set];
    NSBezierPath *bp = [NSBezierPath bezierPath];
    [bp setLineWidth:0.0f];
    [bp setFlatness: 0.6f];
    [bp appendBezierPathWithPoints:points count:(currentPointIndex + (1 - filledOffset))];
    if (filled) {
        [bp closePath];
        [bp fill];
    }
    else 
        [bp stroke];
        
    [bp removeAllPoints];
}

-(void)drawRangedGraphWithDataFromDataSet:(XRGDataSet *)dataSet UpperBound:(float)max LowerBound:(float)min InRect:(NSRect)rect Flipped:(BOOL)flipped Filled:(BOOL)filled Color:(NSColor *)color 
{
    size_t numVals = [dataSet numValues];
    CGFloat *values = alloca(numVals * sizeof(CGFloat));
    [dataSet valuesInOrder:values];
	
    // call drawRangedGraphWithData to avoid a lot of code duplication.
	[self drawRangedGraphWithData:values Size:numVals CurrentIndex:numVals - 1 UpperBound:max LowerBound:min InRect:rect Flipped:flipped Filled:filled Color:color];
}

-(void)fillRect:(NSRect)rect withColor:(NSColor *)color {
    NSPoint *pointsA;
    NSPoint *pointsB;

    // Allocate points on to the stack, so we don't have to free (also much cheaper than malloc)
    pointsA = (NSPoint *)alloca(2 * sizeof(NSPoint));
    pointsB = (NSPoint *)alloca(2 * sizeof(NSPoint));

    pointsA[0] = rect.origin;
    pointsA[1] = NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height);
    pointsB[0] = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
    pointsB[1] = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y);

    [color set];
    NSBezierPath *bp = [NSBezierPath bezierPath];
    [bp setLineWidth:0.0f];
    [bp appendBezierPathWithPoints:pointsA count:2];
    [[NSColor blackColor] set];
    [bp appendBezierPathWithPoints:pointsB count:2];
    [bp fill];
}

-(BOOL)isHidden {
    return isHidden;
}

-(void)setHidden:(bool)yesNo {
    isHidden = yesNo;
}

// The following methods are to be implemented in subclasses.
- (void)setGraphSize:(NSSize)newSize {
#ifdef XRG_DEBUG
	NSLog(@"Subclass should override setGraphSize.");
#endif
}

- (void)updateMinSize {
#ifdef XRG_DEBUG
	NSLog(@"Subclass should override updateMinSize.");
#endif
}

- (void)graphUpdate:(NSTimer *)aTimer {
#ifdef XRG_DEBUG
	NSLog(@"Subclass should override graphUpdate.");
#endif
}

- (void)fastUpdate:(NSTimer *)aTimer {
#ifdef XRG_DEBUG
	NSLog(@"Subclass should override fastUpdate.");
#endif
}

- (void)min5Update:(NSTimer *)aTimer {
#ifdef XRG_DEBUG
	NSLog(@"Subclass should override min5Update.");
#endif
}

- (void)min30Update:(NSTimer *)aTimer {
#ifdef XRG_DEBUG
	NSLog(@"Subclass should override min30Update.");
#endif
}

@end

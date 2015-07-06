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
//  XRGGraphicsView.m
//

#import "XRGGPUView.h"
#import "XRGGraphWindow.h"

@implementation XRGGPUView

- (void)awakeFromNib {
	graphicsMiner = [[XRGGPUMiner alloc] init];
	
	parentWindow = (XRGGraphWindow *)[self window];
	[parentWindow setGpuView:self];
	[parentWindow initTimers];
	appSettings = [parentWindow appSettings];
	moduleManager = [parentWindow moduleManager];
	
	textRectHeight = [appSettings textRectHeight];
	
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	m = [[XRGModule alloc] initWithName:@"GPU" andReference:self];
	[m setDoesFastUpdate:NO];
	[m setDoesGraphUpdate:YES];
	[m setDoesMin5Update:NO];
	[m setDoesMin30Update:NO];
	[m setDisplayOrder:1];
	[self updateMinSize];
	[m setIsDisplayed: (bool)[defs boolForKey:XRG_showGPUGraph]];
	
	[[parentWindow moduleManager] addModule:m];
	[self setGraphSize:[m currentSize]];
}

- (void)setGraphSize:(NSSize)newSize {
	NSSize tmpSize;
	tmpSize.width = newSize.width;
	tmpSize.height = newSize.height;
	if (tmpSize.width < 23) tmpSize.width = 23;
	if (tmpSize.width > 2000) tmpSize.width = 2000;
	[self setWidth:tmpSize.width];
	graphSize = tmpSize;
}

- (void)setWidth:(int)newWidth {
	int newNumSamples = newWidth;
	if (newNumSamples < 0) return;
	
	numSamples = newNumSamples;
	
	[graphicsMiner setDataSize:newNumSamples];
}

- (void)updateMinSize {
	float width, height;
	height = [appSettings textRectHeight] * 2;
	width = [@"W: 9999M" sizeWithAttributes:[appSettings alignRightAttributes]].width + 19 + 6;
	
	[m setMinWidth: width];
	[m setMinHeight: height];
}

- (void)graphUpdate:(NSTimer *)aTimer {
	[graphicsMiner getLatestGraphicsInfo];
	
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect {
	if ([self isHidden]) return;
	
	NSGraphicsContext *gc = [NSGraphicsContext currentContext];
	
#ifdef XRG_DEBUG
	NSLog(@"In Graphics DrawRect.");
#endif
	
	NSArray *totalValues = [graphicsMiner totalVRAMDataSets];
	NSArray *freeValues = [graphicsMiner freeVRAMDataSets];
	if ((totalValues.count != freeValues.count) || (totalValues.count == 0)) {
		[@"GPU n/a" drawInRect:self.bounds withAttributes:[appSettings alignCenterAttributes]];
		return;
	}
	
	CGFloat graphHeight = graphSize.height / totalValues.count;
	for (NSInteger i = 0; i < totalValues.count; i++) {
		NSRect graphRect = NSMakeRect(0, (totalValues.count - i - 1) * floor(graphHeight), numSamples, floor(graphHeight) - 1);
		[[appSettings graphBGColor] set];
		NSRectFill(graphRect);

		// Draw the graph.
		[gc setShouldAntialias:[appSettings antiAliasing]];

		XRGDataSet *usedDataSet = [[XRGDataSet alloc] initWithContentsOfOtherDataSet:totalValues[i]];
		[usedDataSet subtractOtherDataSetValues:freeValues[i]];
		if ([usedDataSet max] > 0) {
			[self drawGraphWithDataFromDataSet:usedDataSet maxValue:[totalValues[i] max] inRect:graphRect flipped:NO filled:YES color:[appSettings graphFG1Color]];
		}
		else {
			[[appSettings backgroundColor] set];
			NSRectFill(NSMakeRect(graphRect.origin.x, graphRect.origin.y, graphRect.size.width, 1.));
		}
		
		// Draw the text
		[gc setShouldAntialias:[appSettings antialiasText]];
		NSRect textRect = graphRect;
		textRect.origin.x += 3;
		textRect.size.width -= 6;
		CGFloat t = [(XRGDataSet *)totalValues[i] currentValue];
		CGFloat f = [(XRGDataSet *)freeValues[i] currentValue];
		
		if (textRect.size.width < 90) {
			[[NSString stringWithFormat:@"GPU %d", (int)i] drawInRect:textRect withAttributes:[appSettings alignLeftAttributes]];
			if (t > 0) {
				[[NSString stringWithFormat:@"%dM", (int)((t - f) / 1024. / 1024.)] drawInRect:textRect withAttributes:[appSettings alignRightAttributes]];
			}
		}
		else {
			[[NSString stringWithFormat:@"GPU %d", (int)i] drawInRect:textRect withAttributes:[appSettings alignCenterAttributes]];

			if (t > 0) {
				[[NSString stringWithFormat:@"%dM", (int)((t - f) / 1024. / 1024.)] drawInRect:textRect withAttributes:[appSettings alignLeftAttributes]];
				[[NSString stringWithFormat:@"%d%%", (int)((t - f) / t * 100.)] drawInRect:textRect withAttributes:[appSettings alignRightAttributes]];
			}
		}
	}

	[gc setShouldAntialias:YES];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent {
	[parentWindow mouseDown:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent {
	[parentWindow mouseDragged:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent {
	[parentWindow mouseUp:theEvent];
}

@end

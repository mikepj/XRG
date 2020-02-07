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
//  XRGMemoryView.m
//


#import "XRGMemoryView.h"
#import "XRGGraphWindow.h"

@implementation XRGMemoryView

- (void)awakeFromNib { 
    memoryMiner = [[XRGMemoryMiner alloc] init];
	processMiner = [[XRGProcessMiner alloc] init];
    
    parentWindow = (XRGGraphWindow *)[self window];
    [parentWindow setMemoryView:self];
    [parentWindow initTimers]; 
    appSettings = [parentWindow appSettings]; 
    moduleManager = [parentWindow moduleManager];
                                     
    textRectHeight = [appSettings textRectHeight];
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];    
    m = [[XRGModule alloc] initWithName:@"Memory" andReference:self];
	m.doesFastUpdate = NO;
	m.doesGraphUpdate = YES;
	m.doesMin5Update = NO;
	m.doesMin30Update = NO;
	m.displayOrder = 2;
    [self updateMinSize];
    [m setIsDisplayed: (bool)[defs boolForKey:XRG_showMemoryGraph]];

    [[parentWindow moduleManager] addModule:m];
    [self setGraphSize:[m currentSize]];
    
    // cut out the initial spike
    //[self getLatestMemoryInfo];
}

- (void)setGraphSize:(NSSize)newSize {
    NSSize tmpSize;
    tmpSize.width = newSize.width;
    tmpSize.height = newSize.height;
    if (tmpSize.width < 23) tmpSize.width = 23;
    if (tmpSize.width > 20000) tmpSize.width = 20000;
    [self setWidth:tmpSize.width];
    graphSize = tmpSize;
}

- (void)setWidth:(int)newWidth {
    int newNumSamples = newWidth - 19;
    if (newNumSamples < 0) return;
    
    numSamples = newNumSamples;

    [memoryMiner setDataSize:newNumSamples];
}

- (void)updateMinSize {    
    [m setMinWidth: [@"W: 9999M" sizeWithAttributes:[appSettings alignRightAttributes]].width + 19 + 6];
    [m setMinHeight: [appSettings textRectHeight]];
}

- (void)graphUpdate:(NSTimer *)aTimer {
    [memoryMiner getLatestMemoryInfo];
    
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect {
    if ([self isHidden]) return;

    NSGraphicsContext *gc = [NSGraphicsContext currentContext];

    #ifdef XRG_DEBUG
        NSLog(@"In Memory DrawRect."); 
    #endif
    textRectHeight = [appSettings textRectHeight];
    
    [[appSettings graphBGColor] set];
    NSRect bounds = [self bounds];
    CGContextFillRect(gc.CGContext, bounds);
    
    if ([self shouldDrawMiniGraph]) {
        [self drawMiniGraph:self.bounds];
        return;
    }
    
    [gc setShouldAntialias:[appSettings antiAliasing]];
    
    if ([appSettings showMemoryPagingGraph]) {
        NSColor *colors[3];
        colors[0] = [appSettings graphFG1Color];
        colors[1] = [appSettings graphFG2Color];
        colors[2] = [appSettings graphFG3Color];
        
        NSRect graphRect = NSMakeRect(0, 0, numSamples, graphSize.height);
    
        XRGDataSet *tmpDataSet = [[XRGDataSet alloc] initWithContentsOfOtherDataSet:[memoryMiner faultData]];
        [tmpDataSet addOtherDataSetValues:[memoryMiner pageInData]];
        [tmpDataSet addOtherDataSetValues:[memoryMiner pageOutData]];
        
        [self drawGraphWithDataFromDataSet:tmpDataSet maxValue:[tmpDataSet max] inRect:graphRect flipped:NO filled:YES color:colors[2]];
        
        [tmpDataSet subtractOtherDataSetValues:[memoryMiner pageOutData]];
        
        [self drawGraphWithDataFromDataSet:tmpDataSet maxValue:[tmpDataSet max] inRect:graphRect flipped:NO filled:YES color:colors[1]];
        
        [self drawGraphWithDataFromDataSet:[memoryMiner faultData] maxValue:[tmpDataSet max] inRect:graphRect flipped:NO filled:YES color:colors[0]];
        
    }
    
    // draw the immediate memory status
    CGFloat max = (CGFloat)([memoryMiner wiredBytes] + [memoryMiner activeBytes] + [memoryMiner inactiveBytes] + [memoryMiner freeBytes]);
    NSRect tmpRect = NSMakeRect(numSamples, 0, 2, graphSize.height);
    [[appSettings borderColor] set];
    NSRectFill(tmpRect);
    
	tmpRect.origin.x   += 2;
	tmpRect.size.width  = 8;
	tmpRect.size.height = (max == 0) ? 0 : (CGFloat)[memoryMiner wiredBytes] / max * graphSize.height;
	[[appSettings graphFG1Color] set];
	NSRectFill(tmpRect);
	
	tmpRect.origin.y   += tmpRect.size.height;
	tmpRect.size.height = (max == 0) ? 0 : (CGFloat)[memoryMiner activeBytes] / max * graphSize.height;
	[[appSettings graphFG2Color] set];
	NSRectFill(tmpRect);
	
	tmpRect.origin.y   += tmpRect.size.height;
	tmpRect.size.height = (max == 0) ? 0 : (CGFloat)[memoryMiner inactiveBytes] / max * graphSize.height;
	[[appSettings graphFG3Color] set];
	NSRectFill(tmpRect);
	
	// Draw the swap info.
	[[appSettings borderColor] set];
	tmpRect.origin.x += 8;
	tmpRect.origin.y = 0;
	tmpRect.size.width = 1;
	tmpRect.size.height = graphSize.height;
	NSRectFill(tmpRect);

	tmpRect.origin.x += 1;
	tmpRect.size.width = 8;
	tmpRect.size.height = ([memoryMiner totalSwap] == 0) ? 0 : (double)[memoryMiner usedSwap] / (double)[memoryMiner totalSwap] * graphSize.height;
	[[appSettings graphFG1Color] set];
	NSRectFill(tmpRect);

    // draw the text
    tmpRect.origin.y    = graphSize.height - textRectHeight;
    tmpRect.origin.x    = 3;
    tmpRect.size.height = textRectHeight;
    tmpRect.size.width  = graphSize.width - 19 - 6;
    NSMutableString *s  = [[NSMutableString alloc] init]; 
    [s setString: @"Memory"];
       
    if ([appSettings memoryShowFree]) {
        [s appendFormat:@"\nF: %ldM", (long)[memoryMiner freeBytes] / 1024];
    }
    
    if ([appSettings memoryShowInactive]) {
        [s appendFormat:@"\nI: %ldM", (long)[memoryMiner inactiveBytes] / 1024];
    }
    
    if ([appSettings memoryShowActive]) {
        [s appendFormat:@"\nA: %ldM", (long)[memoryMiner activeBytes] / 1024];
    }
    
    if ([appSettings memoryShowWired]) {
        [s appendFormat:@"\nW: %ldM", (long)[memoryMiner wiredBytes] / 1024];
    }
    
    if ([appSettings memoryShowCache]) {
        [s appendFormat:@"\nCa: %d%%", ([memoryMiner totalCacheLookups] == 0) ? 0 : (int)((float)[memoryMiner totalCacheHits] / (float)[memoryMiner totalCacheLookups] * 100.)];
    }
    
    if ([appSettings memoryShowPage]) {
        if ([appSettings graphRefresh] != 0) {
            if ([memoryMiner recentFaults] * 4 > 1024)
                [s appendFormat:@"\nPF: %4.2fM/s", (float)[memoryMiner recentFaults] / [appSettings graphRefresh] * 4. / 1024.];
            else
                [s appendFormat: @"\nPF: %dK/s", (int)((float)[memoryMiner recentFaults] / [appSettings graphRefresh]) * 4];
        }
    }
	
	// Draw the VM text.
    [s appendFormat:@"\nVu: %dM", (int)((double)[memoryMiner usedSwap] / 1024. / 1024.)];
    [s appendFormat:@"\nVt: %dM", (int)((double)[memoryMiner totalSwap] / 1024. / 1024.)];

    [self drawLeftText:s centerText:nil rightText:nil inRect:[self paddedTextRect]];
    [gc setShouldAntialias:YES];
}

- (void)drawMiniGraph:(NSRect)inRect {
	NSGraphicsContext *gc = [NSGraphicsContext currentContext]; 
		
	CGFloat totalScale = MAX([memoryMiner wiredBytes] + [memoryMiner activeBytes] + [memoryMiner inactiveBytes] + [memoryMiner freeBytes], (CGFloat)[memoryMiner totalSwap] / 1024.);
	
	NSRect bottomBarRect = NSMakeRect(inRect.origin.x, inRect.origin.y, inRect.size.width, roundf(inRect.size.height * 0.4) - 1);
	NSRect topBarRect = NSMakeRect(inRect.origin.x, bottomBarRect.origin.y + bottomBarRect.size.height + 1, inRect.size.width, inRect.origin.y + inRect.size.height - (bottomBarRect.origin.y + bottomBarRect.size.height + 1));
	
	NSRect wiredRect = topBarRect;
	wiredRect.size.width = (totalScale == 0) ? 0 : (CGFloat)[memoryMiner wiredBytes] / totalScale * topBarRect.size.width;
	[[appSettings graphFG1Color] set];
	NSRectFill(wiredRect);
	
	NSRect activeRect = topBarRect;
	activeRect.origin.x = wiredRect.origin.x + wiredRect.size.width;
	activeRect.size.width = (totalScale == 0) ? 0 : (CGFloat)[memoryMiner activeBytes] / totalScale * topBarRect.size.width;
	[[appSettings graphFG2Color] set];
	NSRectFill(activeRect);
	
	NSRect inactiveRect = topBarRect;
	inactiveRect.origin.x = activeRect.origin.x + activeRect.size.width;
	inactiveRect.size.width = (totalScale == 0) ? 0 : (CGFloat)[memoryMiner inactiveBytes] / totalScale * topBarRect.size.width;
	[[appSettings graphFG3Color] set];
	NSRectFill(inactiveRect);
	
	// Draw the swap info.
	bottomBarRect.size.width *= (totalScale == 0) ? 0 : ((CGFloat)[memoryMiner usedSwap] / 1024.) / totalScale;
	[[appSettings graphFG1Color] set];
	NSRectFill(bottomBarRect);
	
	// draw the text
	NSString *leftString = @"Mem";
	NSString *rightString = [NSString stringWithFormat:@"%dM Vu", (int)((double)[memoryMiner usedSwap] / 1024. / 1024.)];
	
    [self drawLeftText:leftString centerText:nil rightText:rightString inRect:[self paddedTextRect]];
	
	[gc setShouldAntialias:YES];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Memory View"];
    NSMenuItem *tMI;

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Top 10 Memory Processes" action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    // Need to get our process list.
	[processMiner graphUpdate:nil];
	NSArray *sortedProcesses = [processMiner processesSortedByMemoryUsage];
	int i;
	for (i = 0; i < 10; i++) {
		NSDictionary *process = sortedProcesses[i];
		u_int32_t memory = [process[XRGProcessResidentMemorySize] intValue];
		int pid = [process[XRGProcessID] intValue];
		NSString *command = process[XRGProcessCommand];
		
		NSString *memoryString;
		if (memory > 1024 * 1024) {
			memoryString = [NSString stringWithFormat:@"%1.1fG", (float)memory / 1024.f / 1024.f];
		}
		else if (memory > 1024) {
			memoryString = [NSString stringWithFormat:@"%1.1fM", (float)memory / 1024.f];
		}
		else {
			memoryString = [NSString stringWithFormat:@"%dK", memory];
		}
		
		tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSString stringWithFormat:@"%@ - %@ (id %d)", memoryString, command, pid] action:@selector(emptyEvent:) keyEquivalent:@""];
		[myMenu addItem:tMI];
	}

    [myMenu addItem:[NSMenuItem separatorItem]];

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Reset Graph" action:@selector(clearData:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open XRG Memory Preferences..." action:@selector(openMemoryPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
     
    return myMenu;
}

- (void)clearData:(NSEvent *)theEvent {
    [memoryMiner reset];
}

- (void)emptyEvent:(NSEvent *)theEvent {
}

- (void)openMemoryPreferences:(NSEvent *)theEvent {
    [[parentWindow controller] showPrefsWithPanel:@"RAM"];
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

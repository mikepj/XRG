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
//  XRGNetView.m
//

#import "XRGGraphWindow.h"
#import "XRGNetView.h"
#import "XRGCommon.h"

@implementation XRGNetView

- (void)awakeFromNib {    
    graphSize    = NSMakeSize(90, 112);
    
    self.miner = [[XRGNetMiner alloc] init];
    self.fastMiner = [[XRGNetMiner alloc] init];
    
    parentWindow = (XRGGraphWindow *)[self window];
    [parentWindow setNetView:self];
    [parentWindow initTimers];  
    appSettings = [parentWindow appSettings];
    moduleManager = [parentWindow moduleManager];
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    m = [[XRGModule alloc] initWithName:@"Network" andReference:self];
	m.doesFastUpdate = YES;
	m.doesGraphUpdate = YES;
	m.doesMin5Update = NO;
	m.doesMin30Update = NO;
	m.displayOrder = 5;
    [self updateMinSize];
    [m setIsDisplayed: (bool)[defs boolForKey:XRG_showNetworkGraph]];

    [[parentWindow moduleManager] addModule:m];
    [self setGraphSize:[m currentSize]];
}

- (void)graphUpdate:(NSTimer *)aTimer {
    self.miner.monitorNetworkInterface = [appSettings networkInterface];
    [self.miner getLatestNetInfo];
    [self setNeedsDisplay: YES];
}

- (void)fastUpdate:(NSTimer *)aTimer {
    if ([self shouldDrawMiniGraph]) {
        self.fastMiner.monitorNetworkInterface = [appSettings networkInterface];
        [self.fastMiner getLatestNetInfo];
        
        fastTXValue = [XRGCommon dampedValueUsingPreviousValue:fastTXValue currentValue:self.fastMiner.currentTX];
        fastRXValue = [XRGCommon dampedValueUsingPreviousValue:fastRXValue currentValue:self.fastMiner.currentRX];
        
        [self setNeedsDisplay: YES];       
    }
}

- (void)setGraphSize:(NSSize)newSize {
    NSSize tmpSize;
    tmpSize.width = newSize.width;
    tmpSize.height = newSize.height;
    if (tmpSize.width < 1) tmpSize.width = 1;
    if (tmpSize.width > 20000) tmpSize.width = 20000;
    [self setWidth:tmpSize.width];
    graphSize = tmpSize;
}

- (void)setWidth:(int)newWidth {
    int newNumSamples = newWidth;
    [self.miner setDataSize:newWidth];
    [self.fastMiner setDataSize:newWidth];

    numSamples  = newNumSamples;
}

- (void)updateMinSize {
    [m setMinWidth: [@"N1023K Rx" sizeWithAttributes:[appSettings alignRightAttributes]].width];
    [m setMinHeight: XRG_MINI_HEIGHT];
}

- (void)drawRect:(NSRect)rect {
    if ([self isHidden]) return;

    #ifdef XRG_DEBUG
        NSLog(@"In Network DrawRect."); 
    #endif

    NSGraphicsContext *gc = [NSGraphicsContext currentContext];
    
    [[appSettings graphBGColor] set];
    NSRect bounds = [self bounds];
    CGContextFillRect(gc.CGContext, bounds);

    if ([self shouldDrawMiniGraph]) {
        [self drawMiniGraph:self.bounds];
        return;
    }

    NSInteger max, tx, rx;
    NSInteger textRectHeight = [appSettings textRectHeight];
    max = MAX([self.miner maxBandwidth], [appSettings netMinGraphScale]);

    NSRect tmpRect = NSMakeRect(0, 0, graphSize.width, textRectHeight * 2);
    tmpRect.origin.x   += 3;
    tmpRect.size.width -= 6;
    tmpRect.size.height = textRectHeight;
    
    [gc setShouldAntialias:[appSettings antiAliasing]];

    NSInteger netGraphMode = [appSettings netGraphMode];

    /* received data */
    if (netGraphMode == 0) {
        [self drawGraphWithDataFromDataSet:self.miner.totalValues maxValue:max inRect:rect flipped:(netGraphMode == 2) filled:YES color:[appSettings graphFG2Color]];
    }
    else {
        [self drawGraphWithDataFromDataSet:self.miner.rxValues maxValue:max inRect:rect flipped:(netGraphMode == 2) filled:YES color:[appSettings graphFG2Color]];
    }

    /* sent data */
    [self drawGraphWithDataFromDataSet:self.miner.txValues maxValue:max inRect:rect flipped:(netGraphMode == 1) filled:YES color:[appSettings graphFG1Color]];

    [gc setShouldAntialias:YES];

        
    // draw the text
    [gc setShouldAntialias:[appSettings antialiasText]];

    NSMutableString *s = [[NSMutableString alloc] init];
	
	if ([@"Net1023K Rx" sizeWithAttributes:[appSettings alignRightAttributes]].width + 6 > [self frame].size.width) {
		[s appendFormat:@"N"];
	}
	else {
		[s appendFormat:@"Net"];
	}
    //[s appendFormat:@"Net - %@", [appSettings networkInterface]];
    tmpRect.origin.y = graphSize.height - textRectHeight;
    
    // draw the scale if there is room
    if (tmpRect.origin.y - textRectHeight > 0) {
        tmpRect.origin.y -= textRectHeight;
        tmpRect.size.height += textRectHeight;
        if (max >= 1048576)
            [s appendFormat:@"\n%3.2fM/s", ((CGFloat)max / 1048576.)];
        else if (max >= 1024)
            [s appendFormat:@"\n%4.1fK/s", ((CGFloat)max / 1024.)];
        else
            [s appendFormat:@"\n%ldB/s", (long)max];
    }
    
    // draw the total bandwidth used if there is room
    if ([appSettings showTotalBandwidthSinceBoot]) {
        if (tmpRect.origin.y - textRectHeight > 0) {
            tmpRect.origin.y -= textRectHeight;
            tmpRect.size.height += textRectHeight;
            UInt64 totalBytesSinceBoot = self.miner.totalBytesSinceBoot;
            if (totalBytesSinceBoot >= 1073741824)
                [s appendFormat:@"\n%3.2fG", ((CGFloat)totalBytesSinceBoot / 1073741824.)];
            else if (totalBytesSinceBoot >= 1048576)
                [s appendFormat:@"\n%3.2fM", ((CGFloat)totalBytesSinceBoot / 1048576.)];
            else if (totalBytesSinceBoot >= 1024)
                [s appendFormat:@"\n%4.1fK", ((CGFloat)totalBytesSinceBoot / 1024.)];
            else
                [s appendFormat:@"\n%quB", totalBytesSinceBoot];
        }
    }
    if ([appSettings showTotalBandwidthSinceLoad]) {
        if (tmpRect.origin.y - textRectHeight > 0) {
            tmpRect.origin.y -= textRectHeight;
            tmpRect.size.height += textRectHeight;
            UInt64 totalBytesSinceLoad = self.miner.totalBytesSinceLoad;
            if (totalBytesSinceLoad >= 1073741824)
                [s appendFormat:@"\n%3.2fG", ((CGFloat)totalBytesSinceLoad / 1073741824.)];
            else if (totalBytesSinceLoad >= 1048576)
                [s appendFormat:@"\n%3.2fM", ((CGFloat)totalBytesSinceLoad / 1048576.)];
            else if (totalBytesSinceLoad >= 1024)
                [s appendFormat:@"\n%4.1fK", ((CGFloat)totalBytesSinceLoad / 1024.)];
            else
                [s appendFormat:@"\n%quB", totalBytesSinceLoad];
        }
    }

    [s drawInRect:tmpRect withAttributes:[appSettings alignLeftAttributes]];
        
    if (netGraphMode == 0) {
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight * 2;
        [s setString:@""];
        
        rx = [self.miner currentRX];
		if (rx >= 104857600) 
			[s appendFormat:@"%3.1fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 1048576)
            [s appendFormat:@"%3.2fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 102400)
            [s appendFormat:@"%4.0fK Rx", ((CGFloat)rx / 1024.)];
        else if (rx >= 1024)
            [s appendFormat:@"%4.1fK Rx", ((CGFloat)rx / 1024.)];
        else
            [s appendFormat:@"%ldB Rx", (long)rx];
        
        
        tx = [self.miner currentTX];
		if (tx >= 104857600) 
			[s appendFormat:@"\n%3.1fM Tx", ((CGFloat)tx / 1048576.)];
        else if (tx >= 1048576)
            [s appendFormat:@"\n%3.2fM Tx", ((CGFloat)tx / 1048576.)];
        else if (rx >= 102400)
            [s appendFormat:@"\n%4.0fK Tx", ((CGFloat)tx / 1024.)];
        else if (tx >= 1024)
            [s appendFormat:@"\n%4.1fK Tx", ((CGFloat)tx / 1024.)];
        else
            [s appendFormat:@"\n%ldB Tx", (long)tx];
        
        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
    }
    else if (netGraphMode == 1) {
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight;
        [s setString:@""];
        rx = [self.miner currentRX];
		if (rx >= 104857600) 
			[s appendFormat:@"%3.1fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 1048576)
            [s appendFormat:@"%3.2fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 102400)
            [s appendFormat:@"%4.0fK Rx", ((CGFloat)rx / 1024.)];
        else if (rx >= 1024)
            [s appendFormat:@"%4.1fK Rx", ((CGFloat)rx / 1024.)];
        else
            [s appendFormat:@"%ldB Rx", (long)rx];
		
        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
        
        tmpRect.origin.y = graphSize.height - textRectHeight;
        [s setString:@""];
        tx = [self.miner currentTX];
		if (tx >= 104857600) 
			[s appendFormat:@"%3.1fM Tx", ((CGFloat)tx / 1048576.)];
        else if (tx >= 1048576)
            [s appendFormat:@"%3.2fM Tx", ((CGFloat)tx / 1048576.)];
        else if (tx >= 102400)
            [s appendFormat:@"%4.0fK Tx", ((CGFloat)tx / 1024.)];
        else if (tx >= 1024)
            [s appendFormat:@"%4.1fK Tx", ((CGFloat)tx / 1024.)];
        else
            [s appendFormat:@"%ldB Tx", (long)tx];
		
        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
    }
    else { // netGraphMode == 2
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight;
        [s setString:@""];
        tx = [self.miner currentTX];
		if (tx >= 104857600) 
			[s appendFormat:@"%3.1fM Tx", ((CGFloat)tx / 1048576.)];
        else if (tx >= 1048576)
            [s appendFormat:@"%3.2fM Tx", ((CGFloat)tx / 1048576.)];
        else if (tx >= 102400)
            [s appendFormat:@"%4.0fK Tx", ((CGFloat)tx / 1024.)];
        else if (tx >= 1024)
            [s appendFormat:@"%4.1fK Tx", ((CGFloat)tx / 1024.)];
        else
            [s appendFormat:@"%ldB Tx", (long)tx];
		
        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
        
        tmpRect.origin.y = graphSize.height - textRectHeight;
        [s setString:@""];
        rx = [self.miner currentRX];
		if (rx >= 104857600) 
			[s appendFormat:@"%3.1fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 1048576)
            [s appendFormat:@"%3.2fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 102400)
            [s appendFormat:@"%4.0fK Rx", ((CGFloat)rx / 1024.)];
        else if (rx >= 1024)
            [s appendFormat:@"%4.1fK Rx", ((CGFloat)rx / 1024.)];
        else
            [s appendFormat:@"%ldB Rx", (long)rx];
		
        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
    }


    [gc setShouldAntialias:YES];
}

- (void)drawMiniGraph:(NSRect)inRect {
    NSString *leftLabel = nil;
    if ([@"Net1023K Rx" sizeWithAttributes:[appSettings alignRightAttributes]].width + 6 > [self frame].size.width) {
        leftLabel = @"N";
    }
    else {
        leftLabel = @"Net";
    }

    NSInteger max = MAX([self.fastMiner maxBandwidth], [appSettings netMinGraphScale]);
    
    if ([appSettings netGraphMode] == 1) {      // Tx on top of Rx.
        [self drawMiniGraphWithValues:@[@(fastTXValue), @(fastRXValue)] upperBound:max lowerBound:0 leftLabel:leftLabel printValueBytes:self.miner.totalValues.currentValue printValueIsRate:YES];
    }
    else {                                      // Rx on top of Tx.
        [self drawMiniGraphWithValues:@[@(fastRXValue), @(fastTXValue)] upperBound:max lowerBound:0 leftLabel:leftLabel printValueBytes:self.miner.totalValues.currentValue printValueIsRate:YES];
    }
}

- (NSInteger)convertHeight:(NSInteger) yComponent {
    return (yComponent >= 0 ? yComponent : 0) * (graphSize.height - ([appSettings textRectHeight] * 2)) / 100;
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Network View"];
    NSMenuItem *tMI;

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Network Interface Traffic" action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    for (NSInteger i = 0; i < self.miner.numInterfaces; i++) {
        tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSString stringWithFormat:@"%s: RX(%1.1fM) TX(%1.1fM)", self.miner.interfaceStats[i].if_name, self.miner.interfaceStats[i].if_in.bytes / 1024. / 1024., self.miner.interfaceStats[i].if_out.bytes / 1024. / 1024.] action:@selector(emptyEvent:) keyEquivalent:@""];
        [myMenu addItem:tMI];
    }
    
    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open Network System Preferences..." action:@selector(openNetworkSystemPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open Network Utility..." action:@selector(openNetworkUtility:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open XRG Network Preferences..." action:@selector(openNetworkPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    return myMenu;
}

- (void)emptyEvent:(NSEvent *)theEvent {
}

- (void)openNetworkSystemPreferences:(NSEvent *)theEvent {
    [NSTask 
      launchedTaskWithLaunchPath:@"/usr/bin/open"
      arguments:@[@"/System/Library/PreferencePanes/Network.prefPane"]
    ];
}

- (void)openNetworkUtility:(NSEvent *)theEvent {
    [NSTask 
      launchedTaskWithLaunchPath:@"/usr/bin/open"
      arguments:@[@"/Applications/Utilities/Network Utility.app"]
    ];
}

- (void)openNetworkPreferences:(NSEvent *)theEvent {
    [[parentWindow controller] showPrefsWithPanel:@"Network"];
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

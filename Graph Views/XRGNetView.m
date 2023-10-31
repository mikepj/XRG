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
//  XRGNetView.m
//

#import "XRGGraphWindow.h"
#import "XRGNetView.h"
#import "XRGCommon.h"

@implementation XRGNetView

- (void)awakeFromNib {    
    [super awakeFromNib];
    
    graphSize = NSMakeSize(90, 112);
    
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
        [self drawGraphWithDataFromDataSet:self.miner.totalValues maxValue:max inRect:bounds flipped:(netGraphMode == 2) filled:YES color:[appSettings graphFG2Color]];
    }
    else {
        [self drawGraphWithDataFromDataSet:self.miner.rxValues maxValue:max inRect:bounds flipped:(netGraphMode == 2) filled:YES color:[appSettings graphFG2Color]];
    }

    /* sent data */
    [self drawGraphWithDataFromDataSet:self.miner.txValues maxValue:max inRect:bounds flipped:(netGraphMode == 1) filled:YES color:[appSettings graphFG1Color]];

    [gc setShouldAntialias:YES];

    // draw the text
    NSMutableString *leftText = [[NSMutableString alloc] init];
    NSMutableString *rightText = [[NSMutableString alloc] init];
	
	if ([@"Net1023K Rx" sizeWithAttributes:[appSettings alignRightAttributes]].width + 6 > [self frame].size.width) {
		[leftText appendFormat:@"N"];
	}
	else {
		[leftText appendFormat:@"Net"];
	}

    tmpRect.origin.y = graphSize.height - textRectHeight;
    
    // draw the scale if there is room
    if (tmpRect.origin.y - textRectHeight > 0) {
        tmpRect.origin.y -= textRectHeight;
        tmpRect.size.height += textRectHeight;
        [leftText appendFormat:@"\n%@/s", [XRGCommon formattedStringForBytes:max]];
    }
    
    // draw the total bandwidth used if there is room
    if ([appSettings showTotalBandwidthSinceBoot]) {
        if (tmpRect.origin.y - textRectHeight > 0) {
            tmpRect.origin.y -= textRectHeight;
            tmpRect.size.height += textRectHeight;
            UInt64 totalBytesSinceBoot = self.miner.totalBytesSinceBoot;
            [leftText appendFormat:@"\n%@", [XRGCommon formattedStringForBytes:totalBytesSinceBoot]];
        }
    }
    if ([appSettings showTotalBandwidthSinceLoad]) {
        if (tmpRect.origin.y - textRectHeight > 0) {
            tmpRect.origin.y -= textRectHeight;
            tmpRect.size.height += textRectHeight;
            UInt64 totalBytesSinceLoad = self.miner.totalBytesSinceLoad;
            [leftText appendFormat:@"\n%@", [XRGCommon formattedStringForBytes:totalBytesSinceLoad]];
        }
    }

    // Right text is drawn below and can have multiple strings.
    [self drawLeftText:leftText centerText:nil rightText:nil inRect:[self paddedTextRect]];

    if (netGraphMode == 0) {
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight * 2;
        
        rx = [self.miner currentRX];
        [rightText appendFormat:@"%@ Rx", [XRGCommon formattedStringForBytes:rx]];
        
        tx = [self.miner currentTX];
        [rightText appendFormat:@"\n%@ Tx", [XRGCommon formattedStringForBytes:tx]];
        
        [rightText drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
    }
    else if (netGraphMode == 1) {
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight;

        rx = [self.miner currentRX];
        [rightText appendFormat:@"%@ Rx", [XRGCommon formattedStringForBytes:rx]];
		
        [rightText drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
        
        tmpRect.origin.y = graphSize.height - textRectHeight;
        [rightText setString:@""];
        tx = [self.miner currentTX];
        [rightText appendFormat:@"%@ Tx", [XRGCommon formattedStringForBytes:tx]];
		
        [rightText drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
    }
    else { // netGraphMode == 2
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight;
        tx = [self.miner currentTX];
        [rightText appendFormat:@"%@ Tx", [XRGCommon formattedStringForBytes:tx]];
		
        [rightText drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
        
        tmpRect.origin.y = graphSize.height - textRectHeight;
        [rightText setString:@""];
        rx = [self.miner currentRX];
        [rightText appendFormat:@"%@ Rx", [XRGCommon formattedStringForBytes:rx]];
		
        [rightText drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
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
    NSMenu *myMenu = [[NSMenu alloc] initWithTitle:@"Network View"];
    NSMenuItem *tMI;

    tMI = [[NSMenuItem alloc] initWithTitle:@"Network Interface Traffic" action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    for (NSInteger i = 0; i < self.miner.numInterfaces; i++) {
        tMI = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%s: RX(%1.1fM) TX(%1.1fM)", self.miner.interfaceStats[i].if_name, self.miner.interfaceStats[i].if_in.bytes / 1024. / 1024., self.miner.interfaceStats[i].if_out.bytes / 1024. / 1024.] action:@selector(emptyEvent:) keyEquivalent:@""];
        [myMenu addItem:tMI];
    }
    
    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem alloc] initWithTitle:@"Reset Graph" action:@selector(clearData:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem alloc] initWithTitle:@"Open Network System Preferences..." action:@selector(openNetworkSystemPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    tMI = [[NSMenuItem alloc] initWithTitle:@"Open Network Utility..." action:@selector(openNetworkUtility:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    tMI = [[NSMenuItem alloc] initWithTitle:@"Open XRG Network Preferences..." action:@selector(openNetworkPreferences:) keyEquivalent:@""];
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
      arguments:@[@"-a", @"Network Utility.app"]
    ];
}

- (void)openNetworkPreferences:(NSEvent *)theEvent {
    [[parentWindow controller] showPrefsWithPanel:@"Network"];
}

- (void)clearData:(NSEvent *)theEvent {
    [self.miner reset];
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

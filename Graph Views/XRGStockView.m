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
//  XRGStockView.m
//

#import "XRGStockView.h"
#import "XRGGraphWindow.h"

@implementation XRGStockView

- (void)awakeFromNib {
    parentWindow = (XRGGraphWindow *)[self window];
    [parentWindow setStockView:self];
    [parentWindow initTimers];
    appSettings = [parentWindow appSettings];
    moduleManager = [parentWindow moduleManager];

    stockToShow = 0;
    switchIncrementer = 0;
    switchTime = 15;
    
    slowIncrementer = 0;
    slowTime = 4;

    stockObjects = [NSMutableArray arrayWithCapacity:5];
    stockSymbols = [NSMutableArray arrayWithCapacity:5];
    [self setStockSymbolsFromString:[appSettings stockSymbols]];
    
    djia = [[XRGStock alloc] init];
   
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];    
    m = [[XRGModule alloc] initWithName:@"Stock" andReference:self];
	m.doesFastUpdate = NO;
	m.doesGraphUpdate = YES;
	m.doesMin5Update = NO;
	m.doesMin30Update = YES;
	m.displayOrder = 8;
    [self updateMinSize];
    m.isDisplayed = [defs boolForKey:XRG_showStockGraph];

    [[parentWindow moduleManager] addModule:m];
    [self setGraphSize:[m currentSize]];
    
    // show the first set of data if the module is displayed
    if ([m isDisplayed]) [self min30Update:nil];
	
	[NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(ticker) userInfo:nil repeats:YES];
}

- (void)setStockSymbolsFromString:(NSString *)s {
    NSString *uppercaseS = [s uppercaseString];
    NSMutableString *tmpString = [NSMutableString stringWithCapacity: 10];
    NSUInteger stringLength = [uppercaseS lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    char *cString = (char *)[uppercaseS cStringUsingEncoding:NSUTF8StringEncoding];

    [stockSymbols removeAllObjects];
    
    for (NSInteger i = 0; i < stringLength; i++) {
        if (cString[i] == ' ' || cString[i] == '\t' || cString[i] == '\n') {
            continue;
        }
        else if (cString[i] == ',') {
            if ([tmpString length] > 0) {
                // add the current string to the list
                [stockSymbols addObject:[tmpString copy]];
                
                // reset the temp string
                [tmpString setString:@""];
            }
        }
        else {
            [tmpString appendFormat:@"%c", cString[i]];
        }
    }
    // add the last stock
    if ([tmpString length] > 0) {
        // add the current string to the list
        [stockSymbols addObject:[tmpString copy]];
        
        // reset the temp string
        [tmpString setString:@""];
    }

    [self resetStockObjects];
    if ([[[parentWindow moduleManager] getModuleByReference:self] isDisplayed]) 
        [self reloadStockData];
}

- (void)resetStockObjects {
    if (![[[parentWindow moduleManager] getModuleByReference:self] isDisplayed]) return;
    
    [stockObjects removeAllObjects];
    for (NSString *symbol in stockSymbols) {
        XRGStock *tmpStock = [[XRGStock alloc] init];
        [tmpStock setSymbol:symbol];
        [stockObjects addObject:tmpStock];
    }
    
    [djia resetData];
    [djia setSymbol:@"%5EDJI"];

    self.gettingData = NO;
}

- (void)reloadStockData {
    if (![[[parentWindow moduleManager] getModuleByReference:self] isDisplayed]) return;

	[stockObjects makeObjectsPerformSelector:@selector(resetData)];
	[stockObjects makeObjectsPerformSelector:@selector(loadData)];
    
    [djia resetData];
    [djia setSymbol:@"%5EDJI"];
    
    self.gettingData = YES;
}

- (bool)dataIsReady {
    if (!self.gettingData) return YES;
    
    for (XRGStock *tmpStock in stockObjects) {
        if ([tmpStock gettingData]) {
            return NO;
        }
    }
    
    if ([djia gettingData]) {
        return NO;
    }
    
    self.gettingData = NO;
    return YES;
}

- (void)updateMinSize {
    CGFloat width = [@"WWWW: $999.99" sizeWithAttributes:[appSettings alignRightAttributes]].width + 6;
    
    [m setMinWidth: width];
    [m setMinHeight: XRG_MINI_HEIGHT];
}

- (void)ticker {
	switchIncrementer++;
	if ((self.gettingData == YES) || (switchIncrementer >= switchTime)) {
        switchIncrementer = 0;
        if ([stockObjects count]) stockToShow = (stockToShow + 1) % [stockObjects count];
        [self dataIsReady];
        [self setNeedsDisplay:YES];
	}
}

- (void)graphUpdate:(NSTimer *)aTimer {
}

- (void)min30Update:(NSTimer *)aTimer {
    if (slowIncrementer == 0) {
        [self resetStockObjects];
        [self reloadStockData];
		
		self.gettingData = YES;
    }
    slowIncrementer = (slowIncrementer + 1) % slowTime;
}

- (void)drawRect:(NSRect)rect {
    if ([self isHidden]) return;

    #ifdef XRG_DEBUG
        NSLog(@"In Stock DrawRect."); 
    #endif
    
    NSGraphicsContext *gc = [NSGraphicsContext currentContext];
    
    // first draw the background
    [[appSettings graphBGColor] set];
    NSRect bounds = [self bounds];
    CGContextFillRect(gc.CGContext, bounds);

    if ([self shouldDrawMiniGraph]) {
        [self drawMiniGraph];
    }
    else {
        [self drawGraph];
    }
}

- (void)drawMiniGraph {
    NSGraphicsContext *gc = [NSGraphicsContext currentContext];
    [gc setShouldAntialias:[appSettings antiAliasing]];
    
    // first draw the background
    [[appSettings graphBGColor] set];
    NSRect bounds = [self bounds];
    CGContextFillRect(gc.CGContext, bounds);

    if ([stockObjects count]) {
        XRGStock *showStock = stockObjects[stockToShow];
        
        if (self.gettingData) {  // we are getting data, display a status and return
            [@"Fetching Data" drawInRect:[self paddedTextRect] withAttributes:[appSettings alignLeftAttributes]];
        }
        else if ([showStock haveGoodDisplayData]) {
            // draw the graph
            NSArray *a = nil;
            if ([appSettings stockGraphTimeFrame] == 0)
                a = [showStock get1MonthValues];
            else if ([appSettings stockGraphTimeFrame] == 1)
                a = [showStock get3MonthValues];
            else if ([appSettings stockGraphTimeFrame] == 2)
                a = [showStock get6MonthValues];
            else if ([appSettings stockGraphTimeFrame] == 3)
                a = [showStock get12MonthValues];
            
            if ([a count] > 0) {
                // find the high, low and range of the graph
                CGFloat high, low;
                low = high = [a[0] floatValue];
                for (NSInteger i = 1; i < [a count]; i++) {
                    low = MIN(low, [a[i] floatValue]);
                    high = MAX(high, [a[i] floatValue]);
                }
                
                [self drawMiniGraphWithValues:@[@([showStock currentPrice])] upperBound:high lowerBound:low leftLabel:[showStock symbol] rightLabel:[showStock priceString]];
            }
            else {
                [self drawLeftText:@"Stocks n/a" centerText:nil rightText:nil inRect:[self paddedTextRect]];
            }
        }
        else {
            [self drawLeftText:@"Stocks n/a" centerText:nil rightText:nil inRect:[self paddedTextRect]];
        }
    }
    else {  // there are no stock objects
        [self drawLeftText:@"No Stocks" centerText:nil rightText:nil inRect:[self paddedTextRect]];
    }
}

- (void)drawGraph {
    NSGraphicsContext *gc = [NSGraphicsContext currentContext];

    NSInteger textRectHeight = [appSettings textRectHeight];
    NSRect tmpRect = NSMakeRect(2, 
                                self.graphSize.height - textRectHeight,
                                self.graphSize.width - 4,
                                textRectHeight);
    NSMutableString *s = [NSMutableString stringWithString:@""];
    int i;
    float r;

    [gc setShouldAntialias:[appSettings antiAliasing]];

    if ([stockObjects count]) {
        if (self.gettingData) {  // we are getting data, display a status and return
            [s setString:@"Fetching Data"];

            [s drawInRect:tmpRect withAttributes:[appSettings alignLeftAttributes]];
            return;
        }
    
        [[appSettings graphFG1Color] set];
        if ([stockObjects[stockToShow] haveGoodDisplayData]) {
            // draw the graph
            NSArray *a = nil;
            if ([appSettings stockGraphTimeFrame] == 0)
                a = [stockObjects[stockToShow] get1MonthValues];
            else if ([appSettings stockGraphTimeFrame] == 1)
                a = [stockObjects[stockToShow] get3MonthValues];
            else if ([appSettings stockGraphTimeFrame] == 2)
                a = [stockObjects[stockToShow] get6MonthValues];
            else if ([appSettings stockGraphTimeFrame] == 3)
                a = [stockObjects[stockToShow] get12MonthValues];
            
            if ([a count] > 0) {
                // find the high, low and range of the graph
                int i;
                float high, low;
                low = high = [a[0] floatValue];
                for (i = 1; i < [a count]; i++) {
                    if ([a[i] floatValue] > high) 
                        high = [a[i] floatValue];
                    if ([a[i] floatValue] < low)
                        low = [a[i] floatValue];
                }
                                
                r = (high - low) * .1;
                high += r;
                low -= r;
                
                NSInteger count = [a count];
                CGFloat *data = alloca(count * sizeof(CGFloat));
                
                for (i = 0; i < count; i++) data[i] = [a[i] floatValue];
                
                [self drawRangedGraphWithData:data size:[a count] currentIndex:(count - 1) upperBound:high lowerBound:low inRect:[self bounds] flipped:NO filled:YES color:[appSettings graphFG1Color]];
            }
        }
        
        // draw the secondary graph
        if ([appSettings showDJIA] != 0) {
            if ([djia haveGoodDisplayData]) {
                NSArray *a = nil;
                if ([appSettings stockGraphTimeFrame] == 0)
                    a = [djia get1MonthValues];
                else if ([appSettings stockGraphTimeFrame] == 1)
                    a = [djia get3MonthValues];
                else if ([appSettings stockGraphTimeFrame] == 2)
                    a = [djia get6MonthValues];
                else if ([appSettings stockGraphTimeFrame] == 3)
                    a = [djia get12MonthValues];
                    
                if ([a count] > 0) {
                    float high, low;
                    low = high = [a[0] floatValue];
                    for (NSNumber *closingPrice in a) {
                        high = MAX(high, [closingPrice floatValue]);
                        low = MIN(low, [closingPrice floatValue]);
                    }
                    
                    r = (high - low) * .1;
                    high += r;
                    low -= r;
    
                    NSInteger count = [a count];
                    CGFloat *data = alloca(count * sizeof(CGFloat));
                    
                    for (i = 0; i < count; i++) data[i] = [a[i] floatValue];
                    
                    [self drawRangedGraphWithData:data size:[a count] currentIndex:(count - 1) upperBound:high lowerBound:low inRect:[self bounds] flipped:NO filled:NO color:[appSettings graphFG2Color]];
                }
            }
        }

        [gc setShouldAntialias:YES];

        
        // now draw some text for each of the stocks.
        [gc setShouldAntialias:[appSettings antialiasText]];

        NSInteger heightOfEachStock = MAX(1, [appSettings stockShowChange] ? textRectHeight * 2 : textRectHeight);
        NSUInteger maxToShow = tmpRect.origin.y / heightOfEachStock;
        if ([stockObjects count] <= maxToShow) {
            maxToShow = [stockObjects count];
        }
        else {
            // don't show the last one if there isn't enough space for the down arrow.
			if ((tmpRect.origin.y - (maxToShow * heightOfEachStock) < textRectHeight) && (maxToShow > 0)) {
                maxToShow--;
			}
        }
            
        NSInteger currentIndex = stockToShow;
        for (i = 0; i < maxToShow; i++) {
            if (currentIndex == stockToShow && [stockObjects count] != 1) {
                [appSettings alignRightAttributes][NSForegroundColorAttributeName] = [appSettings graphFG3Color];
                [appSettings alignLeftAttributes][NSForegroundColorAttributeName] = [appSettings graphFG3Color];
            }

            [s setString:[stockObjects[currentIndex] label]];
            [s drawInRect:tmpRect withAttributes:[appSettings alignLeftAttributes]];
            
            NSArray *a = [stockObjects[currentIndex] getCurrentPriceAndChange];
            if (a != nil) {
                NSString *priceString = [stockObjects[currentIndex] priceString];
                [priceString drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
                tmpRect.origin.y -= textRectHeight;
                
                if ([a[0] intValue] == 0) {
                    // reset the text color
                    if (currentIndex == stockToShow) {
                        [appSettings alignRightAttributes][NSForegroundColorAttributeName] = [appSettings textColor];
                        [appSettings alignLeftAttributes][NSForegroundColorAttributeName] = [appSettings textColor];
                    }
                    continue;   // skip the last change
                }
                
                if ([appSettings stockShowChange]) {
                    NSString *changeString = [stockObjects[currentIndex] changeString];

                    [changeString drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
                    tmpRect.origin.y -= textRectHeight;
                }
            }
            else {  // there isn't good pricing info for this stock
                [s setString:@"n/a"];

                [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
                tmpRect.origin.y -= textRectHeight;
            }
            
            if (currentIndex == stockToShow && [stockObjects count] != 1) {
                [appSettings alignRightAttributes][NSForegroundColorAttributeName] = [appSettings textColor];
                [appSettings alignLeftAttributes][NSForegroundColorAttributeName] = [appSettings textColor];
            }
            
            // increment currentIndex;
            if (currentIndex == [stockObjects count] - 1)
                currentIndex = 0;
            else 
                currentIndex++;
        }
        
        // now draw the time frame that we are using at the bottom
        if ([appSettings stockGraphTimeFrame] == 0)
            [s setString:@"1m"];
        else if ([appSettings stockGraphTimeFrame] == 1)
            [s setString:@"3m"];
        else if ([appSettings stockGraphTimeFrame] == 2)
            [s setString:@"6m"];
        else if ([appSettings stockGraphTimeFrame] == 3)
            [s setString:@"1y"];
        
        tmpRect.origin.y = 0;

        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
        
        if ([appSettings showDJIA]) {
            NSArray *a = [djia getCurrentPriceAndChange];
            if (a != nil) {
                if ([a[0] intValue] == 0) {
                    [s setString:@"n/a"];
                }
                else {
                    [s setString:@""];
                    [s appendFormat:@"$%2.2f", [a[0] floatValue]];
                }

                [s drawInRect:tmpRect withAttributes:[appSettings alignLeftAttributes]];
            }
        }

    }
    else {  // there are no stock objects
        [s setString:@"No Stocks"];
        [s drawInRect:tmpRect withAttributes:[appSettings alignLeftAttributes]];
        
        tmpRect.origin.y -= textRectHeight;
        [s setString:@"Found"];
        [s drawInRect:tmpRect withAttributes:[appSettings alignLeftAttributes]];
    }
        
    [gc setShouldAntialias:YES];
}

- (int)convertHeight:(int) yComponent {
    return (yComponent >= 0 ? yComponent : 0) * (self.graphSize.height) / 100;
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Stock View"];
    NSMenuItem *tMI;

    int i;
    for (i = 0; i < [stockObjects count]; i++) {
        tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSString stringWithFormat:@"View Detailed Status for %@", [stockObjects[i] symbol]] action:@selector(openStock:) keyEquivalent:@""];
        [tMI setTag:i];
        [myMenu addItem:tMI];
    }
    
    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"View Detailed Status for DJIA" action:@selector(openDJIA:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    [myMenu addItem:[NSMenuItem separatorItem]];

	tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Update Stock Graph Now" action:@selector(updateNow:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    [myMenu addItem:[NSMenuItem separatorItem]];
	
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open XRG Stock Preferences..." action:@selector(openStockPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    return myMenu;
}

- (void)emptyEvent:(NSEvent *)theEvent {
}

- (void)openStock:(id)sender {
	if (![sender isKindOfClass:[NSMenuItem class]]) return;
	
    NSInteger i = [(NSMenuItem *)sender tag];
    
    [NSTask 
        launchedTaskWithLaunchPath:@"/usr/bin/open"
        arguments:@[[NSMutableString stringWithFormat:@"http://www.google.com/finance?q=%@", [stockObjects[i] symbol]]]
    ];
}

- (void)openDJIA:(NSEvent *)theEvent {
    [NSTask 
        launchedTaskWithLaunchPath:@"/usr/bin/open"
        arguments:@[@"http://www.google.com/finance?q=%5EDJI"]
    ];
}

- (void)updateNow:(NSEvent *)theEvent {
	slowIncrementer = 0;
	[self min30Update:nil];
}

- (void)openStockPreferences:(NSEvent *)theEvent {
    [[parentWindow controller] showPrefsWithPanel:@"Stocks"];
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

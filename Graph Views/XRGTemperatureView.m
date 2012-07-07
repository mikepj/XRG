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
//  XRGTemperatureView.m
//

#import "XRGGraphWindow.h"
#import "XRGTemperatureView.h"

@implementation XRGTemperatureView

- (id)initWithFrame:(NSRect)frameRect {
    [super initWithFrame:frameRect];
 
    return self;
}

- (void)awakeFromNib {       
    parentWindow = (XRGGraphWindow *)[self window];
    [parentWindow setTemperatureView:self];
    [parentWindow initTimers];
    
    appSettings = [[parentWindow appSettings] retain];
    moduleManager = [[parentWindow moduleManager] retain];
	
	locationSizeCache = [[[NSMutableDictionary alloc] initWithCapacity:20] retain];
    
    TemperatureMiner = [[XRGTemperatureMiner alloc] init];
    [parentWindow setTemperatureMiner:TemperatureMiner];
	[TemperatureMiner setDisplayFans:YES];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];    
    m = [[[XRGModule alloc] initWithName:@"Temperature" andReference:self] retain];
    [m setDoesFastUpdate:NO];
    [m setDoesGraphUpdate:YES];
    [m setDoesMin5Update:NO];
    [m setDoesMin30Update:NO];
    [m setDisplayOrder:3];
    [m setAlwaysDoesGraphUpdate:NO];
    [self updateMinSize];
    [m setIsDisplayed: (bool)[defs boolForKey:XRG_showTemperatureGraph]];

    [[parentWindow moduleManager] addModule:m];
    [self setGraphSize:[m currentSize]];
}

- (void)setGraphSize:(NSSize)newSize {
    NSSize tmpSize;
    tmpSize.width = newSize.width;
    tmpSize.height = newSize.height;
    if (tmpSize.width < 1) tmpSize.width = 1;
    if (tmpSize.width > 2000) tmpSize.width = 2000;
    [self setWidth: tmpSize.width];
    graphSize = tmpSize;
}

- (void)setWidth:(int)newWidth {
    int newNumSamples = newWidth;

    if (newNumSamples < 0) return;

    [TemperatureMiner setDataSize:newNumSamples];

    numSamples = newNumSamples;
}

- (void)updateMinSize {
    float width, height;
    height = [appSettings textRectHeight];
    
    width = [[NSString stringWithFormat:@"CPU 199%CF", 0x00B0] sizeWithAttributes:[appSettings alignRightAttributes]].width;
    temperatureWidth = [[NSString stringWithFormat:@"199%CF", 0x00B0] sizeWithAttributes:[appSettings alignRightAttributes]].width;
	rpmWidth = [@"9999 rpm" sizeWithAttributes:[appSettings alignRightAttributes]].width;
	
	[locationSizeCache removeAllObjects];
    
    [m setMinWidth: width];
    [m setMinHeight: height];
}

- (void)graphUpdate:(NSTimer *)aTimer {
    [TemperatureMiner setCurrentTemperatures];
    
    [self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)inRect {
    if ([self isHidden]) {
        return;
    }
    
    #ifdef XRG_DEBUG
        NSLog(@"In Temperature DrawRect."); 
    #endif

    NSGraphicsContext *gc = [NSGraphicsContext currentContext]; 

    int i;
    float textRectHeight = [appSettings textRectHeight];

    NSRect textRect = NSMakeRect(3, inRect.size.height, inRect.size.width - 6, 0);

    [gc setShouldAntialias:[appSettings antiAliasing]];

    [[appSettings graphBGColor] set];
    NSRectFill(inRect);
        
    NSArray *locations = [TemperatureMiner locationKeysInOrder];
    
    if ([locations count] == 0) {
        // This machine isn't supported.
        if ([@"No Sensors Found" sizeWithAttributes:[appSettings alignRightAttributes]].width < textRect.size.width) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            [@"No Sensors Found" drawInRect:textRect withAttributes:[appSettings alignLeftAttributes]];
        }
        else {
            textRect.origin.y -= textRectHeight * 2;
            textRect.size.height += textRectHeight * 2;
            [@"No Sensors\nFound" drawInRect:textRect withAttributes:[appSettings alignLeftAttributes]];            
        }
    }
    
    XRGDataSet *dataSet1 = nil;
    XRGDataSet *dataSet2 = nil;
    XRGDataSet *dataSet3 = nil;
    float maxValue = 0;
	float minValue = 9999999.f;
    
    if ([appSettings tempFG1Location] > 0 && [appSettings tempFG1Location] <= [locations count]) {
        dataSet1 = [TemperatureMiner dataSetForKey:[locations objectAtIndex:[appSettings tempFG1Location] - 1]];
        if ([dataSet1 max] > maxValue) maxValue = [dataSet1 max];
		if ([dataSet1 min] < minValue) minValue = [dataSet1 min];
    }

    if ([appSettings tempFG2Location] > 0 && [appSettings tempFG2Location] <= [locations count]) {
        dataSet2 = [TemperatureMiner dataSetForKey:[locations objectAtIndex:[appSettings tempFG2Location] - 1]];
        if ([dataSet2 max] > maxValue) maxValue = [dataSet2 max];
		if ([dataSet2 min] < minValue) minValue = [dataSet2 min];
    }

    if ([appSettings tempFG3Location] > 0 && [appSettings tempFG3Location] <= [locations count]) {
        dataSet3 = [TemperatureMiner dataSetForKey:[locations objectAtIndex:[appSettings tempFG3Location] - 1]];
        if ([dataSet3 max] > maxValue) maxValue = [dataSet3 max];
 		if ([dataSet3 min] < minValue) minValue = [dataSet3 min];
    }
    
	// Scale the max and min values a bit.
	float range = maxValue - minValue;
	if (range < 20) range = 20;
	maxValue += 0.1 * range;
	minValue -= 0.1 * range;
	
    if (dataSet1) {
		[self drawRangedGraphWithDataFromDataSet:dataSet1 upperBound:maxValue lowerBound:minValue inRect:inRect flipped:NO filled:NO color:[appSettings graphFG1Color]];
    }
    
    if (dataSet2) {
		[self drawRangedGraphWithDataFromDataSet:dataSet2 upperBound:maxValue lowerBound:minValue inRect:inRect flipped:NO filled:NO color:[appSettings graphFG2Color]];
    }
    
    if (dataSet3) {
		[self drawRangedGraphWithDataFromDataSet:dataSet3 upperBound:maxValue lowerBound:minValue inRect:inRect flipped:NO filled:NO color:[appSettings graphFG3Color]];
    }

    [gc setShouldAntialias:YES];
            
            
    // draw the text
    [gc setShouldAntialias:[appSettings antialiasText]];

    NSMutableString *s = [NSMutableString stringWithCapacity:50];
    NSMutableString *t = [NSMutableString stringWithCapacity:50];
			
	bool firstLine = YES;
    for (i = 0; i < [locations count]; i++) {
        NSString *label = [TemperatureMiner labelForKey:[locations objectAtIndex:i]];
		if (label == nil) {
			continue;
		}

        float locationTemperature = [TemperatureMiner currentValueForKey:[locations objectAtIndex:i]];		
        NSString *units = [TemperatureMiner unitsForLocation:[locations objectAtIndex:i]];
		if (units == nil) {
			units = @"";
		}
		
		if (locationTemperature < 0.001) continue;

        if (textRect.origin.y - textRectHeight > 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
        }
        else {
            break;
        }
        
        if (firstLine) {
			firstLine = NO;
		}
		else {
            [s appendString:@"\n"];
            [t appendString:@"\n"];
        }
        
		[s appendString:label];
        
        // Now add the temperature
        if ([appSettings tempUnits] == 0 && [units isEqualToString:[NSString stringWithFormat:@"%CC", 0x00B0]]) {
			units = [NSString stringWithFormat:@"%CF", 0x00B0];
			locationTemperature = locationTemperature * 1.8 + 32.;
        }
		
		if ([units isEqualToString:@" rpm"] | [units isEqualToString:@"%"]) {
			[t appendFormat:@"%3.0f%@", locationTemperature, units];
		}
		else {
			[t appendFormat:@"%3.1f%@", locationTemperature, units];
		}
    }
    
    [t drawInRect:textRect withAttributes:[appSettings alignRightAttributes]];
    
	NSRect leftRect = NSMakeRect(textRect.origin.x, 
								 textRect.origin.y, 
								 textRect.size.width - [t sizeWithAttributes:[appSettings alignRightAttributes]].width, 
								 textRect.size.height);
    [s drawInRect:leftRect withAttributes:[appSettings alignLeftAttributes]];
        
    [gc setShouldAntialias:YES];
}

//- (int) getWidthForLabel:(NSString *)label {
//	if ([locationSizeCache objectForKey:label] == nil) {
//		NSMutableAttributedString *tmpAttrString = [[[NSMutableAttributedString alloc] initWithString:label attributes:[appSettings alignLeftAttributes]] autorelease];
//		[locationSizeCache setObject:[NSNumber numberWithInt:[tmpAttrString size].width + 12] forKey:label];
//	}
//	
//	return [[locationSizeCache objectForKey:label] intValue];
//}

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

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Temperature View"] autorelease];
    NSMenuItem *tMI;

    NSArray *locations = [TemperatureMiner locationKeysInOrder];
    int i;    
    for (i = 0; i < [locations count]; i++) {
        NSMutableString *s = [NSMutableString stringWithFormat:@"%@: ", [TemperatureMiner labelForKey:[locations objectAtIndex:i]]];
        NSString *units = [TemperatureMiner unitsForLocation:[locations objectAtIndex:i]];
		float locationTemperature = [TemperatureMiner currentValueForKey:[locations objectAtIndex:i]];
        if (locationTemperature < 0.001) {
			continue;
		}
		
        // Now add the temperature
        if ([appSettings tempUnits] == 0 && [units isEqualToString:[NSString stringWithFormat:@"%CC", 0x00B0]]) {
			units = [NSString stringWithFormat:@"%CF", 0x00B0];
			locationTemperature = locationTemperature * 1.8 + 32.;
			[s appendFormat:@"%3.1f%@", locationTemperature, units];
		}
		else {
			[s appendFormat:@"%3.0f%@", locationTemperature, units];
		}

        tMI = [[[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:s
																	action:@selector(emptyEvent:) 
															 keyEquivalent:@""] autorelease];

        [myMenu addItem:tMI];
    }
        
    [myMenu addItem:[NSMenuItem separatorItem]];

    tMI = [[[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open XRG Temperature Preferences..." action:@selector(openTemperaturePreferences:) keyEquivalent:@""] autorelease];
    [myMenu addItem:tMI];
    
    return myMenu;
}

- (void)emptyEvent:(NSEvent *)theEvent {
}

- (void)openTemperaturePreferences:(NSEvent *)theEvent {
    [[parentWindow controller] showPrefsWithPanel:@"Temperature"];
}

- (BOOL) acceptsFirstMouse {
    return YES;
}

@end

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
//  XRGTemperatureView.m
//

#import "XRGGraphWindow.h"
#import "XRGTemperatureView.h"

@implementation XRGTemperatureView

- (void)awakeFromNib {       
    parentWindow = (XRGGraphWindow *)[self window];
    [parentWindow setTemperatureView:self];
    [parentWindow initTimers];
    
    appSettings = [parentWindow appSettings];
    moduleManager = [parentWindow moduleManager];
	
	locationSizeCache = [[NSMutableDictionary alloc] initWithCapacity:20];
    
    TemperatureMiner = [[XRGTemperatureMiner alloc] init];
    [parentWindow setTemperatureMiner:TemperatureMiner];
	[TemperatureMiner setDisplayFans:YES];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];    
    m = [[XRGModule alloc] initWithName:@"Temperature" andReference:self];
	m.doesFastUpdate = NO;
	m.doesGraphUpdate = YES;
	m.doesMin5Update = NO;
	m.doesMin30Update = NO;
	m.displayOrder = 4;
    m.alwaysDoesGraphUpdate = NO;
    [self updateMinSize];
    m.isDisplayed = [defs boolForKey:XRG_showTemperatureGraph];

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
    
    width = [[NSString stringWithFormat:@"CPU 199%CF", (unsigned short)0x00B0] sizeWithAttributes:[appSettings alignRightAttributes]].width;
    temperatureWidth = [[NSString stringWithFormat:@"199%CF", (unsigned short)0x00B0] sizeWithAttributes:[appSettings alignRightAttributes]].width;
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
    // Get our sensor locations.
    NSArray *locations = [TemperatureMiner locationKeysInOrder];
    if ([locations count] == 0) {
        [@"Temperature n/a" drawInRect:[self paddedTextRect] withAttributes:[appSettings alignLeftAttributes]];
        return;
    }
    
    // Get our main sensor index.
    NSInteger primaryIndex = [appSettings tempFG1Location] - 1;
    if (primaryIndex < 0 || primaryIndex >= [locations count]) {
        primaryIndex = 0;
    }
    
    // Get the label for this sensor.
    NSString *primaryLabel = [TemperatureMiner labelForKey:locations[primaryIndex]];
    if (!primaryLabel) {
        [@"Temperature n/a" drawInRect:[self paddedTextRect] withAttributes:[appSettings alignLeftAttributes]];
        return;
    }

    // Get the temperature value.
    float primaryValue = [TemperatureMiner currentValueForKey:locations[primaryIndex]];
    float adaptedValue = primaryValue;
    
    // Get the units.
    NSString *units = [TemperatureMiner unitsForLocation:locations[primaryIndex]];
    if (units == nil) {
        units = @"";
    }

    // Now create the value string
    NSString *valueString = nil;
    if ([appSettings tempUnits] == 0 && [units isEqualToString:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0]]) {
        units = [NSString stringWithFormat:@"%CF", (unsigned short)0x00B0];
        adaptedValue = primaryValue * 1.8 + 32.;
    }
    
    if ([units isEqualToString:@" rpm"] | [units isEqualToString:@"%"]) {
        valueString = [NSString stringWithFormat:@"%3.0f%@", adaptedValue, units];
    }
    else {
        valueString = [NSString stringWithFormat:@"%3.1f%@", adaptedValue, units];
    }
    
    // Create an array with the selected temperature value and fan values to plot.
    NSMutableArray *plotValues = [NSMutableArray array];
    XRGDataSet *dataSet = [TemperatureMiner dataSetForKey:locations[primaryIndex]];
    if (dataSet && dataSet.max > 0) {
        // Scale the primary value.
        float plotValue = (primaryValue - MIN(dataSet.min, 20)) / MAX(dataSet.max, 90) * 100;           // Use 90°C as max, or dataset.max, and 20°C as min
        [plotValues addObject:@(plotValue)];
    }
    
    // Add the fans
    NSArray *fans = [TemperatureMiner fanValues];
    for (XRGFan *fan in fans) {
        if ([fan.name isEqualToString:primaryLabel]) continue;  // Already showing this one.
        
        if (fan.maximumSpeed > 0) {
            [plotValues addObject:@((CGFloat)fan.actualSpeed / (CGFloat)fan.maximumSpeed * 100)];
        }
    }
    
    // Draw the mini graph.
    [self drawMiniGraphWithValues:plotValues upperBound:100 lowerBound:0 leftLabel:primaryLabel rightLabel:valueString];
    
    // Draw the text.
    [self drawLeftText:primaryLabel centerText:nil rightText:valueString inRect:[self paddedTextRect]];
}

- (void)drawGraph {
    NSGraphicsContext *gc = [NSGraphicsContext currentContext];

    int i;
    float textRectHeight = [appSettings textRectHeight];

    NSRect textRect = [self paddedTextRect];

    [gc setShouldAntialias:[appSettings antiAliasing]];

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
        dataSet1 = [TemperatureMiner dataSetForKey:locations[[appSettings tempFG1Location] - 1]];
        if ([dataSet1 max] > maxValue) maxValue = [dataSet1 max];
		if ([dataSet1 min] < minValue) minValue = [dataSet1 min];
    }

    if ([appSettings tempFG2Location] > 0 && [appSettings tempFG2Location] <= [locations count]) {
        dataSet2 = [TemperatureMiner dataSetForKey:locations[[appSettings tempFG2Location] - 1]];
        if ([dataSet2 max] > maxValue) maxValue = [dataSet2 max];
		if ([dataSet2 min] < minValue) minValue = [dataSet2 min];
    }

    if ([appSettings tempFG3Location] > 0 && [appSettings tempFG3Location] <= [locations count]) {
        dataSet3 = [TemperatureMiner dataSetForKey:locations[[appSettings tempFG3Location] - 1]];
        if ([dataSet3 max] > maxValue) maxValue = [dataSet3 max];
 		if ([dataSet3 min] < minValue) minValue = [dataSet3 min];
    }
    
	// Scale the max and min values a bit.
	float range = maxValue - minValue;
	if (range < 20) range = 20;
	maxValue += 0.1 * range;
	minValue -= 0.1 * range;
	
    if (dataSet1) {
		[self drawRangedGraphWithDataFromDataSet:dataSet1 upperBound:maxValue lowerBound:minValue inRect:self.bounds flipped:NO filled:NO color:[appSettings graphFG1Color]];
    }
    
    if (dataSet2) {
		[self drawRangedGraphWithDataFromDataSet:dataSet2 upperBound:maxValue lowerBound:minValue inRect:self.bounds flipped:NO filled:NO color:[appSettings graphFG2Color]];
    }
    
    if (dataSet3) {
		[self drawRangedGraphWithDataFromDataSet:dataSet3 upperBound:maxValue lowerBound:minValue inRect:self.bounds flipped:NO filled:NO color:[appSettings graphFG3Color]];
    }

            
    // draw the text
    [gc setShouldAntialias:[appSettings antialiasText]];

	NSMutableDictionary *sAttributes = [NSMutableDictionary dictionaryWithDictionary:[appSettings alignLeftAttributes]];
	NSMutableDictionary *tAttributes = [NSMutableDictionary dictionaryWithDictionary:[appSettings alignRightAttributes]];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:@"" attributes:sAttributes];
	NSMutableAttributedString *t = [[NSMutableAttributedString alloc] initWithString:@"" attributes:tAttributes];
	
	NSAttributedString *newline = [[NSAttributedString alloc] initWithString:@"\n" attributes:[appSettings alignLeftAttributes]];
	
    NSInteger lineNumber = 0;
    for (i = 0; i < [locations count]; i++) {
		NSColor *lineColor = [appSettings textColor];
		if (i == [appSettings tempFG1Location] - 1) {
			lineColor = [[appSettings graphFG1Color] colorWithAlphaComponent:[appSettings textTransparency]];
		}
		else if (i == [appSettings tempFG2Location] - 1) {
			lineColor = [[appSettings graphFG2Color] colorWithAlphaComponent:[appSettings textTransparency]];
		}
		else if (i == [appSettings tempFG3Location] - 1) {
			lineColor = [[appSettings graphFG3Color] colorWithAlphaComponent:[appSettings textTransparency]];
		}
		if (lineColor) {
			sAttributes[NSForegroundColorAttributeName] = lineColor;
			tAttributes[NSForegroundColorAttributeName] = lineColor;
		}
		
        NSString *label = [TemperatureMiner labelForKey:locations[i]];
		if (label == nil) {
			continue;
		}

        float locationTemperature = [TemperatureMiner currentValueForKey:locations[i]];		
        NSString *units = [TemperatureMiner unitsForLocation:locations[i]];
		if (units == nil) {
			units = @"";
		}
		
		if (locationTemperature < 0.001 && ![units isEqualToString:@" rpm"]) continue;

        if ((lineNumber + 1) * textRectHeight > self.bounds.size.height) {
            break;
        }
        lineNumber++;
        
        if (lineNumber > 1) {
			[s appendAttributedString:newline];
			[t appendAttributedString:newline];
        }
        
		[s appendAttributedString:[[NSAttributedString alloc] initWithString:label attributes:sAttributes]];
        
        // Now add the temperature
        if ([appSettings tempUnits] == 0 && [units isEqualToString:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0]]) {
			units = [NSString stringWithFormat:@"%CF", (unsigned short)0x00B0];
			locationTemperature = locationTemperature * 1.8 + 32.;
        }
		
		if ([units isEqualToString:@" rpm"] | [units isEqualToString:@"%"]) {
			[t appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%3.0f%@", locationTemperature, units] attributes:tAttributes]];
		}
		else {
			[t appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%3.1f%@", locationTemperature, units] attributes:tAttributes]];
		}
    }
    
    if (lineNumber == 1) {
        textRect.origin.y = 0.5 * (self.bounds.size.height - textRectHeight);
        textRect.size.height = textRectHeight;
    }
    
    [t drawInRect:textRect];
    
	NSRect leftRect = NSMakeRect(textRect.origin.x, 
								 textRect.origin.y, 
								 textRect.size.width - [t size].width,
								 textRect.size.height);
    [s drawInRect:leftRect];
        
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

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Temperature View"];
    NSMenuItem *tMI;

    NSArray *locations = [TemperatureMiner locationKeysInOrder];
    int i;    
    for (i = 0; i < [locations count]; i++) {
        NSMutableString *s = [NSMutableString stringWithFormat:@"%@: ", [TemperatureMiner labelForKey:locations[i]]];
        NSString *units = [TemperatureMiner unitsForLocation:locations[i]];
		float locationTemperature = [TemperatureMiner currentValueForKey:locations[i]];
        if (locationTemperature < 0.001) {
			continue;
		}
		
        // Now add the temperature
        if ([appSettings tempUnits] == 0 && [units isEqualToString:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0]]) {
			units = [NSString stringWithFormat:@"%CF", (unsigned short)0x00B0];
			locationTemperature = locationTemperature * 1.8 + 32.;
			[s appendFormat:@"%3.1f%@", locationTemperature, units];
		}
		else {
			[s appendFormat:@"%3.0f%@", locationTemperature, units];
		}

        tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:s
																	action:@selector(emptyEvent:) 
															 keyEquivalent:@""];

        [myMenu addItem:tMI];
    }
        
    [myMenu addItem:[NSMenuItem separatorItem]];

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open XRG Temperature Preferences..." action:@selector(openTemperaturePreferences:) keyEquivalent:@""];
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

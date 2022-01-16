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
//  XRGTemperatureView.m
//

#import "XRGGraphWindow.h"
#import "XRGTemperatureView.h"
#import "XRGStatsManager.h"

@implementation XRGTemperatureView

+ (BOOL)showUnknownSensors {
    BOOL showUnknown = [[NSUserDefaults standardUserDefaults] boolForKey:XRG_tempShowUnknownSensors];
    
    // show all unnamed sensors if very few are known
    showUnknown |= [XRGTemperatureMiner shared].smcSensors.knownTemperatureKeys.count < 10;

    return showUnknown;
}


- (void)awakeFromNib {       
    [super awakeFromNib];
    
    parentWindow = (XRGGraphWindow *)[self window];
    [parentWindow setTemperatureView:self];
    [parentWindow initTimers];
    
    appSettings = [parentWindow appSettings];
    moduleManager = [parentWindow moduleManager];
	
	locationSizeCache = [[NSMutableDictionary alloc] initWithCapacity:20];
    
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
    
    updateCounter = 0;
}

- (void)setGraphSize:(NSSize)newSize {
    NSSize tmpSize;
    tmpSize.width = newSize.width;
    tmpSize.height = newSize.height;
    if (tmpSize.width < 1) tmpSize.width = 1;
    if (tmpSize.width > 20000) tmpSize.width = 20000;
    [self setWidth: tmpSize.width];
    graphSize = tmpSize;
}

- (void)setWidth:(NSInteger)newWidth {
    NSInteger newNumSamples = newWidth;

    if (newNumSamples < 0) return;

    [[XRGTemperatureMiner shared] setDataSize:newNumSamples];

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
    [[XRGTemperatureMiner shared] updateCurrentTemperatures:[XRGTemperatureView showUnknownSensors]];
    [self checkForConfiguredSensors];

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
    NSArray *locations = [[XRGTemperatureMiner shared] locationKeysIncludingUnknown:[XRGTemperatureView showUnknownSensors]];
    if ([locations count] == 0) {
        [@"Temperature n/a" drawInRect:[self paddedTextRect] withAttributes:[appSettings alignLeftAttributes]];
        return;
    }
    
    // Get our main sensor.
    XRGSensorData *sensor = [self sensor1];
    
    // Get the label for this sensor.
    NSString *primaryLabel = sensor.humanReadableName;
    if (!primaryLabel) {
        [@"Temperature n/a" drawInRect:[self paddedTextRect] withAttributes:[appSettings alignLeftAttributes]];
        return;
    }

    // Get the temperature value.
    float primaryValue = sensor.currentValue;
    float adaptedValue = primaryValue;
    
    // Get the units.
    NSString *units = sensor.units;
    if (units == nil) {
        units = @"";
    }

    // Now create the value string
    NSString *valueString = nil;
    if ([appSettings tempUnits] == XRGTemperatureUnitsF && [units isEqualToString:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0]]) {
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
    XRGDataSet *dataSet = sensor.dataSet;
    if (dataSet && dataSet.max > 0) {
        // Scale the primary value.
        float plotValue = (primaryValue - MIN(dataSet.min, 20)) / MAX(dataSet.max, 90) * 100;           // Use 90°C as max, or dataset.max, and 20°C as min
        [plotValues addObject:@(plotValue)];
    }
    
    // Add the fans
    NSArray *fans = [[XRGTemperatureMiner shared] fanValues];
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

    NSRect paddedTextRect = [self paddedTextRect];
    float textRectHeight = [appSettings textRectHeight];

    NSArray *locations = [[XRGTemperatureMiner shared] locationKeysIncludingUnknown:[XRGTemperatureView showUnknownSensors]];
    
    if ([locations count] == 0) {
        // This machine isn't supported.
        if ([@"No Sensors Found" sizeWithAttributes:[appSettings alignRightAttributes]].width < paddedTextRect.size.width) {
            [@"No Sensors Found" drawInRect:paddedTextRect withAttributes:[appSettings alignLeftAttributes]];
        }
        else {
            [@"No Sensors\nFound" drawInRect:paddedTextRect withAttributes:[appSettings alignLeftAttributes]];
        }

        return;
    }

    XRGSensorData *sensor1 = [self sensor1];
    XRGSensorData *sensor2 = [self sensor2];
    XRGSensorData *sensor3 = [self sensor3];

    if (!sensor1 && !sensor2 && !sensor3) {
        if ([@"Select Sensors in Prefs" sizeWithAttributes:[appSettings alignRightAttributes]].width < paddedTextRect.size.width) {
            [@"Select Sensors in Prefs" drawInRect:paddedTextRect withAttributes:[appSettings alignLeftAttributes]];
        }
        else {
            [@"Select Sensors\nin Prefs" drawInRect:paddedTextRect withAttributes:[appSettings alignLeftAttributes]];
        }
        return;
    }

    BOOL sensor1IsFan = [[XRGTemperatureMiner shared] isFanSensor:sensor1];
    BOOL sensor2IsFan = [[XRGTemperatureMiner shared] isFanSensor:sensor2];
    BOOL sensor3IsFan = [[XRGTemperatureMiner shared] isFanSensor:sensor3];

    NSMutableArray<XRGSensorData *> *sensors = [NSMutableArray array];
    if (sensor1) [sensors addObject:sensor1];
    if (sensor2) [sensors addObject:sensor2];
    if (sensor3) [sensors addObject:sensor3];

    float temperatureMax = 0;
    float temperatureMin = 9999999.f;

    if (sensor1.dataSet && !sensor1IsFan) {
        temperatureMax = MAX(temperatureMax, sensor1.dataSet.max);
        temperatureMin = MIN(temperatureMin, sensor1.dataSet.min);
    }

    if (sensor2.dataSet && !sensor2IsFan) {
        temperatureMax = MAX(temperatureMax, sensor2.dataSet.max);
        temperatureMin = MIN(temperatureMin, sensor2.dataSet.min);
    }

    if (sensor3.dataSet && !sensor3IsFan) {
        temperatureMax = MAX(temperatureMax, sensor3.dataSet.max);
        temperatureMin = MIN(temperatureMin, sensor3.dataSet.min);
    }

    // Scale the max and min values a bit.
    float range = MAX(temperatureMax - temperatureMin, 20);
    temperatureMax += 0.1 * range;
    temperatureMin -= 0.1 * range;

    // Draw the text
    NSRect textRect = NSMakeRect(paddedTextRect.origin.x, graphSize.height - textRectHeight, paddedTextRect.size.width, textRectHeight);
    NSRect barRect = NSMakeRect(self.bounds.origin.x, textRect.origin.y, self.bounds.size.width, textRect.size.height);
    
    NSMutableString *leftText = [[NSMutableString alloc] init];
    NSMutableString *rightText = [[NSMutableString alloc] init];
    NSInteger textLines = 0;

    for (NSInteger i = 0; i < sensors.count; i++) {
        XRGSensorData *sensor = sensors[i];
        if (!sensor.label) continue;

        float locationValue = sensor.currentValue;
        NSString *units = sensor.units;
        if (!units) units = @"";
        if (locationValue < 0.001 && ![units isEqualToString:@" rpm"]) continue;

        if ([appSettings tempUnits] == XRGTemperatureUnitsF && [units isEqualToString:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0]]) {
            units = [NSString stringWithFormat:@"%CF", (unsigned short)0x00B0];
            locationValue = locationValue * 1.8 + 32.;
        }

        NSString *valueString;
        if ([units isEqualToString:@" rpm"] | [units isEqualToString:@"%"]) {
            valueString = [NSString stringWithFormat:@"%3.0f%@", locationValue, units];
        }
        else {
            valueString = [NSString stringWithFormat:@"%3.1f%@", locationValue, units];
        }

        [[appSettings graphFG1Color] set];
        if ([[XRGTemperatureMiner shared] isFanSensor:sensor]) {
            float min = 0;
            float max = [[XRGTemperatureMiner shared] maxSpeedForFan:sensor];

            CGContextFillRect(gc.CGContext, CGRectMake(barRect.origin.x, barRect.origin.y, MAX(1, ((locationValue - min) / (max - min)) * barRect.size.width), (i == 0) ? barRect.size.height : floor(barRect.size.height - 1)));
        }
        else {
            float min = temperatureMin;
            float max = temperatureMax;

            CGContextFillRect(gc.CGContext, CGRectMake(barRect.origin.x, barRect.origin.y, MAX(1, ((locationValue - min) / (max - min)) * barRect.size.width), (i == 0) ? barRect.size.height : floor(barRect.size.height - 1)));
        }

        [[appSettings borderColor] set];
        NSRectFill(NSMakeRect(self.bounds.origin.x, barRect.origin.y - 1, self.bounds.size.width, 2));

        [leftText appendFormat:@"%@\n", sensor.label];
        [rightText appendFormat:@"%@\n", valueString];
        textLines++;

        barRect.origin.y -= barRect.size.height;
        textRect.origin.y -= textRect.size.height;
        if (textRect.origin.y < 0) break;
    }
    
    textRect.origin.y += textRect.size.height;
    textRect.size.height *= textLines;
    [self drawLeftText:leftText centerText:nil rightText:rightText inRect:textRect];

    [[appSettings borderColor] set];
    NSRectFill(NSMakeRect(self.bounds.origin.x, NSMaxY(textRect) - 1, self.bounds.size.width, 2));

    // Draw the graph.
    [gc setShouldAntialias:[appSettings antiAliasing]];
    NSRect graphRect = NSMakeRect(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, NSMinY(textRect) - self.bounds.origin.y - 2);

    if (sensor1.dataSet) {
        float min = sensor1IsFan ? 0 : temperatureMin;
        float max = sensor1IsFan ? [[XRGTemperatureMiner shared] maxSpeedForFan:sensor1] : temperatureMax;

		[self drawRangedGraphWithDataFromDataSet:sensor1.dataSet upperBound:max lowerBound:min inRect:graphRect flipped:NO filled:YES color:[appSettings graphFG1Color]];
    }
    
    if (sensor2.dataSet) {
        float min = sensor2IsFan ? 0 : temperatureMin;
        float max = sensor2IsFan ? [[XRGTemperatureMiner shared] maxSpeedForFan:sensor2] : temperatureMax;

		[self drawRangedGraphWithDataFromDataSet:sensor2.dataSet upperBound:max lowerBound:min inRect:graphRect flipped:NO filled:NO color:[appSettings graphFG2Color]];
    }
    
    if (sensor3.dataSet) {
        float min = sensor3IsFan ? 0 : temperatureMin;
        float max = sensor3IsFan ? [[XRGTemperatureMiner shared] maxSpeedForFan:sensor3] : temperatureMax;

		[self drawRangedGraphWithDataFromDataSet:sensor3.dataSet upperBound:max lowerBound:min inRect:graphRect flipped:NO filled:NO color:[appSettings graphFG3Color]];
    }
}

- (XRGSensorData *)sensor1 {
    NSString *sensorKey = [appSettings tempFG1Location];
    return [XRGTemperatureMiner.shared sensorForLocation:sensorKey];
}

- (XRGSensorData *)sensor2 {
    NSString *sensorKey = [appSettings tempFG2Location];
    return [XRGTemperatureMiner.shared sensorForLocation:sensorKey];
}

- (XRGSensorData *)sensor3 {
    NSString *sensorKey = [appSettings tempFG3Location];
    return [XRGTemperatureMiner.shared sensorForLocation:sensorKey];
}

/// Check if we have configured temperature sensors, and make some decent default choices if none were setup previously.
- (void)checkForConfiguredSensors {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs boolForKey:XRG_tempLocationsAutoconfigured]) {
        // Already autoconfigured.  Don't do it again.
        return;
    }
    if (([self sensor1] != nil) || ([self sensor2] != nil) || ([self sensor3] != nil)) {
        return;
    }

    [defs setBool:YES forKey:XRG_tempLocationsAutoconfigured];

    NSArray *locations = [[XRGTemperatureMiner shared] locationKeysIncludingUnknown:[XRGTemperatureView showUnknownSensors]];
    NSMutableArray *preferredLocationKeys = [NSMutableArray array];

    // First look for a Fan.
    NSString *fanKey = [self preferredKeyWithPrefix:@"Fan" inLocationKeys:locations];
    if (fanKey) {
        [preferredLocationKeys addObject:fanKey];
    }

    // Second look for a CPU.
    NSString *cpuKey = [self preferredKeyWithPrefix:@"CPU" inLocationKeys:locations];
    if (cpuKey) {
        [preferredLocationKeys addObject:cpuKey];
    }

    // Thrid look for a GPU.
    NSString *gpuKey = [self preferredKeyWithPrefix:@"GPU" inLocationKeys:locations];
    if (gpuKey) {
        [preferredLocationKeys addObject:gpuKey];
    }

    // Fourth look for a SSD.
    NSString *ssdKey = [self preferredKeyWithPrefix:@"SSD" inLocationKeys:locations];
    if (ssdKey) {
        [preferredLocationKeys addObject:ssdKey];
    }

    NSString *sensor1Key = [preferredLocationKeys firstObject];
    if (sensor1Key) {
        [preferredLocationKeys removeObjectAtIndex:0];
        [appSettings setTempFG1Location:sensor1Key];
    }

    NSString *sensor2Key = [preferredLocationKeys firstObject];
    if (sensor2Key) {
        [preferredLocationKeys removeObjectAtIndex:0];
        [appSettings setTempFG2Location:sensor2Key];
    }

    NSString *sensor3Key = [preferredLocationKeys firstObject];
    if (sensor3Key) {
        [preferredLocationKeys removeObjectAtIndex:0];
        [appSettings setTempFG3Location:sensor3Key];
    }
}

- (NSString *)preferredKeyWithPrefix:(NSString *)prefix inLocationKeys:(NSArray<NSString *> *)locations {
    for (NSString *key in locations) {
        XRGSensorData *sensor = [[XRGTemperatureMiner shared] sensorForLocation:key];
        NSString *humanReadableName = sensor.label;

        if ([humanReadableName hasPrefix:prefix]) {
            return key;
        }
    }

    return nil;
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

    NSArray *locations = [[XRGTemperatureMiner shared] locationKeysIncludingUnknown:[XRGTemperatureView showUnknownSensors]];
    int i;    
    for (i = 0; i < [locations count]; i++) {
        XRGSensorData *sensor = [[XRGTemperatureMiner shared] sensorForLocation:locations[i]];

        NSMutableString *s = [NSMutableString stringWithFormat:@"%@: ", sensor.label];
        NSString *units = sensor.units;
		float locationTemperature = sensor.currentValue;
        if (locationTemperature < 0.001) {
			continue;
		}
		
        // Now add the temperature
        if ([appSettings tempUnits] == XRGTemperatureUnitsF && [units isEqualToString:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0]]) {
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

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Reset Graph" action:@selector(clearData:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    [myMenu addItem:[NSMenuItem separatorItem]];

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open XRG Temperature Preferences..." action:@selector(openTemperaturePreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open Temperature Sensors Window..." action:@selector(showSensorWindow:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    return myMenu;
}

- (void)clearData:(NSEvent *)theEvent {
    [[XRGTemperatureMiner shared] reset];
    [[XRGStatsManager shared] clearHistoryForModule:XRGStatsModuleNameTemperature];
}

- (void)emptyEvent:(NSEvent *)theEvent {
}

- (void)openTemperaturePreferences:(NSEvent *)theEvent {
    [[parentWindow controller] showPrefsWithPanel:@"Temperature"];
}

- (void)showSensorWindow:(NSEvent *)theEvent {
    [(XRGAppDelegate *)[[NSApplication sharedApplication] delegate] openSensorWindow:self];
}

- (BOOL) acceptsFirstMouse {
    return YES;
}

@end

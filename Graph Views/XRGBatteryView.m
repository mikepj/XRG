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
//  XRGBatteryView.m
//


#import "XRGGraphWindow.h"
#import "XRGBatteryView.h"

#include <IOKit/pwr_mgt/IOPM.h>
#include <IOKit/pwr_mgt/IOPMLib.h>

#include "IOKit/ps/IOPowerSources.h"
#include "IOKit/ps/IOPSKeys.h"

@implementation XRGBatteryView

- (void)awakeFromNib {    
    maxVolts = 0;
    maxAmps = 0;
	minAmps = 0;
    currentIndex = 0;
    values = 0;
    powerStatus = UNKNOWN;
    numBatteries = 0;
    minutesRemaining = 0;
    currentPercent = 0;
    chargeSum = 0;
    capacitySum = 0;
    voltageAverage = 0;
    amperageAverage = 0;

    
    graphPixelTimeFrame = 30;
    currentPixelTime = 0.;
    statsUpdateTimeFrame = 10;
    currentStatsTime = statsUpdateTimeFrame + 1;
    tripleCount = 0;
    
    graphSize    = NSMakeSize(90, 112);
              
    parentWindow = (XRGGraphWindow *)[self window];
    [parentWindow setBatteryView:self];
    [parentWindow initTimers];  
    appSettings = [parentWindow appSettings];
    moduleManager = [parentWindow moduleManager];
    
    // flush out the first spike
    [self graphUpdate:nil];
    
    NBF_WIDE          = 0;
    NBF_NORMAL        = 0;
    PERCENT_WIDE      = 0;
    CHARGED_WIDE      = 0;
    ESTIMATING_WIDE   = 0;
    ESTIMATING_NORMAL = 0;
    VOLTAGE_WIDE      = 0;
    VOLTAGE_NORMAL    = 0;
    AMPERAGE_WIDE     = 0;
    AMPERAGE_NORMAL   = 0;
    CURRENT_WIDE      = 0;
    CURRENT_NORMAL    = 0;
    CAPACITY_WIDE     = 0;
    CAPACITY_NORMAL   = 0;
    NBIF_WIDE         = 0;
    NBIF_NORMAL       = 0;
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];    
    m = [[XRGModule alloc] initWithName:@"Battery" andReference:self];
    m.doesFastUpdate = NO;
    m.doesGraphUpdate = YES;
    m.doesMin5Update = NO;
    m.doesMin30Update = NO;
    m.displayOrder = 3;
    [self updateMinSize];
    [m setIsDisplayed: (bool)[defs boolForKey:XRG_showBatteryGraph]];

    [[parentWindow moduleManager] addModule:m];
}

- (void)setGraphSize:(NSSize)newSize {
    NSSize tmpSize;
    tmpSize.width = newSize.width;
    tmpSize.height = newSize.height;
    if (tmpSize.width < 1) tmpSize.width = 1;
    if (tmpSize.width > 2000) tmpSize.width = 2000;
    [self setWidth:tmpSize.width];
    graphSize = tmpSize;
    
    // Figure out our display mode
    if (graphSize.width < 70) {
        displayMode = SMALL;
    }
    else if (graphSize.width >= 70 && graphSize.width <= 135) {
        displayMode = NORMAL;
    }
    else {
        displayMode = WIDE;
    }
}

- (void)setWidth:(int)newWidth {
    NSInteger i;
    NSInteger newNumSamples = newWidth;
    maxVal = 0;
    
    if (values) {
        NSInteger *newVals;
        NSInteger newValIndex = newNumSamples - 1;
        newVals   = calloc(newNumSamples, sizeof(NSInteger));
        
        for (i = currentIndex; i >= 0; i--) {
            if (newValIndex < 0) break;
            newVals[newValIndex]   = values[i];            
            newValIndex--;
        }
        
        for (i = numSamples - 1; i > currentIndex; i--) {
            if (newValIndex < 0) break;
            newVals[newValIndex]   = values[i];
            newValIndex--;
        }
                
        free(values);      
        values = newVals;
        currentIndex = newNumSamples - 1;
    }
    else {
        values = calloc(newNumSamples, sizeof(NSInteger));
        currentIndex = 0;
    }
    numSamples  = newNumSamples;
}

- (void)updateMinSize {
    NSMutableDictionary *textAttributes = [appSettings alignRightAttributes];

    float width, height;
    height = [appSettings textRectHeight];
    width = [@"100% Chgd." sizeWithAttributes:textAttributes].width + 6;
    
    [m setMinWidth: width];
    [m setMinHeight: height];
    
    // Update the cache dictionary
    NBF_WIDE          = [@"No Battery Found" sizeWithAttributes:textAttributes].width;
    NBF_NORMAL        = [@"No Battery\nFound" sizeWithAttributes:textAttributes].width;
    
    PERCENT_WIDE      = [@"100% Charged 9:99 Left" sizeWithAttributes:textAttributes].width;
    
    CHARGED_WIDE      = [@"100% Charged" sizeWithAttributes:textAttributes].width;
    
    ESTIMATING_WIDE   = [@"100% Estimating Left" sizeWithAttributes:textAttributes].width;
    ESTIMATING_NORMAL = [@"100% Estimating" sizeWithAttributes:textAttributes].width;
    
    VOLTAGE_WIDE      = [@"Voltage: 99.999V" sizeWithAttributes:textAttributes].width;
    VOLTAGE_NORMAL    = [@"Volts: 99.999" sizeWithAttributes:textAttributes].width;
    
    AMPERAGE_WIDE     = [@"Current: 9.999A" sizeWithAttributes:textAttributes].width;
    AMPERAGE_NORMAL   = [@"Cur: 9.999" sizeWithAttributes:textAttributes].width;
    
    CURRENT_WIDE      = [@"Remaining Capacity: " sizeWithAttributes:textAttributes].width;
    CURRENT_NORMAL    = [@"Rem: " sizeWithAttributes:textAttributes].width;
    
    CAPACITY_WIDE     = [@"Maximum Capacity: " sizeWithAttributes:textAttributes].width;
    CAPACITY_NORMAL   = [@"Max: " sizeWithAttributes:textAttributes].width;
    
    NBIF_WIDE         = [@"No Battery Info Found" sizeWithAttributes:textAttributes].width;
    NBIF_NORMAL       = [@"No Battery\nInfo Found" sizeWithAttributes:textAttributes].width;
    
    MAH_STRING        = [@"9999mAh" sizeWithAttributes:textAttributes].width;
}

// Battery stats code based on code in Idleize by Jason Patterson.  
// http://www.pattosoft.com.au/idleize/
- (void)graphUpdate:(NSTimer *)aTimer {
    static mach_port_t port;
    CFArrayRef battinfo;
    kern_return_t err;
    
    // increment our charging counter
    tripleCount = (tripleCount + 1) % 4;
    
    // If we are changing power status, then recalculate our time remaining immediately
    if (lastPowerStatus != powerStatus) {
        currentPixelTime = graphPixelTimeFrame + 1;
        tripleCount = 0;
    }
    
    float refresh = [appSettings graphRefresh];
    currentStatsTime += refresh;
    currentPixelTime += refresh;
    if (currentPixelTime > graphPixelTimeFrame) {
        currentPixelTime = 0.;
        minutesRemaining = 0.;
        
        // change the minutes remaining
        if (current && capacity) {
            if (powerStatus == RUNNING_ON_BATTERY) {
                NSInteger changePerMinute = (CGFloat)(values[currentIndex] - chargeSum) * (CGFloat)(60. / (CGFloat)graphPixelTimeFrame);
                minutesRemaining = (CGFloat)chargeSum / (CGFloat)changePerMinute;
            }
            else if (powerStatus == CHARGING) {
                NSInteger changePerMinute = (CGFloat)(chargeSum - values[currentIndex]) * (CGFloat)(60. / (CGFloat)graphPixelTimeFrame);
                minutesRemaining = (CGFloat)(capacitySum - chargeSum) / (CGFloat)changePerMinute;
            }
        }
        // Check that minutes remaining is reasonable (< 20 hours)
        if (minutesRemaining > 20 * 60) 
            minutesRemaining = 0;
        
        // Save the time remaining into the values array for graphing.
        currentIndex++;
        if (currentIndex == numSamples)
            currentIndex = 0;

        if (current) {
            values[currentIndex] = chargeSum;
        }
    }
    
    // Cycle the powerStatus to lastPowerStatus before it's possible for us 
    // to return and before we set the new powerStatus.
    lastPowerStatus = powerStatus;
    
    if (currentStatsTime > statsUpdateTimeFrame) {
        currentStatsTime = 0.;
    }
    else {
        [self setNeedsDisplay:YES];
        return;
    }
    
    if (!port) {
        if ((err = IOMasterPort(bootstrap_port, &port)) != kIOReturnSuccess) {
            powerStatus = UNKNOWN;
            return;
        }
    }
	
    if ((err = IOPMCopyBatteryInfo(port, &battinfo)) == kIOReturnSuccess && battinfo != NULL) {
		NSArray *batteryInfoArray = (NSArray *)CFBridgingRelease(battinfo);
        numBatteries = batteryInfoArray.count;
        
        // Since there could be a different number of batteries each time we run this code,
        // we have to reset the arrays that hold the battery values each time.
        if (current)  free(current);
        if (capacity) free(capacity);
        if (charge)   free(charge);
        if (voltage)  free(voltage);
        if (amperage) free(amperage);
        
        if (!numBatteries) {
            current = capacity = charge = voltage = amperage = 0;
            powerStatus = NO_BATTERY;
        }
        else {
            current  = (NSInteger *)calloc(numBatteries, sizeof(NSInteger));
            capacity = (NSInteger *)calloc(numBatteries, sizeof(NSInteger));
            charge   = (NSInteger *)calloc(numBatteries, sizeof(NSInteger));
            voltage  = (NSInteger *)calloc(numBatteries, sizeof(NSInteger));
            amperage = (NSInteger *)calloc(numBatteries, sizeof(NSInteger));
        }
            
        currentPercent = 0;
        chargeSum = 0;
        capacitySum = 0;
        voltageAverage = 0;
        amperageAverage = 0;
        
        NSInteger skipBatteries = 0;
        
        for (NSInteger i = 0; i < numBatteries; i++) {
            NSInteger flags = [[batteryInfoArray[i] valueForKey:@kIOBatteryFlagsKey] integerValue];
            
            // Check if this is really a battery
            if (flags & kIOPMACnoChargeCapability) {
                current[i] = capacity[i] = charge[i] = voltage[i] = amperage[i] = 0;
                skipBatteries++;
                continue;
            }
            
            if ((flags & kIOBatteryChargerConnect) && (flags & kIOBatteryCharge)) {
                // if the charger is connected, and the battery is charging...
                powerStatus = CHARGING;
            }
            else if ((flags & kIOBatteryChargerConnect) && !(flags & kIOBatteryCharge)) {
                // if the charger is connected, and the battery is not charging...
                powerStatus = CHARGED;
            }
            else {
                powerStatus = RUNNING_ON_BATTERY;
            }
            
            // get the current charge
			current[i] = [[batteryInfoArray[i] valueForKey:@kIOBatteryCurrentChargeKey] integerValue];
            chargeSum += current[i];
            
            // get the total capacity
			capacity[i] = [[batteryInfoArray[i] valueForKey:@kIOBatteryCapacityKey] integerValue];
            capacitySum += capacity[i];
                                
            // get the current voltage
			voltage[i] = [[batteryInfoArray[i] valueForKey:@kIOBatteryVoltageKey] integerValue];
            if (voltage[i] || i == 0)
                voltageAverage += voltage[i];
            else 
                voltageAverage += voltageAverage / i;
                                                
            // get the current amperage
			amperage[i] = [[batteryInfoArray[i] valueForKey:@kIOBatteryAmperageKey] integerValue];
            if (amperage[i] || i == 0)
                amperageAverage += amperage[i];
            else 
                amperageAverage += amperageAverage / i;
            
            // calculate the % charge
            charge[i] = (int)(100.0 * current[i] / capacity[i] + 0.5);
            
            if (charge[i] < 95. && powerStatus == CHARGED) {
                powerStatus = CHARGING;
            }
            
            if (current[i] == 0 && voltage[i] == 0) powerStatus = NO_BATTERY;
        }
        
        if (numBatteries - skipBatteries > 0) {
            voltageAverage  /= (numBatteries - skipBatteries);
            amperageAverage /= (numBatteries - skipBatteries);
            currentPercent = (int)(100.0 * chargeSum / capacitySum + 0.5);
            if (amperageAverage > maxAmps) maxAmps = amperageAverage;
			if (amperageAverage < minAmps) minAmps = amperageAverage;
            if (voltageAverage > maxVolts) maxVolts = voltageAverage;
        }
        else {
            voltageAverage = 0;
            amperageAverage = 0;
            currentPercent = 0;
            powerStatus = UNKNOWN;
        }
    
        [self setNeedsDisplay:YES];
    }  
    else {
        powerStatus = UNKNOWN;
    }
	
    return;
}

/*! Lots of UPS devices don't reveal anything really useful here other than time to empty and charge %.  Leaving this here for possible future use though. */
//- (void)upsUpdate {
//	CFTypeRef powerBlob = IOPSCopyPowerSourcesInfo();
//	if (powerBlob != NULL) {
//		CFArrayRef powerSourceKeys = IOPSCopyPowerSourcesList(powerBlob);
//		if (powerSourceKeys != NULL) {
//			for (NSInteger i = 0; i < CFArrayGetCount(powerSourceKeys); i++) {
//				CFTypeRef powerSourceKey = CFArrayGetValueAtIndex(powerSourceKeys, i);
//				CFDictionaryRef powerD = IOPSGetPowerSourceDescription(powerBlob, powerSourceKey);
//				if (powerD != NULL) {
//					
//				}
//			}
//			CFRelease(powerSourceKeys);
//		}
//		
//		CFRelease(powerBlob);
//	}
//}

- (void)drawRect:(NSRect)rect {
    if ([self isHidden]) return;

    #ifdef XRG_DEBUG
        NSLog(@"In Battery DrawRect."); 
    #endif

    NSGraphicsContext *gc = [NSGraphicsContext currentContext]; 
    
    float textRectHeight = [appSettings textRectHeight];
    NSRect percentRect = NSMakeRect(0, 
                                    graphSize.height - textRectHeight, 
                                    graphSize.width, 
                                    textRectHeight);    
    NSRect textRect = NSMakeRect(0, 
                                 graphSize.height - textRectHeight, 
                                 graphSize.width, 
                                 textRectHeight);
    
    // Clear the background
    [[appSettings graphBGColor] set];
    NSRectFill(rect);
        
    // First check if there is battery data to graph.
    if (powerStatus == NO_BATTERY || powerStatus == UNKNOWN) {
        if (NBF_WIDE <= graphSize.width) {
            [@"No Battery Found" drawAtPoint:textRect.origin withAttributes:[appSettings alignLeftAttributes]];
        }
        else if (NBF_NORMAL <= graphSize.width) {
            textRect.origin.y -= textRectHeight;
            [@"No Battery\nFound" drawAtPoint:textRect.origin withAttributes:[appSettings alignLeftAttributes]];
        }
        else {
            textRect.origin.y -= textRectHeight * 2;
            [@"No\nBattery\nFound" drawAtPoint:textRect.origin withAttributes:[appSettings alignLeftAttributes]];
        }
        
        return;
    }

    [gc setShouldAntialias:[appSettings antiAliasing]];
    
    // draw the battery bar
    [[appSettings graphFG1Color] set];
    if (charge) {
        percentRect.size.width = rect.size.width * (float)((float)currentPercent / 100.);
        NSRectFill(percentRect);
    }
    
    // set graphFG2Color before drawing the triple bar for charging.
    [[appSettings graphFG2Color] set];
    if (powerStatus == CHARGING) {
        NSRect chargingRect = NSMakeRect(percentRect.origin.x + percentRect.size.width, 
                                         percentRect.origin.y,
                                         (rect.size.width - percentRect.size.width) * ((float)tripleCount / 3.),
                                         percentRect.size.height);
                                        
        NSRectFill(chargingRect);
    }
    
    // draw the volts bar
    percentRect.origin.y -= textRectHeight;
    if (voltage) {
        percentRect.size.width = (maxVolts == 0) ? 0 : rect.size.width * (float)((float)voltageAverage / (float)maxVolts);
        NSRectFill(percentRect);
    }
    
    // draw the amps bar
    [[appSettings graphFG3Color] set];
    percentRect.origin.y -= textRectHeight;
	percentRect.origin.x = rect.size.width / 2.;
    if (amperage) {
		if (amperageAverage > 0) {
			percentRect.size.width = (maxAmps == 0) ? 0 : (rect.size.width / 2.) * (float)((float)amperageAverage / (float)maxAmps);
			NSRectFill(percentRect);
		}
		else {
			percentRect.size.width = (minAmps == 0) ? 0 : (rect.size.width / 2.) * (float)((float)amperageAverage / (float)minAmps);
			percentRect.origin.x -= percentRect.size.width;
			NSRectFill(percentRect);
		}
    }
	percentRect.origin.x = 0;
    
    // draw the borders
    [[appSettings borderColor] set];
    percentRect.size.width = graphSize.width;
    percentRect.size.height = 2;
    percentRect.origin.y--;
    int topOfCapacityGraph = percentRect.origin.y;
    NSRectFill(percentRect);
    percentRect.origin.y += textRectHeight;
    NSRectFill(percentRect);
    percentRect.origin.y += textRectHeight;
    NSRectFill(percentRect);
	
	// Fill the split bar for the amp graph
	NSRectFill(NSMakeRect((rect.size.width / 2.) - 1., topOfCapacityGraph, 2., textRectHeight + 2.));
    
    // Draw the battery capacity graph, only if there is space for it on the graph.
    percentRect.size.width = graphSize.width;
    percentRect.origin.y = 0;
    percentRect.size.height = topOfCapacityGraph;
    
    if (capacity && percentRect.size.height > 0) {
        CGFloat *data = (CGFloat *)alloca(numSamples * sizeof(CGFloat));
        for (NSInteger i = 0; i < numSamples; ++i) {
            data[i] = (capacitySum == 0) ? 0 : ((CGFloat)values[i] / (CGFloat)capacitySum) * 100;
            if (data[i] > 100) data[i] = 100;
        }
    
        [self drawGraphWithData:data size:numSamples currentIndex:currentIndex maxValue:100.0f inRect:percentRect flipped:NO color:[appSettings graphFG1Color]];
    }

    [gc setShouldAntialias:YES];


    // Draw the text.
    [gc setShouldAntialias:[appSettings antialiasText]];

    textRect.origin.x   += 3;
    textRect.size.width -= 6;

    if (current && charge && capacity && voltage && amperage) {
        NSMutableString *leftS = [[NSMutableString alloc] init];
        NSMutableString *rightS = [[NSMutableString alloc] init];
        NSMutableString *centerS = [[NSMutableString alloc] init];
        [leftS setString:@""];
        [rightS setString:@""];
        [centerS setString:@""];
        bool drawCenter = NO;

        // Draw the battery percentage
        if (minutesRemaining > 0) {
            NSString *mrString;
            if (minutesRemaining % 60 < 10)
                mrString = [NSString stringWithFormat:@"%ld:0%ld", (long)minutesRemaining / 60, (long)minutesRemaining % 60];
            else 
                mrString = [NSString stringWithFormat:@"%ld:%ld", (long)minutesRemaining / 60, (long)minutesRemaining % 60];
            
            if (PERCENT_WIDE <= textRect.size.width) {
                [leftS appendFormat:@"%ld%% Charged", (long)currentPercent];
                [rightS appendFormat:@"%@ Left", mrString];
            }
            else {
                [leftS appendFormat:@"%ld%%", (long)currentPercent];
                [rightS appendString: mrString];
            }
        }
        else if (powerStatus == CHARGED) {
            [leftS appendFormat:@"%ld%%", (long)currentPercent];
            if (CHARGED_WIDE <= textRect.size.width)
                [rightS appendFormat:@"Charged"];
            else
                [rightS appendFormat:@"Chgd."];
        }
        else {
            [leftS appendFormat:@"%ld%%", (long)currentPercent];
            if (ESTIMATING_WIDE <= textRect.size.width)
                [rightS appendFormat:@"Estimating Left"];
            else if (ESTIMATING_NORMAL <= textRect.size.width)
                [rightS appendFormat:@"Estimating"];
            else
                [rightS appendFormat:@"Est."];
        }
        
        // Draw the voltage
        if (textRect.origin.y - textRectHeight > 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            if (VOLTAGE_WIDE <= textRect.size.width) {
                [leftS appendString:@"\nVoltage:"];
                [rightS appendFormat:@"\n%2.3fV", (float)voltageAverage / 1000.];
                [centerS appendString:@"\n "];
            }
            else if (VOLTAGE_NORMAL <= textRect.size.width) {
                [leftS appendString:@"\nVolts:"];
                [rightS appendFormat:@"\n%2.3f", (float)voltageAverage / 1000.];
                [centerS appendString:@"\n "];
            }
            else {
                [leftS appendString:@"\n "];
                [rightS appendString:@"\n "];
                [centerS appendFormat:@"\n%2.3fV", (float)voltageAverage / 1000.];
                drawCenter = YES;
            }
        }
    
        // Draw the amperage
        if (textRect.origin.y - textRectHeight > 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            if (AMPERAGE_WIDE <= textRect.size.width) {
                [leftS appendString:@"\nCurrent:"];
                [rightS appendFormat:@"\n%1.3fA", (float)amperageAverage / 1000.];
                [centerS appendString:@"\n "];
            }
            else if (AMPERAGE_NORMAL <= textRect.size.width) {
                [leftS appendString:@"\nCur:"];
                [rightS appendFormat:@"\n%1.3f", (float)amperageAverage / 1000.];
                [centerS appendString:@"\n "];
            }
            else {
                [leftS appendString:@"\n "];
                [rightS appendString:@"\n "];
                [centerS appendFormat:@"\n%1.3fA", (float)amperageAverage / 1000.];
                drawCenter = YES;
            }
        }

        // Draw the current charge
        if (textRect.origin.y - textRectHeight > 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            NSString *chargeString = [NSString stringWithFormat:@"\n%ldmAh", (long)chargeSum];
            
            if (CURRENT_WIDE + MAH_STRING <= textRect.size.width) {
                [leftS appendString:@"\nRemaining Capacity:"];
                [rightS appendString:chargeString];
                [centerS appendString:@"\n "];
            }
            else if (CURRENT_NORMAL + MAH_STRING <= textRect.size.width) {
                [leftS appendString:@"\nRem:"];
                [rightS appendString:chargeString];
                [centerS appendString:@"\n "];
            }
            else {
                [leftS appendString:@"\n "];
                [rightS appendString:@"\n "];
                [centerS appendString:chargeString];
                drawCenter = YES;
            }
        }
        
        // Draw the capacity
        if (textRect.origin.y - textRectHeight > 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            NSString *capacityString = [NSString stringWithFormat:@"\n%ldmAh", (long)capacitySum];
            
            if (CAPACITY_WIDE + MAH_STRING <= textRect.size.width) {
                [leftS appendString:@"\nMaximum Capacity:"];
                [rightS appendString:capacityString];
                [centerS appendString:@"\n "];
            }
            else if (CAPACITY_NORMAL + MAH_STRING <= textRect.size.width) {
                [leftS appendString:@"\nMax:"];
                [rightS appendString:capacityString];
                [centerS appendString:@"\n "];
            }
            else {
                [leftS appendString:@"\n "];
                [rightS appendString:@"\n "];
                [centerS appendString:capacityString];
                drawCenter = YES;
            }
        }
        
        [leftS drawAtPoint:textRect.origin withAttributes:[appSettings alignLeftAttributes]];
        [rightS drawInRect:textRect withAttributes:[appSettings alignRightAttributes]];
        
        if (drawCenter) {
            [centerS drawInRect:textRect withAttributes:[appSettings alignCenterAttributes]];
        }

    }
    else {
        if (NBIF_WIDE <= textRect.size.width) {
            [@"No Battery Info Found" drawAtPoint:textRect.origin withAttributes:[appSettings alignLeftAttributes]];
        }
        else if (NBIF_NORMAL <= textRect.size.width) {
            textRect.origin.y -= textRectHeight;
            [@"No Battery\nInfo Found" drawAtPoint:textRect.origin withAttributes:[appSettings alignLeftAttributes]];
        }
        else {
            textRect.origin.y -= textRectHeight * 3;
            [@"No\nBattery\nInfo\nFound" drawAtPoint:textRect.origin withAttributes:[appSettings alignLeftAttributes]];
        }
    }
    
    [gc setShouldAntialias:YES];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Battery View"];
    NSMenuItem *tMI;

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open Energy Saver System Preferences..." action:@selector(openEnergySaverSystemPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    return myMenu;
}

- (void)openEnergySaverSystemPreferences:(NSEvent *)theEvent {
    [NSTask 
      launchedTaskWithLaunchPath:@"/usr/bin/open"
      arguments:@[@"/System/Library/PreferencePanes/EnergySaver.prefPane"]
    ];
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

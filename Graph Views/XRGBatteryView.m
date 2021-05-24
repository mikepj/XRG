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
    powerStatus = XRGBatteryStatusUnknown;
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
    self.chargeWatts = [[XRGDataSet alloc] init];
    self.dischargeWatts = [[XRGDataSet alloc] init];
    
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
    POWER_WIDE        = 0;
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
    if (tmpSize.width > 20000) tmpSize.width = 20000;
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
    [self.chargeWatts resize:newWidth];
    [self.dischargeWatts resize:newWidth];
    
    numSamples  = newWidth;
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
    
    POWER_WIDE        = [@"Power: 99.9V" sizeWithAttributes:textAttributes].width;
    
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
            powerStatus = XRGBatteryStatusUnknown;
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
            powerStatus = XRGBatteryStatusNoBattery;
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
                powerStatus = XRGBatteryStatusCharging;
            }
            else if ((flags & kIOBatteryChargerConnect) && !(flags & kIOBatteryCharge)) {
                // if the charger is connected, and the battery is not charging...
                powerStatus = XRGBatteryStatusCharged;
            }
            else {
                powerStatus = XRGBatteryStatusRunningOnBattery;
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
            
            if (charge[i] < 95. && powerStatus == XRGBatteryStatusCharged) {
                powerStatus = XRGBatteryStatusOnHold;
            }
            
            if (current[i] == 0 && voltage[i] == 0) powerStatus = XRGBatteryStatusNoBattery;
        }
        
        // Save the watts being used.
        CGFloat chargeWattsSum = 0;
        CGFloat dischargeWattsSum = 0;
        for (NSInteger i = 0; i < numBatteries; i++) {
            CGFloat watts = ((CGFloat)amperage[i] / 1000) * ((CGFloat)voltage[i] / 1000);
            if (watts < 0) {
                dischargeWattsSum += -watts;
            }
            else {
                chargeWattsSum += watts;
            }
        }
        [self.chargeWatts setNextValue:chargeWattsSum];
        [self.dischargeWatts setNextValue:dischargeWattsSum];
        
        // Calculate the time remaining.
        if ((fabs(chargeWattsSum) < 0.1) && (fabs(dischargeWattsSum) < 0.1)) {
            minutesRemaining = 0;
        }
        else {
            CGFloat mahChange = 0;
            for (NSInteger i = 0; i < numBatteries; i++) {
                mahChange += (CGFloat)amperage[i];
            }
            
            if (mahChange < 0) {
                // Discharging
                CGFloat remaingingMAH = chargeSum;
                minutesRemaining = minutesRemaining * 0.8 + (remaingingMAH / -mahChange * 60) * 0.2;
            }
            else {
                // Charging
                CGFloat remaingingMAH = capacitySum - chargeSum;
                minutesRemaining = minutesRemaining * 0.8 + (remaingingMAH / mahChange * 60) * 0.2;
            }
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
            powerStatus = XRGBatteryStatusUnknown;
        }
    
        [self setNeedsDisplay:YES];
    }  
    else {
        powerStatus = XRGBatteryStatusUnknown;
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
                                    graphSize.height - textRectHeight * 2,
                                    graphSize.width, 
                                    textRectHeight * 2);
    
    // Clear the background
    [[appSettings graphBGColor] set];
    NSRect bounds = [self bounds];
    CGContextFillRect(gc.CGContext, bounds);
    
    NSMutableDictionary *wrapAttributes = [[appSettings alignLeftAttributes] mutableCopy];
    wrapAttributes[NSParagraphStyleAttributeName] = [wrapAttributes[NSParagraphStyleAttributeName] mutableCopy];
    [wrapAttributes[NSParagraphStyleAttributeName] setLineBreakMode:NSLineBreakByWordWrapping];
    
    // First check if there is battery data to graph.
    if (powerStatus == XRGBatteryStatusNoBattery || powerStatus == XRGBatteryStatusUnknown) {
        [@"No Battery Found" drawInRect:self.bounds withAttributes:wrapAttributes];
        return;
    }

    [gc setShouldAntialias:[appSettings antiAliasing]];
    
    CGFloat currentWatts = self.chargeWatts.currentValue - self.dischargeWatts.currentValue;
    CGFloat maxWatts = MAX(self.chargeWatts.max, self.dischargeWatts.max);
    maxWatts = MAX(maxWatts, 30);
    
    // draw the battery bar
    [[appSettings graphFG1Color] set];
    if (charge) {
        percentRect.size.width = rect.size.width * ((float)currentPercent / 100.);
		
		if ([self shouldDrawMiniGraph]) {
			percentRect.origin.y = self.bounds.origin.y;
			percentRect.size.height = self.bounds.size.height;
		}
		
        NSRectFill(percentRect);
    }
    
    // set graphFG2Color before drawing the triple bar for charging.
    [[appSettings graphFG2Color] set];
    if (powerStatus == XRGBatteryStatusCharging) {
        NSRect chargingRect = NSMakeRect(percentRect.origin.x + percentRect.size.width, 
                                         percentRect.origin.y,
                                         (rect.size.width - percentRect.size.width) * ((float)tripleCount / 3.),
                                         percentRect.size.height);
                                        
        NSRectFill(chargingRect);
    }
    percentRect.size.height = textRectHeight;
    percentRect.origin.y -= percentRect.size.height;
    
	if (![self shouldDrawMiniGraph]) {
        // Draw the watts bar
        percentRect.origin.x = rect.size.width / 2.;
        percentRect.size.width = (rect.size.width / 2.) * (fabs(currentWatts) / maxWatts);
        if (currentWatts < 0) {
            percentRect.origin.x -= percentRect.size.width;
        }
        NSRectFill(percentRect);
        percentRect.origin.x = 0;
		
		// draw the borders
		[[appSettings borderColor] set];
		percentRect.size.width = graphSize.width;
		percentRect.size.height = 2;
		percentRect.origin.y--;
		CGFloat topOfGraph = percentRect.origin.y;
		NSRectFill(percentRect);
		percentRect.origin.y += textRectHeight;
		NSRectFill(percentRect);
		
		// Fill the split bar for the amp graph
		NSRectFill(NSMakeRect((rect.size.width / 2.) - 1., topOfGraph, 2., textRectHeight + 2.));
		
		// Draw the battery capacity graph, only if there is space for it on the graph.
		percentRect.size.width = graphSize.width;
		percentRect.origin.y = 0;
		percentRect.size.height = topOfGraph;
		
        if (percentRect.size.height > 0) {
            [self drawGraphWithDataFromDataSet:self.chargeWatts maxValue:maxWatts inRect:percentRect flipped:NO filled:YES color:[appSettings graphFG1Color]];
            [self drawGraphWithDataFromDataSet:self.dischargeWatts maxValue:maxWatts inRect:percentRect flipped:YES filled:YES color:[appSettings graphFG2Color]];
        }
	}
    [gc setShouldAntialias:YES];

    // Draw the text.
    NSRect textRect = [self paddedTextRect];
    if (current && charge && capacity) {
        NSMutableString *leftS = [[NSMutableString alloc] init];
        NSMutableString *rightS = [[NSMutableString alloc] init];
        NSMutableString *centerS = [[NSMutableString alloc] init];
        BOOL drawCenter = NO;

        // Draw the battery percentage
        if (powerStatus == XRGBatteryStatusCharged) {
            [leftS appendFormat:@"%ld%%", (long)currentPercent];
            if (CHARGED_WIDE <= textRect.size.width)
                [rightS appendFormat:@"Charged"];
            else
                [rightS appendFormat:@"Chgd."];
        }
        else if (powerStatus == XRGBatteryStatusOnHold) {
            [leftS appendFormat:@"%ld%%", (long)currentPercent];
            if (CHARGED_WIDE <= textRect.size.width)
                [rightS appendFormat:@"On Hold"];
            else
                [rightS appendFormat:@"Hold"];
        }
        else if (minutesRemaining > 0) {
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
        else {
            [leftS appendFormat:@"%ld%%", (long)currentPercent];
            if (ESTIMATING_WIDE <= textRect.size.width)
                [rightS appendFormat:@"Estimating Left"];
            else if (ESTIMATING_NORMAL <= textRect.size.width)
                [rightS appendFormat:@"Estimating"];
            else
                [rightS appendFormat:@"Est."];
        }
        
        // Draw the current charge.
        [leftS appendFormat:@"\n%ldmAh", (long)chargeSum];
        [rightS appendFormat:@"\n%ldmAh", (long)capacitySum];
        [centerS appendString:@"\n"];
        
		if (![self shouldDrawMiniGraph]) {
            // Draw the wattage.
            if (POWER_WIDE <= textRect.size.width) {
                [leftS appendString:@"\nPower:"];
                [rightS appendFormat:@"\n%2.1fW", currentWatts];
                [centerS appendString:@"\n "];
            }
            else {
                [leftS appendString:@"\n "];
                [rightS appendString:@"\n "];
                [centerS appendFormat:@"\n%2.1fW", currentWatts];
                drawCenter = YES;
            }
		}
		
        [self drawLeftText:leftS centerText:drawCenter ? centerS : nil rightText:rightS inRect:textRect];
    }
    else {
        [@"No Battery Info Found" drawInRect:NSInsetRect(self.bounds, 3, 0) withAttributes:wrapAttributes];
    }
    
    [gc setShouldAntialias:YES];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Battery View"];
    NSMenuItem *tMI;

    if (@available(macOS 11, *)) {
        tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open Battery System Preferences..." action:@selector(openEnergySaverSystemPreferences:) keyEquivalent:@""];
        [myMenu addItem:tMI];
    }
    else {
        tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open Energy Saver System Preferences..." action:@selector(openEnergySaverSystemPreferences:) keyEquivalent:@""];
        [myMenu addItem:tMI];
    }
    
    return myMenu;
}

- (void)openEnergySaverSystemPreferences:(NSEvent *)theEvent {
    if (@available(macOS 11, *)) {
        [NSTask
          launchedTaskWithLaunchPath:@"/usr/bin/open"
          arguments:@[@"/System/Library/PreferencePanes/Battery.prefPane"]
        ];
    }
    else {
        [NSTask
          launchedTaskWithLaunchPath:@"/usr/bin/open"
          arguments:@[@"/System/Library/PreferencePanes/EnergySaver.prefPane"]
        ];
    }
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

/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2009 Gaucho Software, LLC.
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
//  XRGGraphWindow.m
//

#import "XRGGraphWindow.h"
#import "definitions.h"
#import <stdio.h>
#import <IOKit/IOMessage.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

// sleep/wake notifications
bool systemJustWokeUp;
io_object_t powerConnection;
void sleepNotification(void *refcon, io_service_t service, natural_t messageType, void *messageArgument);

@implementation XRGGraphWindow

///// Initialization Methods /////

+ (void)initialize {
    // first set up the defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:[self getDefaultPrefs]];
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{    
    // Initialize the settings class
    appSettings = [[XRGSettings alloc] init];
    [appSettings initVariables];
    
    // Initialize the module manager class
    moduleManager = [[XRGModuleManager alloc] initWithWindow:self];
    
    // Initialize the font manager
    fontManager = [NSFontManager sharedFontManager];
    
    // Initialize resizing variables
    isResizingTL = isResizingTC = isResizingTR = NO;
    isResizingML = isResizingMR = NO;
    isResizingBL = isResizingBC = isResizingBR = NO;
    
    // Initialize other status variables.
    systemJustWokeUp = NO;
    xrgCheckURL = nil;
    
    // Get the User Defaults object
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];    
    
    // Set variables from the user defaults
    [self setupSettingsFromDictionary:[defs dictionaryRepresentation]];

    // register for sleep/wake notifications
    CFRunLoopSourceRef rls;
    IONotificationPortRef thePortRef;
    io_object_t notifier;

    powerConnection = IORegisterForSystemPower(NULL, &thePortRef, sleepNotification, &notifier );

    if (powerConnection == 0) NSLog(@"Failed to register for sleep/wake events.");

    rls = IONotificationPortGetRunLoopSource(thePortRef);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
    
    if ([appSettings checkForUpdates]) {
        [self checkServerForUpdates];
    }
                
    return parentWindow;
}

+ (NSMutableDictionary *) getDefaultPrefs {
    NSMutableDictionary *appDefs = [NSMutableDictionary dictionary];
    
    [appDefs setObject: @"0.9" forKey:XRG_backgroundTransparency];
    [appDefs setObject: @"0.9" forKey:XRG_graphBGTransparency];
    [appDefs setObject: @"1.0" forKey:XRG_graphFG1Transparency];
    [appDefs setObject: @"1.0" forKey:XRG_graphFG2Transparency];
    [appDefs setObject: @"1.0" forKey:XRG_graphFG3Transparency];
    [appDefs setObject: @"0.4" forKey:XRG_borderTransparency];
    [appDefs setObject: @"1.0" forKey:XRG_textTransparency];
    
    NSColor *c = [NSColor colorWithDeviceRed: 0.0
                                       green: 0.0
                                        blue: 0.0
                                       alpha: 0.9];
    [appDefs setObject:
        [NSArchiver archivedDataWithRootObject: [[c copy] autorelease]]
        forKey: XRG_backgroundColor
    ];
    
    c = [NSColor colorWithDeviceRed: 0.0
                              green: 0.0
                               blue: 0.0
                              alpha: 0.9];
    [appDefs setObject:
        [NSArchiver archivedDataWithRootObject: [[c copy] autorelease]]
        forKey: XRG_graphBGColor
    ];
    
    c = [NSColor colorWithDeviceRed: 0.165
                              green: 0.224
                               blue: 0.773
                              alpha: 1.0];
    [appDefs setObject:
        [NSArchiver archivedDataWithRootObject:[[c copy] autorelease]]
        forKey: XRG_graphFG1Color
    ];
    
    c = [NSColor colorWithDeviceRed: 0.922
                              green: 0.667
                               blue: 0.337
                              alpha: 1.0];
    [appDefs setObject:
        [NSArchiver archivedDataWithRootObject:[[c copy] autorelease]]
        forKey: XRG_graphFG2Color
    ];
    
    c = [NSColor colorWithDeviceRed: 0.690
                              green: 0.102
                               blue: 0.102
                              alpha: 1.0];
    [appDefs setObject:
        [NSArchiver archivedDataWithRootObject:[[c copy] autorelease]]
        forKey: XRG_graphFG3Color
    ];
    
    c = [NSColor colorWithDeviceRed: 0.0
                              green: 0.0
                               blue: 0.0
                              alpha: 0.4];
    [appDefs setObject:
        [NSArchiver archivedDataWithRootObject: [[c copy] autorelease]]
        forKey: XRG_borderColor
    ];
        
    [appDefs setObject: 
        [NSArchiver archivedDataWithRootObject: [NSColor whiteColor]] 
        forKey: XRG_textColor
    ];
    
    [appDefs setObject:[NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Lucida Grande" size:9.0]]
                forKey:XRG_graphFont];
                
    [appDefs setObject: @"YES"  forKey: XRG_antialiasText];
    
    [appDefs setObject: @"140"  forKey: XRG_windowWidth];
    [appDefs setObject: @"700"  forKey: XRG_windowHeight];
	
	NSScreen *mainScreen = [NSScreen mainScreen];
	NSRect screenFrame = [mainScreen frame];
	[appDefs setObject: [NSNumber numberWithInt:screenFrame.origin.x + (0.5 * screenFrame.size.width) - 70]  forKey: XRG_windowOriginX];
    [appDefs setObject: [NSNumber numberWithInt:screenFrame.origin.y + screenFrame.size.height - 50 - 700]   forKey: XRG_windowOriginY];
    
    [appDefs setObject: @"4"    forKey: XRG_borderWidth];
    [appDefs setObject: @"YES"  forKey: XRG_graphOrientationVertical];
    [appDefs setObject: @"YES"  forKey: XRG_antiAliasing];
    [appDefs setObject: @"1.0"  forKey: XRG_graphRefresh];
    [appDefs setObject: @"YES"  forKey: XRG_showCPUGraph];
    [appDefs setObject: @"YES"  forKey: XRG_showMemoryGraph];
    [appDefs setObject: @"YES"  forKey: XRG_showBatteryGraph];
    [appDefs setObject: @"YES"  forKey: XRG_showTemperatureGraph];
    [appDefs setObject: @"YES"  forKey: XRG_showNetworkGraph];
    [appDefs setObject: @"YES"  forKey: XRG_showDiskGraph];
    [appDefs setObject: @"YES"  forKey: XRG_showWeatherGraph];
    [appDefs setObject: @"YES"  forKey: XRG_showStockGraph];
    [appDefs setObject: @"0"	forKey: XRG_windowLevel];
    [appDefs setObject: @"YES"  forKey: XRG_stickyWindow];
    [appDefs setObject: @"YES"  forKey: XRG_checkForUpdates];
    [appDefs setObject: @"NO"   forKey: XRG_dropShadow];
    [appDefs setObject: @""     forKey: XRG_windowLevel];
    [appDefs setObject: @"YES"  forKey: XRG_autoExpandGraph];
    [appDefs setObject: @"NO"   forKey: XRG_foregroundWhenExpanding];
    [appDefs setObject: @"YES"  forKey: XRG_showSummary];
    [appDefs setObject: @""     forKey: XRG_minimizeUpDown];
    
    [appDefs setObject: @"NO"   forKey: XRG_fastCPUUsage];
    [appDefs setObject: @"YES"  forKey: XRG_separateCPUColor];
    [appDefs setObject: @"NO"   forKey: XRG_showCPUTemperature];
    [appDefs setObject: @"0"    forKey: XRG_cpuTemperatureUnits];
    [appDefs setObject: @"YES"  forKey: XRG_showLoadAverage];
    [appDefs setObject: @"YES"  forKey: XRG_cpuShowAverageUsage];
    [appDefs setObject: @"YES"  forKey: XRG_cpuShowUptime];
    
    [appDefs setObject: @"YES"  forKey: XRG_showMemoryPagingGraph];
    [appDefs setObject: @"YES"  forKey: XRG_memoryShowWired];
    [appDefs setObject: @"YES"  forKey: XRG_memoryShowActive];
    [appDefs setObject: @"YES"  forKey: XRG_memoryShowInactive];
    [appDefs setObject: @"YES"  forKey: XRG_memoryShowFree];
    [appDefs setObject: @"YES"  forKey: XRG_memoryShowCache];
    [appDefs setObject: @"YES"  forKey: XRG_memoryShowPage];
    
    [appDefs setObject: @"0"    forKey: XRG_tempUnits];
    [appDefs setObject: @"0"    forKey: XRG_tempFG1Location];
    [appDefs setObject: @"1"    forKey: XRG_tempFG2Location];
    [appDefs setObject: @"2"    forKey: XRG_tempFG3Location];

    [appDefs setObject: @"1024" forKey: XRG_netMinGraphScale];
    [appDefs setObject: @"0"    forKey: XRG_netGraphMode];
    [appDefs setObject: @"YES"  forKey: XRG_showTotalBandwidthSinceBoot];
    [appDefs setObject: @"YES"  forKey: XRG_showTotalBandwidthSinceLoad];
    [appDefs setObject: @"All"  forKey: XRG_networkInterface];

    [appDefs setObject: @"0"    forKey: XRG_diskGraphMode];

    [appDefs setObject: @"KMOP" forKey: XRG_ICAO];
    [appDefs setObject: @"1"    forKey: XRG_secondaryWeatherGraph];
    [appDefs setObject: @"0"    forKey: XRG_temperatureUnits];
    [appDefs setObject: @"0"    forKey: XRG_distanceUnits];
    [appDefs setObject: @"0"    forKey: XRG_pressureUnits];
    
    [appDefs setObject: @"AAPL" forKey: XRG_stockSymbols];
    [appDefs setObject: @"3"    forKey: XRG_stockGraphTimeFrame];
    [appDefs setObject: @"YES"  forKey: XRG_stockShowChange];
    [appDefs setObject: @"YES"  forKey: XRG_showDJIA];

    return appDefs;
}

- (void) setupSettingsFromDictionary:(NSDictionary *) defs {
    [self        setBorderWidth:             [[defs objectForKey:XRG_borderWidth] intValue]];
    [appSettings setAntiAliasing:            [[defs objectForKey:XRG_antiAliasing] boolValue]];
    [appSettings setGraphRefresh:            [[defs objectForKey:XRG_graphRefresh] floatValue]];
    [appSettings setStickyWindow:            [[defs objectForKey:XRG_stickyWindow] boolValue]];
    [appSettings setWindowLevel:             [[defs objectForKey:XRG_windowLevel] intValue]];
    [appSettings setCheckForUpdates:         [[defs objectForKey:XRG_checkForUpdates] boolValue]];
    [appSettings setDropShadow:              [[defs objectForKey:XRG_dropShadow] boolValue]];
    [appSettings setWindowTitle:             [defs objectForKey:XRG_windowTitle]];
    [appSettings setAutoExpandGraph:         [[defs objectForKey:XRG_autoExpandGraph] boolValue]];
    [appSettings setForegroundWhenExpanding: [[defs objectForKey:XRG_foregroundWhenExpanding] boolValue]];
    [appSettings setShowSummary:             [[defs objectForKey:XRG_showSummary] boolValue]];
    [appSettings setMinimizeUpDown:          [[defs objectForKey:XRG_minimizeUpDown] intValue]];

    [appSettings setBackgroundColor:        [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_backgroundColor]]];
    [appSettings setGraphBGColor:           [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_graphBGColor]]];
    [appSettings setGraphFG1Color:          [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_graphFG1Color]]];
    [appSettings setGraphFG2Color:          [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_graphFG2Color]]];
    [appSettings setGraphFG3Color:          [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_graphFG3Color]]];
    [appSettings setBorderColor:            [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_borderColor]]];
    [appSettings setTextColor:              [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_textColor]]];
    [appSettings setGraphFont:              [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_graphFont]]];
    [appSettings setAntialiasText:          [[defs objectForKey:XRG_antialiasText] boolValue]];
    [appSettings setBackgroundTransparency: [[defs objectForKey:XRG_backgroundTransparency] floatValue]];
    [appSettings setGraphBGTransparency:    [[defs objectForKey:XRG_graphBGTransparency] floatValue]];
    [appSettings setGraphFG1Transparency:   [[defs objectForKey:XRG_graphFG1Transparency] floatValue]];
    [appSettings setGraphFG2Transparency:   [[defs objectForKey:XRG_graphFG2Transparency] floatValue]];
    [appSettings setGraphFG3Transparency:   [[defs objectForKey:XRG_graphFG3Transparency] floatValue]];
    [appSettings setBorderTransparency:     [[defs objectForKey:XRG_borderTransparency] floatValue]];
    [appSettings setTextTransparency:       [[defs objectForKey:XRG_textTransparency] floatValue]];

    [appSettings setFastCPUUsage:           [[defs objectForKey:XRG_fastCPUUsage] boolValue]];
    [appSettings setSeparateCPUColor:       [[defs objectForKey:XRG_separateCPUColor] boolValue]];
    [appSettings setShowCPUTemperature:     [[defs objectForKey:XRG_showCPUTemperature] boolValue]];
    [appSettings setCPUTemperatureUnits:    [[defs objectForKey:XRG_cpuTemperatureUnits] intValue]];
    [appSettings setShowLoadAverage:        [[defs objectForKey:XRG_showLoadAverage] boolValue]];
    [appSettings setCPUShowAverageUsage:    [[defs objectForKey:XRG_cpuShowAverageUsage] boolValue]];
    [appSettings setCPUShowUptime:          [[defs objectForKey:XRG_cpuShowUptime] boolValue]];

    [appSettings setICAO:                   [defs objectForKey:XRG_ICAO]];
    [appSettings setSecondaryWeatherGraph:  [[defs objectForKey:XRG_secondaryWeatherGraph] intValue]];
    [appSettings setTemperatureUnits:       [[defs objectForKey:XRG_temperatureUnits] intValue]];
    [appSettings setDistanceUnits:          [[defs objectForKey:XRG_distanceUnits] intValue]];
    [appSettings setPressureUnits:          [[defs objectForKey:XRG_pressureUnits] intValue]];

    [appSettings setShowMemoryPagingGraph:  [[defs objectForKey:XRG_showMemoryPagingGraph] boolValue]];
    [appSettings setMemoryShowWired:        [[defs objectForKey:XRG_memoryShowWired] boolValue]];
    [appSettings setMemoryShowActive:       [[defs objectForKey:XRG_memoryShowActive] boolValue]];
    [appSettings setMemoryShowInactive:     [[defs objectForKey:XRG_memoryShowInactive] boolValue]];
    [appSettings setMemoryShowFree:         [[defs objectForKey:XRG_memoryShowFree] boolValue]];
    [appSettings setMemoryShowCache:        [[defs objectForKey:XRG_memoryShowCache] boolValue]];
    [appSettings setMemoryShowPage:         [[defs objectForKey:XRG_memoryShowPage] boolValue]];
    
    [appSettings setTempUnits:              [[defs objectForKey:XRG_tempUnits] intValue]];
    [appSettings setTempFG1Location:        [[defs objectForKey:XRG_tempFG1Location] intValue]];
    [appSettings setTempFG2Location:        [[defs objectForKey:XRG_tempFG2Location] intValue]];
    [appSettings setTempFG3Location:        [[defs objectForKey:XRG_tempFG3Location] intValue]];

    [appSettings setNetMinGraphScale:            [[defs objectForKey:XRG_netMinGraphScale] intValue]];
    [appSettings setNetGraphMode:                [[defs objectForKey:XRG_netGraphMode] intValue]];
    [appSettings setShowTotalBandwidthSinceBoot: [[defs objectForKey:XRG_showTotalBandwidthSinceBoot] boolValue]];
    [appSettings setShowTotalBandwidthSinceLoad: [[defs objectForKey:XRG_showTotalBandwidthSinceLoad] boolValue]];
    [appSettings setNetworkInterface:            [defs objectForKey:XRG_networkInterface]];

    [appSettings setDiskGraphMode:          [[defs objectForKey:XRG_diskGraphMode] intValue]];

    [appSettings setStockSymbols:           [defs objectForKey: XRG_stockSymbols]];
    [appSettings setStockGraphTimeFrame:    [[defs objectForKey:XRG_stockGraphTimeFrame] intValue]];
    [appSettings setStockShowChange:        [[defs objectForKey:XRG_stockShowChange] boolValue]];
    [appSettings setShowDJIA:               [[defs objectForKey:XRG_showDJIA] boolValue]];
        
    // Set up our window.
    NSRect windowRect = NSMakeRect([[defs objectForKey:XRG_windowOriginX] floatValue], 
                                   [[defs objectForKey:XRG_windowOriginY] floatValue],
                                   [[defs objectForKey:XRG_windowWidth] floatValue], 
                                   [[defs objectForKey:XRG_windowHeight] floatValue]);
    
    //pass in NSBorderlessWindowMask for the styleMask
    parentWindow = [[super initWithContentRect: windowRect 
                                     styleMask: NSBorderlessWindowMask 
                                       backing: NSBackingStoreBuffered  
                                         defer: NO] retain];
                                         
    //Set the background color to clear
    [parentWindow setBackgroundColor: [NSColor clearColor]];

    //set the transparency close to one.
    [parentWindow setAlphaValue: 0.99];

    //turn off opaqueness
    [parentWindow setOpaque: NO];

    [parentWindow useOptimizedDrawing: YES];

    [parentWindow setHasShadow: [appSettings dropShadow]];
    
    // Set these after we have initialized the parentWindow
    [self setMinSize:[moduleManager getMinSize]];
    [moduleManager windowChangedToSize:[self setWindowRect:windowRect].size];
    [self setWindowLevelHelper: [[defs objectForKey:XRG_windowLevel] intValue]];    
        
    [moduleManager setGraphOrientationVertical: [[defs objectForKey:XRG_graphOrientationVertical] boolValue]];
    [self setMinSize:[moduleManager getMinSize]];
}

void sleepNotification(void *refcon, io_service_t service, natural_t messageType, void *messageArgument) {
     switch(messageType) {
        case kIOMessageSystemWillSleep: 
            IOAllowPowerChange(powerConnection, (long) messageArgument);
            break;
        case kIOMessageCanSystemSleep:
            IOAllowPowerChange(powerConnection, (long) messageArgument);
            break;
        case kIOMessageSystemHasPoweredOn:
            systemJustWokeUp = YES;
            break;
     }
} 

- (bool)systemJustWokeUp {
    return systemJustWokeUp;
}

- (void)setSystemJustWokeUp:(bool)yesNo {
    systemJustWokeUp = yesNo;
}

- (void)checkServerForUpdates {
    xrgCheckURL = [[XRGURL alloc] init];
    [xrgCheckURL setURLString:@"http://download.gauchosoft.com/xrg/latest_version.txt"];
    [xrgCheckURL loadURLInBackground];
}

- (void)checkServerForUpdatesPostProcess {
    if (xrgCheckURL == nil) return;
    
    if ([xrgCheckURL didErrorOccur]) {
        [xrgCheckURL release];
        xrgCheckURL = nil;
    }
    
    if ([xrgCheckURL isDataReady]) {
		NSString *myVersion = (NSString *)CFBundleGetValueForInfoDictionaryKey(CFBundleGetMainBundle(), CFSTR("CFBundleVersion"));
		NSString *s = [[[NSString alloc] initWithData:[xrgCheckURL getData] encoding:NSASCIIStringEncoding] autorelease];
        s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		if ([self isVersion:s laterThanVersion:myVersion]) {
			NSString *mesg = [NSString stringWithFormat:@"XRG %@ is now available.  You are currently running XRG %@.  If you would like visit the XRG website to upgrade, click More Info.", s, myVersion];
			
            int buttonClicked;
            buttonClicked = NSRunInformationalAlertPanel(@"Alert", mesg, @"More Info", @"Disable Checking", @"Not Yet");
            
            switch(buttonClicked) {
                case -1:		// Not Yet
                    // don't do anything here
                    break;
                case 0:			// Disable Checking
                    [appSettings setCheckForUpdates:NO];
                    // save it to the user defaults
                    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
                    [defs setObject: @"NO"  forKey:XRG_checkForUpdates];
                    [defs synchronize];
                    break;
                case 1:			// More Info
                    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.gauchosoft.com/xrg/"]];
                    break;
            }
        }
        
        [xrgCheckURL release];
        xrgCheckURL = nil;
    }
}

- (bool)isVersion:(NSString *)latestVersion laterThanVersion:(NSString *)currentVersion {
	if ([latestVersion isEqualToString:currentVersion]) {
		return NO;
	}
	else {
		//NSLog(@"Current Version: %@   Latest Version: %@", currentVersion, latestVersion);
		NSArray *latestComponents = [latestVersion componentsSeparatedByString:@"."];
		NSArray *currentComponents = [currentVersion componentsSeparatedByString:@"."];
		
		NSInteger numLatestComponents = [latestComponents count];
		NSInteger numCurrentComponents = [currentComponents count];
		NSInteger numIterationsToDo = 0;
		
		if (numLatestComponents > numCurrentComponents) numIterationsToDo = numCurrentComponents;
		else numIterationsToDo = numLatestComponents;
		
		if (!numIterationsToDo) return NO;
		
		NSInteger i;
		for (i = 0; i < numIterationsToDo; i++) {
			NSUInteger latestBLocation = [[latestComponents objectAtIndex:i] rangeOfString:@"b"].location;
			NSUInteger currentBLocation = [[currentComponents objectAtIndex:i] rangeOfString:@"b"].location;

			int latestNumber = 0;
			int currentNumber = 0;
			int latestBetaNumber = 999999;
			int currentBetaNumber = 999999;
			
			if (latestBLocation != NSNotFound) {
				NSArray *tmpArray = [[latestComponents objectAtIndex:i] componentsSeparatedByString:@"b"];
				
				if ([tmpArray count] >= 2) {
					latestNumber = [[tmpArray objectAtIndex:0] intValue];
					latestBetaNumber = [[tmpArray objectAtIndex:1] intValue];
				}
				else if ([tmpArray count] == 1) {
					latestNumber = [[tmpArray objectAtIndex:0] intValue];
				}
				else {
					latestNumber = 0;
				}
			}
			else {
				latestNumber = [[latestComponents objectAtIndex:i] intValue];
			}
			
			if (currentBLocation != NSNotFound) {
				NSArray *tmpArray = [[currentComponents objectAtIndex:i] componentsSeparatedByString:@"b"];
				
				if ([tmpArray count] >= 2) {
					currentNumber = [[tmpArray objectAtIndex:0] intValue];
					currentBetaNumber = [[tmpArray objectAtIndex:1] intValue];
				}
				else if ([tmpArray count] == 1) {
					currentNumber = [[tmpArray objectAtIndex:0] intValue];
				}
				else {
					currentNumber = 0;
				}
			}
			else {
				currentNumber = [[currentComponents objectAtIndex:i] intValue];
			}
			
			// Error checking
			if (latestNumber == INT_MAX | latestNumber == INT_MIN) latestNumber = 0;
			if (currentNumber == INT_MAX | currentNumber == INT_MIN) currentNumber = 0;
			if (latestBetaNumber == INT_MAX | latestBetaNumber == INT_MIN) latestBetaNumber = 0;
			if (currentBetaNumber == INT_MAX | currentBetaNumber == INT_MIN) currentBetaNumber = 0;
			
			// Finally do the comparison for this revision.
			if (latestNumber > currentNumber) {
				//NSLog(@"New Version Available %d > %d (%d, %d | %d, %d)", latestNumber, currentNumber, latestNumber, latestBetaNumber, currentNumber, currentBetaNumber);
				return YES;
			}
			else if (currentNumber > latestNumber) {
				//NSLog(@"Current %d < %d (%d, %d | %d, %d)", latestNumber, currentNumber, latestNumber, latestBetaNumber, currentNumber, currentBetaNumber);
				return NO;
			}
			else if (latestNumber == currentNumber && latestBetaNumber > currentBetaNumber) {
				//NSLog(@"New Version Available %d > %d (%d, %d | %d, %d)", latestBetaNumber, currentBetaNumber, latestNumber, latestBetaNumber, currentNumber, currentBetaNumber);
				return YES;
			}
			else if (latestNumber == currentNumber && latestBetaNumber < currentBetaNumber) {
				//NSLog(@"Current %d < %d (%d, %d | %d, %d)", latestBetaNumber, currentBetaNumber, latestNumber, latestBetaNumber, currentNumber, currentBetaNumber);
				return NO;
			}
			
			// If we get here, then we need to move on to the next sub-version.
			//NSLog(@"Passed (%d, %d | %d, %d)", latestNumber, latestBetaNumber, currentNumber, currentBetaNumber);
		}
		
		if (numLatestComponents > numCurrentComponents) {
			return YES;
		}
		else {
			return NO;
		}
	}
}

- (XRGSettings *)appSettings {
    return appSettings;
}

- (XRGModuleManager *)moduleManager {
    return moduleManager;
}

- (XRGAppDelegate *)controller {
    return controller;
}

- (void)setController:(XRGAppDelegate *)c {
    if (controller) {
        [controller autorelease];
    }
    
    controller = [c retain];
}

///// End of Initialization Methods /////


///// Timer Methods /////

- (void)initTimers {
    if (!min30Timer) {
        min30Timer = [NSTimer scheduledTimerWithTimeInterval: 1800.0
                                                      target: self
                                                    selector: @selector(min30Update:)
                                                    userInfo: nil
                                                     repeats: YES];
    }
    if (!min5Timer) {
        min5Timer = [NSTimer scheduledTimerWithTimeInterval: 300.0
                                                     target: self
                                                   selector: @selector(min5Update:)
                                                   userInfo: nil
                                                    repeats: YES];
    }
    if (!graphTimer) {
        graphTimer = [NSTimer scheduledTimerWithTimeInterval: [appSettings graphRefresh] 
                                                      target: self 
                                                    selector: @selector(graphUpdate:) 
                                                    userInfo: nil 
                                                     repeats: YES];
    }
    if (!fastTimer) {
		fastTimer = [NSTimer scheduledTimerWithTimeInterval: 0.2
													 target: self
												   selector: @selector(fastUpdate:)
												   userInfo: nil
													repeats: YES];
    }
}

- (void)min30Update:(NSTimer *)aTimer {
    [moduleManager min30Update];
}

- (void)min5Update:(NSTimer *)aTimer {
    [moduleManager min5Update];
}

- (void)graphUpdate:(NSTimer *)aTimer {
    [moduleManager graphUpdate];
    
    if (xrgCheckURL != nil) {
        [self checkServerForUpdatesPostProcess];
    }
}

- (void)fastUpdate:(NSTimer *)aTimer {
    [moduleManager fastUpdate];
}

///// End of Timer Methods /////


///// Methods that set up module references /////

- (void)setCPUView:(XRGCPUView *)cpuO {
    cpuView = [cpuO retain];
}

- (void)setMemoryView:(XRGMemoryView *)memoryO {
    memoryView = [memoryO retain];
}

- (void)setBatteryView:(XRGBatteryView *)batteryO {
    batteryView = [batteryO retain];
}

- (void)setTemperatureView:(XRGTemperatureView *)temperatureO {
    temperatureView = [temperatureO retain];
}

- (void)setTemperatureMiner:(XRGTemperatureMiner *)temperatureM {
    temperatureMiner = [temperatureM retain];
}

- (void)setNetView:(XRGNetView *)netO {
    netView = [netO retain];
}

- (void)setDiskView:(XRGDiskView *)diskO {
    diskView = [diskO retain];
}

- (void)setWeatherView:(XRGWeatherView *)weatherO {
    weatherView = [weatherO retain];
}

- (void)setStockView:(XRGStockView *)stockO {
    stockView = [stockO retain];
}

- (void)setBackgroundView:(XRGBackgroundView *)background0 {
    [background0 setFrameSize: [self frame].size];
    [background0 setAutoresizesSubviews:YES];
    [background0 setNeedsDisplay:YES];
    backgroundView = background0;
    
    // Little hack to fix initial ghosting problem caused by drop shadows in Panther.
    [parentWindow setHasShadow: [appSettings dropShadow]];
}

///// End of methods that set up module references /////


///// Methods that return module references /////

- (XRGCPUView *)cpuView {
    return cpuView;
}

- (XRGMemoryView *)memoryView {
    return memoryView;
}

- (XRGBatteryView *)batteryView {
    return batteryView;
}

- (XRGTemperatureView *)temperatureView {
    return temperatureView;
}

- (XRGTemperatureMiner *)temperatureMiner {
    return temperatureMiner;
}

- (XRGNetView *)netView {
    return netView;
}

- (XRGDiskView *)diskView {
    return diskView;
}

- (XRGWeatherView *)weatherView {
    return weatherView;
}

- (XRGStockView *)stockView {
    return stockView;
}

- (XRGBackgroundView *)backgroundView {
    return backgroundView;
}

///// End of methods that return module references /////


///// Action Methods /////

- (IBAction)setShowCPUGraph:(id)sender {
    [backgroundView expandWindow];
    [moduleManager setModule:@"CPU" isDisplayed:([sender state] == NSOnState)];
    [moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowMemoryGraph:(id)sender {
    [backgroundView expandWindow];
    [moduleManager setModule:@"Memory" isDisplayed:([sender state] == NSOnState)];
    [moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowBatteryGraph:(id)sender {
    [backgroundView expandWindow];
    [moduleManager setModule:@"Battery" isDisplayed:([sender state] == NSOnState)];
    [moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowTemperatureGraph:(id)sender {
    [backgroundView expandWindow];
    [moduleManager setModule:@"Temperature" isDisplayed:([sender state] == NSOnState)];
    [moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowNetGraph:(id)sender {    
    [backgroundView expandWindow];
    [moduleManager setModule:@"Network" isDisplayed:([sender state] == NSOnState)];
    [moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowDiskGraph:(id)sender {
    [backgroundView expandWindow];
    [moduleManager setModule:@"Disk" isDisplayed:([sender state] == NSOnState)];
    [moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowWeatherGraph:(id)sender {
    [backgroundView expandWindow];
    [moduleManager setModule:@"Weather" isDisplayed:([sender state] == NSOnState)];
    [moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowStockGraph:(id)sender {
    [backgroundView expandWindow];
    [moduleManager setModule:@"Stock" isDisplayed:([sender state] == NSOnState)];
    [moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setWindowTitle:(id)sender {
    [appSettings setWindowTitle:[sender stringValue]];
    [backgroundView setNeedsDisplay:YES];
}

- (IBAction)setBorderWidthAction:(id)sender {
    [backgroundView expandWindow];
    [self setBorderWidth: [sender intValue]];
    [moduleManager windowChangedToSize:[parentWindow frame].size];
    [self setMinSize:[moduleManager getMinSize]];
}

- (IBAction)setGraphOrientation:(id)sender {
    bool wasMinimized = [self minimized];
    if (backgroundView && wasMinimized) {
        [backgroundView expandWindow];
    }

    bool graphCurrentlyVertical = [moduleManager graphOrientationVertical];
    if ([sender indexOfSelectedItem] == 0) {
        // the user selected vertical
        [moduleManager setGraphOrientationVertical: YES];
    }
    else if ([sender indexOfSelectedItem] == 1) {
        // the user selected horizontal
        [moduleManager setGraphOrientationVertical: NO];
    }
    
    if (graphCurrentlyVertical != [moduleManager graphOrientationVertical]) {        
        NSRect tmpRect = NSMakeRect([parentWindow frame].origin.x, [parentWindow frame].origin.y, [parentWindow frame].size.height, [parentWindow frame].size.width);
        [self setMinSize:[moduleManager getMinSize]];
        [self setWindowRect:tmpRect];
	}
    
    // minimize view again if it was originally.
    if (backgroundView && wasMinimized) {
        [backgroundView minimizeWindow];
    }
    
    // We need to save this parameter right away.
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    if ([sender indexOfSelectedItem] == 0)
        [defs setObject: @"YES" forKey:XRG_graphOrientationVertical];
    else 
        [defs setObject: @"NO"  forKey:XRG_graphOrientationVertical];
    
    [defs synchronize];
}

- (IBAction)setAntiAliasing:(id)sender {
    if ([sender state] == NSOnState) 
        [appSettings setAntiAliasing: YES];
    else
        [appSettings setAntiAliasing: NO];
}

- (IBAction)setGraphRefreshActionPart2:(id)sender {
    float f = [sender floatValue];
	f = roundf(f * 5.) * 0.2;
    [appSettings setGraphRefresh:f];
    
    [graphTimer invalidate];    
    graphTimer = [NSTimer scheduledTimerWithTimeInterval: f
                                                  target: self
                                                selector: @selector(graphUpdate:)
                                                userInfo: nil
                                                 repeats: YES];
}

- (IBAction)setWindowLevel:(id)sender {
    int index = [sender indexOfSelectedItem] - 1;

    [self setWindowLevelHelper: index];

    [appSettings setWindowLevel: index];
}


- (IBAction)setStickyWindow:(id)sender {
    [appSettings setStickyWindow:([sender state] == NSOnState)];
}

- (IBAction)setCheckForUpdates:(id)sender {
    [appSettings setCheckForUpdates:([sender state] == NSOnState)];
}

- (IBAction)setDropShadow:(id)sender {
    [parentWindow setHasShadow:([sender state] == NSOnState)];
    [appSettings setDropShadow:([sender state] == NSOnState)];
}

- (IBAction)setAutoExpandGraph:(id)sender {
    [appSettings setAutoExpandGraph:([sender state] == NSOnState)];
}

- (IBAction)setForegroundWhenExpanding:(id)sender {
    [appSettings setForegroundWhenExpanding:([sender state] == NSOnState)];
}

- (IBAction)setShowSummary:(id)sender {
    [appSettings setShowSummary:([sender state] == NSOnState)];
}

- (IBAction)setMinimizeUpDown:(id)sender {
    [appSettings setMinimizeUpDown:[sender indexOfSelectedItem]];
}

- (IBAction)setAntialiasText:(id)sender {
    [appSettings setAntialiasText:([sender state] == NSOnState)];
    
    [[self contentView] setNeedsDisplay:YES];
}

- (IBAction)setShowTotalBandwidthSinceBoot:(id)sender {
    [appSettings setShowTotalBandwidthSinceBoot:([sender state] == NSOnState)];
}

- (IBAction)setShowTotalBandwidthSinceLoad:(id)sender {
    [appSettings setShowTotalBandwidthSinceLoad:([sender state] == NSOnState)];
}

- (IBAction)setObjectsToColor:(id)sender {
    switch ([sender tag]) {
        case 21: [appSettings setBackgroundColor: [sender color]]; break;
        case 22: [appSettings setGraphBGColor:    [sender color]]; break;
        case 23: [appSettings setGraphFG1Color:   [sender color]]; break;
        case 24: [appSettings setGraphFG2Color:   [sender color]]; break;
        case 25: [appSettings setGraphFG3Color:   [sender color]]; break;
        case 26: [appSettings setBorderColor:     [sender color]]; break;
        case 27: [appSettings setTextColor:       [sender color]]; break;
    }
    [self redrawWindow];
}

- (void)setObjectsToTransparency:(id) sender {
    switch([sender tag]) {
        case 21: [appSettings setBackgroundTransparency: [sender floatValue]]; break;
        case 22: [appSettings setGraphBGTransparency:    [sender floatValue]]; break;
        case 23: [appSettings setGraphFG1Transparency:   [sender floatValue]]; break;
        case 24: [appSettings setGraphFG2Transparency:   [sender floatValue]]; break;
        case 25: [appSettings setGraphFG3Transparency:   [sender floatValue]]; break;
        case 26: [appSettings setBorderTransparency:     [sender floatValue]]; break;
        case 27: [appSettings setTextTransparency:       [sender floatValue]]; break;
    }
    [self redrawWindow];   
}

- (IBAction)setFastCPUUsageCheckbox:(id)sender {
    if ([sender state] == NSOnState) {
        [appSettings setFastCPUUsage: YES];
//        if (!fastTimer) {
//            fastTimer = [NSTimer scheduledTimerWithTimeInterval: 0.2
//                                 target: self
//                                 selector: @selector(fastUpdate:)
//                                 userInfo: nil
//                                 repeats: YES];
//        }
    }
    else {
        [appSettings setFastCPUUsage: NO];
//        if (fastTimer) {
//            [fastTimer invalidate];
//            fastTimer = nil;
//        }
    }
        
    [cpuView setWidth:[[moduleManager getModuleByName:@"CPU"] currentSize].width];
    [cpuView setNeedsDisplay:YES];
}

- (IBAction)setSeparateCPUColor:(id)sender {
    if ([sender state] == NSOnState) 
        [appSettings setSeparateCPUColor: YES];
    else
        [appSettings setSeparateCPUColor: NO];
}

- (IBAction)setShowCPUTemperature:(id)sender {
    if ([sender state] == NSOnState) 
        [appSettings setShowCPUTemperature: YES];
    else
        [appSettings setShowCPUTemperature: NO];
}

- (IBAction)setCPUTemperatureUnits:(id)sender {
    [appSettings setCPUTemperatureUnits:[sender indexOfSelectedItem]];
}

- (IBAction)setShowLoadAverage:(id)sender {
    [appSettings setShowLoadAverage:([sender state] == NSOnState)];
    
    [cpuView graphUpdate:nil];
}

- (IBAction)setCPUShowAverageUsage:(id)sender {
    [appSettings setCPUShowAverageUsage:([sender state] == NSOnState)];
    
    [cpuView graphUpdate:nil];
}

- (IBAction)setCPUShowUptime:(id)sender {
    [appSettings setCPUShowUptime:([sender state] == NSOnState)];
    
    [cpuView graphUpdate:nil];
}

- (IBAction)setMemoryCheckbox:(id)sender {
    switch ([sender tag]) {
        case 42:
            [appSettings setMemoryShowWired:([sender state] == NSOnState)];
            break;
        case 43:
            [appSettings setMemoryShowActive:([sender state] == NSOnState)];
            break;
        case 44:
            [appSettings setMemoryShowInactive:([sender state] == NSOnState)];
            break;
        case 45:
            [appSettings setMemoryShowFree:([sender state] == NSOnState)];
            break;
        case 46:
            [appSettings setMemoryShowCache:([sender state] == NSOnState)];
            break;
        case 47:
            [appSettings setMemoryShowPage:([sender state] == NSOnState)];
            break;
        case 48:
            [appSettings setShowMemoryPagingGraph:([sender state] == NSOnState)];
            break;
    }
    
    [memoryView setNeedsDisplay:YES];
}

- (IBAction)setTempUnits:(id)sender {
    [appSettings setTempUnits: [sender indexOfSelectedItem]];
    [temperatureView setNeedsDisplay:YES];
}

- (IBAction)setTempFG1Location:(id)sender {
    [appSettings setTempFG1Location:[sender indexOfSelectedItem]];
    [temperatureView setNeedsDisplay:YES];
}

- (IBAction)setTempFG2Location:(id)sender {
    [appSettings setTempFG2Location:[sender indexOfSelectedItem]];
    [temperatureView setNeedsDisplay:YES];
}

- (IBAction)setTempFG3Location:(id)sender {
    [appSettings setTempFG3Location:[sender indexOfSelectedItem]];
    [temperatureView setNeedsDisplay:YES];
}

- (IBAction)setNetGraphMode:(id)sender {
    [appSettings setNetGraphMode:[sender selectedRow]];
    [netView setNeedsDisplay:YES];
}

- (IBAction)setNetworkInterface:(id)sender {
    int selectedRow = [sender indexOfSelectedItem];
    if (selectedRow == 0) {
        [appSettings setNetworkInterface:@"All"];
    }
    else {
        NSArray *interfaces = [netView networkInterfaces];
        if (selectedRow - 1 < [interfaces count])
            [appSettings setNetworkInterface:[interfaces objectAtIndex:(selectedRow - 1)]];
        else
            [appSettings setNetworkInterface:@"All"];
    }
}

- (IBAction)setDiskGraphMode:(id)sender {
    [appSettings setDiskGraphMode:[sender selectedRow]];
    [diskView setNeedsDisplay:YES];
}

- (IBAction)setICAO:(id)sender {
    [appSettings setICAO:[sender stringValue]];

    [weatherView setURL: [appSettings ICAO]];
    [weatherView min30Update:nil];
}

- (IBAction)setSecondaryWeatherGraph:(id)sender {
    [appSettings setSecondaryWeatherGraph: [sender indexOfSelectedItem]];
    [weatherView setNeedsDisplay:YES];
}

- (IBAction)setTemperatureUnits:(id)sender {
    [appSettings setTemperatureUnits: [sender indexOfSelectedItem]];
    [weatherView setNeedsDisplay:YES];
}

- (IBAction)setDistanceUnits:(id)sender {
    [appSettings setDistanceUnits: [sender indexOfSelectedItem]];
    [weatherView setNeedsDisplay:YES];
}

- (IBAction)setPressureUnits:(id)sender {
    [appSettings setPressureUnits: [sender indexOfSelectedItem]];
    [weatherView setNeedsDisplay:YES];
}

- (IBAction)setStockSymbols:(id)sender {
    [appSettings setStockSymbols:[sender stringValue]];
    
    [stockView setStockSymbolsFromString:[sender stringValue]];
}

- (IBAction)setStockGraphTimeFrame:(id)sender {
    [appSettings setStockGraphTimeFrame:[sender indexOfSelectedItem]];
    [stockView setNeedsDisplay:YES];
}

- (IBAction)setStockShowChange:(id)sender {
    [appSettings setStockShowChange:([sender state] == NSOnState)];
    [stockView setNeedsDisplay:YES];
}

- (IBAction)setShowDJIA:(id)sender {
    [appSettings setShowDJIA:([sender state] == NSOnState)];
    [stockView setNeedsDisplay:YES];
}


///// End of Action Methods /////


///// Action Helpers /////

- (void)setWindowLevelHelper:(int)index
{
    if (index == 0)
    {
        [self setLevel:NSNormalWindowLevel];
    }
    else if (index == 1)
    {
        [self setLevel:NSFloatingWindowLevel];
    }
    else {
        [self setLevel:kCGDesktopWindowLevel];
    }
}

- (NSColor *)colorForTag:(int)aTag {
    switch (aTag) {
        case 21:  return [appSettings backgroundColor];
        case 22:  return [appSettings graphBGColor];
        case 23:  return [appSettings graphFG1Color];
        case 24:  return [appSettings graphFG2Color];
        case 25:  return [appSettings graphFG3Color];
        case 26:  return [appSettings borderColor];
        case 27:  return [appSettings textColor];
    }
    
    return nil;
}

- (float)transparencyForTag:(int)aTag {
    switch (aTag) {
        case 21: return [appSettings backgroundTransparency];
        case 22: return [appSettings graphBGTransparency];
        case 23: return [appSettings graphFG1Transparency];
        case 24: return [appSettings graphFG2Transparency];
        case 25: return [appSettings graphFG3Transparency];
        case 26: return [appSettings borderTransparency];
        case 27: return [appSettings textTransparency];
    }
    
    return 1.0;
}

- (void)setWindowSize:(NSSize)newSize {
    NSRect tmpRect = NSMakeRect([self frame].origin.x,
                                [self frame].origin.y,
                                newSize.width,
                                newSize.height);
    [self setMinSize:[moduleManager getMinSize]];
    [moduleManager windowChangedToSize:[self setWindowRect:tmpRect].size];
}

- (void)checkWindowSize {
    NSSize smallSizeLimit = [moduleManager getMinSize];
    NSSize newSize = [self frame].size;
    if (newSize.width < smallSizeLimit.width || newSize.height < smallSizeLimit.height) {
        [self setMinSize:[moduleManager getMinSize]];
        [moduleManager windowChangedToSize:[self setWindowRect:[self frame]].size];
    }
}

///// End of Action Helpers /////


///// Event Handlers /////

// Custom windows that use the NSBorderlessWindowMask can't become key by default.
- (BOOL) canBecomeKeyWindow {
    return YES;
}

- (void)becomeKeyWindow {
    [super becomeKeyWindow];
}

- (void)performClose:(id)sender {
    if([[self delegate] windowShouldClose: self])
        [self close];
}

- (void)performMiniaturize:(id)sender {
    [self miniaturize: nil];
}

- (void)windowDidResize:(NSNotification *)aNotification {
    if (moduleManager)
        [moduleManager windowChangedToSize:[self frame].size];
//    if (backgroundView)
//        [backgroundView updateTrackingRects];
}

- (void)cleanupBeforeExiting {
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	BOOL wasMinimized = [defs boolForKey:XRG_windowIsMinimized];
    if (backgroundView != nil)
        [backgroundView expandWindow];
	[defs setBool:wasMinimized forKey:XRG_windowIsMinimized];

    // Save the window size and location.
    [defs setFloat: [self frame].size.width  forKey:XRG_windowWidth];
    [defs setFloat: [self frame].size.height forKey:XRG_windowHeight];
    [defs setFloat: [self frame].origin.x    forKey:XRG_windowOriginX];
    [defs setFloat: [self frame].origin.y    forKey:XRG_windowOriginY];
    [defs synchronize];
}


- (void)mouseDown:(NSEvent *)theEvent {
    // This is to fix a bug in Cocoa where if the mouse is double-clicked causing 
    // a window move/resize, and double clicked again, the content view does not 
    // get the mouseDown.  In the content view, there is a check so the code doesn't 
    // start looping (the content view mouseDown calls [self mouseDown])
    [backgroundView mouseDownAction:theEvent];
    [super mouseDown:theEvent];
}


///// End of Event Handlers /////

@end

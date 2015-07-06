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
@synthesize appSettings, moduleManager, cpuView, gpuView, netView, diskView, memoryView, weatherView, stockView, batteryView, temperatureView, temperatureMiner, backgroundView;

///// Initialization Methods /////

+ (void)initialize {
    // first set up the defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:[self getDefaultPrefs]];
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	// Initialize the settings class
	self.appSettings = [[[XRGSettings alloc] init] autorelease];
	
	// Initialize the module manager class
	self.moduleManager = [[[XRGModuleManager alloc] initWithWindow:self] autorelease];
	
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
	
	if ([self.appSettings checkForUpdates]) {
		[self checkServerForUpdates];
	}
	
    return parentWindow;
}

- (void) dealloc {
	[appSettings release];
	[moduleManager release];
	
	[cpuView release];
	[netView release];
	[diskView release];
	[memoryView release];
	[weatherView release];
	[stockView release];
	[batteryView release];
	[gpuView release];
	[temperatureView release];
	[temperatureMiner release];
	[backgroundView release];
	
	[super dealloc];
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
	[appDefs setObject: @"YES"  forKey: XRG_showGPUGraph];
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
    [self.appSettings setAntiAliasing:            [[defs objectForKey:XRG_antiAliasing] boolValue]];
    [self.appSettings setGraphRefresh:            [[defs objectForKey:XRG_graphRefresh] floatValue]];
    [self.appSettings setStickyWindow:            [[defs objectForKey:XRG_stickyWindow] boolValue]];
    [self.appSettings setWindowLevel:             [[defs objectForKey:XRG_windowLevel] intValue]];
    [self.appSettings setCheckForUpdates:         [[defs objectForKey:XRG_checkForUpdates] boolValue]];
    [self.appSettings setDropShadow:              [[defs objectForKey:XRG_dropShadow] boolValue]];
    [self.appSettings setWindowTitle:             [defs objectForKey:XRG_windowTitle]];
    [self.appSettings setAutoExpandGraph:         [[defs objectForKey:XRG_autoExpandGraph] boolValue]];
    [self.appSettings setForegroundWhenExpanding: [[defs objectForKey:XRG_foregroundWhenExpanding] boolValue]];
    [self.appSettings setShowSummary:             [[defs objectForKey:XRG_showSummary] boolValue]];
    [self.appSettings setMinimizeUpDown:          [[defs objectForKey:XRG_minimizeUpDown] intValue]];

    [self.appSettings setBackgroundColor:        [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_backgroundColor]]];
    [self.appSettings setGraphBGColor:           [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_graphBGColor]]];
    [self.appSettings setGraphFG1Color:          [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_graphFG1Color]]];
    [self.appSettings setGraphFG2Color:          [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_graphFG2Color]]];
    [self.appSettings setGraphFG3Color:          [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_graphFG3Color]]];
    [self.appSettings setBorderColor:            [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_borderColor]]];
    [self.appSettings setTextColor:              [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_textColor]]];
    [self.appSettings setGraphFont:              [NSUnarchiver unarchiveObjectWithData: [defs objectForKey:XRG_graphFont]]];
    [self.appSettings setAntialiasText:          [[defs objectForKey:XRG_antialiasText] boolValue]];
    [self.appSettings setBackgroundTransparency: [[defs objectForKey:XRG_backgroundTransparency] floatValue]];
    [self.appSettings setGraphBGTransparency:    [[defs objectForKey:XRG_graphBGTransparency] floatValue]];
    [self.appSettings setGraphFG1Transparency:   [[defs objectForKey:XRG_graphFG1Transparency] floatValue]];
    [self.appSettings setGraphFG2Transparency:   [[defs objectForKey:XRG_graphFG2Transparency] floatValue]];
    [self.appSettings setGraphFG3Transparency:   [[defs objectForKey:XRG_graphFG3Transparency] floatValue]];
    [self.appSettings setBorderTransparency:     [[defs objectForKey:XRG_borderTransparency] floatValue]];
    [self.appSettings setTextTransparency:       [[defs objectForKey:XRG_textTransparency] floatValue]];

    [self.appSettings setFastCPUUsage:           [[defs objectForKey:XRG_fastCPUUsage] boolValue]];
    [self.appSettings setSeparateCPUColor:       [[defs objectForKey:XRG_separateCPUColor] boolValue]];
    [self.appSettings setShowCPUTemperature:     [[defs objectForKey:XRG_showCPUTemperature] boolValue]];
    [self.appSettings setCpuTemperatureUnits:    [[defs objectForKey:XRG_cpuTemperatureUnits] intValue]];
    [self.appSettings setShowLoadAverage:        [[defs objectForKey:XRG_showLoadAverage] boolValue]];
    [self.appSettings setCpuShowAverageUsage:    [[defs objectForKey:XRG_cpuShowAverageUsage] boolValue]];
    [self.appSettings setCpuShowUptime:          [[defs objectForKey:XRG_cpuShowUptime] boolValue]];

    [self.appSettings setICAO:                   [defs objectForKey:XRG_ICAO]];
    [self.appSettings setSecondaryWeatherGraph:  [[defs objectForKey:XRG_secondaryWeatherGraph] intValue]];
    [self.appSettings setTemperatureUnits:       [[defs objectForKey:XRG_temperatureUnits] intValue]];
    [self.appSettings setDistanceUnits:          [[defs objectForKey:XRG_distanceUnits] intValue]];
    [self.appSettings setPressureUnits:          [[defs objectForKey:XRG_pressureUnits] intValue]];

    [self.appSettings setShowMemoryPagingGraph:  [[defs objectForKey:XRG_showMemoryPagingGraph] boolValue]];
    [self.appSettings setMemoryShowWired:        [[defs objectForKey:XRG_memoryShowWired] boolValue]];
    [self.appSettings setMemoryShowActive:       [[defs objectForKey:XRG_memoryShowActive] boolValue]];
    [self.appSettings setMemoryShowInactive:     [[defs objectForKey:XRG_memoryShowInactive] boolValue]];
    [self.appSettings setMemoryShowFree:         [[defs objectForKey:XRG_memoryShowFree] boolValue]];
    [self.appSettings setMemoryShowCache:        [[defs objectForKey:XRG_memoryShowCache] boolValue]];
    [self.appSettings setMemoryShowPage:         [[defs objectForKey:XRG_memoryShowPage] boolValue]];
    
    [self.appSettings setTempUnits:              [[defs objectForKey:XRG_tempUnits] intValue]];
    [self.appSettings setTempFG1Location:        [[defs objectForKey:XRG_tempFG1Location] intValue]];
    [self.appSettings setTempFG2Location:        [[defs objectForKey:XRG_tempFG2Location] intValue]];
    [self.appSettings setTempFG3Location:        [[defs objectForKey:XRG_tempFG3Location] intValue]];

    [self.appSettings setNetMinGraphScale:            [[defs objectForKey:XRG_netMinGraphScale] intValue]];
    [self.appSettings setNetGraphMode:                [[defs objectForKey:XRG_netGraphMode] intValue]];
    [self.appSettings setShowTotalBandwidthSinceBoot: [[defs objectForKey:XRG_showTotalBandwidthSinceBoot] boolValue]];
    [self.appSettings setShowTotalBandwidthSinceLoad: [[defs objectForKey:XRG_showTotalBandwidthSinceLoad] boolValue]];
    [self.appSettings setNetworkInterface:            [defs objectForKey:XRG_networkInterface]];

    [self.appSettings setDiskGraphMode:          [[defs objectForKey:XRG_diskGraphMode] intValue]];

    [self.appSettings setStockSymbols:           [defs objectForKey: XRG_stockSymbols]];
    [self.appSettings setStockGraphTimeFrame:    [[defs objectForKey:XRG_stockGraphTimeFrame] intValue]];
    [self.appSettings setStockShowChange:        [[defs objectForKey:XRG_stockShowChange] boolValue]];
    [self.appSettings setShowDJIA:               [[defs objectForKey:XRG_showDJIA] boolValue]];
        
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

    [parentWindow setHasShadow: [self.appSettings dropShadow]];
    
    // Set these after we have initialized the parentWindow
    [self setMinSize:[self.moduleManager getMinSize]];
    [self.moduleManager windowChangedToSize:[self setWindowRect:windowRect].size];
    [self setWindowLevelHelper: [[defs objectForKey:XRG_windowLevel] intValue]];    
        
    [self.moduleManager setGraphOrientationVertical: [[defs objectForKey:XRG_graphOrientationVertical] boolValue]];
    [self setMinSize:[self.moduleManager getMinSize]];
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
			
            NSInteger buttonClicked = NSRunInformationalAlertPanel(@"Alert", mesg, @"More Info", @"Disable Checking", @"Not Yet");
            
            switch(buttonClicked) {
                case -1:		// Not Yet
                    // don't do anything here
                    break;
                case 0:			// Disable Checking
                    [self.appSettings setCheckForUpdates:NO];
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
        graphTimer = [NSTimer scheduledTimerWithTimeInterval: [self.appSettings graphRefresh] 
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
    [self.moduleManager min30Update];
}

- (void)min5Update:(NSTimer *)aTimer {
    [self.moduleManager min5Update];
}

- (void)graphUpdate:(NSTimer *)aTimer {
    [self.moduleManager graphUpdate];
    
    if (xrgCheckURL != nil) {
        [self checkServerForUpdatesPostProcess];
    }
}

- (void)fastUpdate:(NSTimer *)aTimer {
    [self.moduleManager fastUpdate];
}

///// End of Timer Methods /////


///// Methods that set up module references /////
- (void)setBackgroundView:(id)background0 {
    [background0 setFrameSize: [self frame].size];
    [background0 setAutoresizesSubviews:YES];
    [background0 setNeedsDisplay:YES];
    backgroundView = [background0 retain];
    
    // Little hack to fix initial ghosting problem caused by drop shadows in Panther.
    [parentWindow setHasShadow:[self.appSettings dropShadow]];
}
///// End of methods that set up module references /////


///// Action Methods /////

- (IBAction)setShowCPUGraph:(id)sender {
    [self.backgroundView expandWindow];
    [self.moduleManager setModule:@"CPU" isDisplayed:([sender state] == NSOnState)];
    [self.moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowGPUGraph:(id)sender {
	[self.backgroundView expandWindow];
	[self.moduleManager setModule:@"GPU" isDisplayed:([sender state] == NSOnState)];
	[self.moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowMemoryGraph:(id)sender {
    [self.backgroundView expandWindow];
    [self.moduleManager setModule:@"Memory" isDisplayed:([sender state] == NSOnState)];
    [self.moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowBatteryGraph:(id)sender {
    [self.backgroundView expandWindow];
    [self.moduleManager setModule:@"Battery" isDisplayed:([sender state] == NSOnState)];
    [self.moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowTemperatureGraph:(id)sender {
    [self.backgroundView expandWindow];
    [self.moduleManager setModule:@"Temperature" isDisplayed:([sender state] == NSOnState)];
    [self.moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowNetGraph:(id)sender {    
    [self.backgroundView expandWindow];
    [self.moduleManager setModule:@"Network" isDisplayed:([sender state] == NSOnState)];
    [self.moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowDiskGraph:(id)sender {
    [self.backgroundView expandWindow];
    [self.moduleManager setModule:@"Disk" isDisplayed:([sender state] == NSOnState)];
    [self.moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowWeatherGraph:(id)sender {
    [self.backgroundView expandWindow];
    [self.moduleManager setModule:@"Weather" isDisplayed:([sender state] == NSOnState)];
    [self.moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setShowStockGraph:(id)sender {
    [self.backgroundView expandWindow];
    [self.moduleManager setModule:@"Stock" isDisplayed:([sender state] == NSOnState)];
    [self.moduleManager windowChangedToSize:[self frame].size];
}

- (IBAction)setWindowTitle:(id)sender {
    [self.appSettings setWindowTitle:[sender stringValue]];
    [self.backgroundView setNeedsDisplay:YES];
}

- (IBAction)setBorderWidthAction:(id)sender {
    [self.backgroundView expandWindow];
    [self setBorderWidth: [sender intValue]];
    [self.moduleManager windowChangedToSize:[parentWindow frame].size];
    [self setMinSize:[self.moduleManager getMinSize]];
}

- (IBAction)setGraphOrientation:(id)sender {
    bool wasMinimized = [self minimized];
    if (wasMinimized) {
        [self.backgroundView expandWindow];
    }

    bool graphCurrentlyVertical = [self.moduleManager graphOrientationVertical];
	[self.moduleManager setGraphOrientationVertical:([sender indexOfSelectedItem] == 0)];	// 0 = vertical, 1 = horizontal
    
    if (graphCurrentlyVertical != [self.moduleManager graphOrientationVertical]) {        
        NSRect tmpRect = NSMakeRect([parentWindow frame].origin.x, [parentWindow frame].origin.y, [parentWindow frame].size.height, [parentWindow frame].size.width);
        [self setMinSize:[self.moduleManager getMinSize]];
        [self setWindowRect:tmpRect];
	}
    
    // minimize view again if it was originally.
    if (wasMinimized) {
        [self.backgroundView minimizeWindow];
    }
    
    // We need to save this parameter right away.
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	[defs setObject:([sender indexOfSelectedItem] == 0) ? @"YES" : @"NO" forKey:XRG_graphOrientationVertical];    
    [defs synchronize];
}

- (IBAction)setAntiAliasing:(id)sender {
	[self.appSettings setAntiAliasing:([sender state] == NSOnState)];
}

- (IBAction)setGraphRefreshActionPart2:(id)sender {
    float f = [sender floatValue];
	f = roundf(f * 5.) * 0.2;
    [self.appSettings setGraphRefresh:f];
    
    [graphTimer invalidate];    
    graphTimer = [NSTimer scheduledTimerWithTimeInterval: f
                                                  target: self
                                                selector: @selector(graphUpdate:)
                                                userInfo: nil
                                                 repeats: YES];
}

- (IBAction)setWindowLevel:(id)sender {
    NSInteger index = [sender indexOfSelectedItem] - 1;

    [self setWindowLevelHelper: index];

    [self.appSettings setWindowLevel: index];
}


- (IBAction)setStickyWindow:(id)sender {
    [self.appSettings setStickyWindow:([sender state] == NSOnState)];
}

- (IBAction)setCheckForUpdates:(id)sender {
    [self.appSettings setCheckForUpdates:([sender state] == NSOnState)];
}

- (IBAction)setDropShadow:(id)sender {
    [parentWindow setHasShadow:([sender state] == NSOnState)];
    [self.appSettings setDropShadow:([sender state] == NSOnState)];
}

- (IBAction)setAutoExpandGraph:(id)sender {
    [self.appSettings setAutoExpandGraph:([sender state] == NSOnState)];
}

- (IBAction)setForegroundWhenExpanding:(id)sender {
    [self.appSettings setForegroundWhenExpanding:([sender state] == NSOnState)];
}

- (IBAction)setShowSummary:(id)sender {
    [self.appSettings setShowSummary:([sender state] == NSOnState)];
}

- (IBAction)setMinimizeUpDown:(id)sender {
    [self.appSettings setMinimizeUpDown:[sender indexOfSelectedItem]];
}

- (IBAction)setAntialiasText:(id)sender {
    [self.appSettings setAntialiasText:([sender state] == NSOnState)];
    
    [[self contentView] setNeedsDisplay:YES];
}

- (IBAction)setShowTotalBandwidthSinceBoot:(id)sender {
    [self.appSettings setShowTotalBandwidthSinceBoot:([sender state] == NSOnState)];
}

- (IBAction)setShowTotalBandwidthSinceLoad:(id)sender {
    [self.appSettings setShowTotalBandwidthSinceLoad:([sender state] == NSOnState)];
}

- (IBAction)setObjectsToColor:(id)sender {
    switch ([sender tag]) {
        case 21: [self.appSettings setBackgroundColor: [sender color]]; break;
        case 22: [self.appSettings setGraphBGColor:    [sender color]]; break;
        case 23: [self.appSettings setGraphFG1Color:   [sender color]]; break;
        case 24: [self.appSettings setGraphFG2Color:   [sender color]]; break;
        case 25: [self.appSettings setGraphFG3Color:   [sender color]]; break;
        case 26: [self.appSettings setBorderColor:     [sender color]]; break;
        case 27: [self.appSettings setTextColor:       [sender color]]; break;
    }
    [self redrawWindow];
}

- (void)setObjectsToTransparency:(id) sender {
    switch([sender tag]) {
        case 21: [self.appSettings setBackgroundTransparency: [sender floatValue]]; break;
        case 22: [self.appSettings setGraphBGTransparency:    [sender floatValue]]; break;
        case 23: [self.appSettings setGraphFG1Transparency:   [sender floatValue]]; break;
        case 24: [self.appSettings setGraphFG2Transparency:   [sender floatValue]]; break;
        case 25: [self.appSettings setGraphFG3Transparency:   [sender floatValue]]; break;
        case 26: [self.appSettings setBorderTransparency:     [sender floatValue]]; break;
        case 27: [self.appSettings setTextTransparency:       [sender floatValue]]; break;
    }
    [self redrawWindow];   
}

- (IBAction)setFastCPUUsageCheckbox:(id)sender {
	[self.appSettings setFastCPUUsage:([sender state] == NSOnState)];
        
    [self.cpuView setWidth:[[self.moduleManager getModuleByName:@"CPU"] currentSize].width];
    [self.cpuView setNeedsDisplay:YES];
}

- (IBAction)setSeparateCPUColor:(id)sender {
	[self.appSettings setSeparateCPUColor:([sender state] == NSOnState)];
}

- (IBAction)setShowCPUTemperature:(id)sender {
	[self.appSettings setShowCPUTemperature:([sender state] == NSOnState)];
}

- (IBAction)setCPUTemperatureUnits:(id)sender {
    [self.appSettings setCpuTemperatureUnits:[sender indexOfSelectedItem]];
}

- (IBAction)setShowLoadAverage:(id)sender {
    [self.appSettings setShowLoadAverage:([sender state] == NSOnState)];
    
    [self.cpuView graphUpdate:nil];
}

- (IBAction)setCPUShowAverageUsage:(id)sender {
    [self.appSettings setCpuShowAverageUsage:([sender state] == NSOnState)];
    
    [self.cpuView graphUpdate:nil];
}

- (IBAction)setCPUShowUptime:(id)sender {
    [self.appSettings setCpuShowUptime:([sender state] == NSOnState)];
    
    [self.cpuView graphUpdate:nil];
}

- (IBAction)setMemoryCheckbox:(id)sender {
    switch ([sender tag]) {
        case 42:
            [self.appSettings setMemoryShowWired:([sender state] == NSOnState)];
            break;
        case 43:
            [self.appSettings setMemoryShowActive:([sender state] == NSOnState)];
            break;
        case 44:
            [self.appSettings setMemoryShowInactive:([sender state] == NSOnState)];
            break;
        case 45:
            [self.appSettings setMemoryShowFree:([sender state] == NSOnState)];
            break;
        case 46:
            [self.appSettings setMemoryShowCache:([sender state] == NSOnState)];
            break;
        case 47:
            [self.appSettings setMemoryShowPage:([sender state] == NSOnState)];
            break;
        case 48:
            [self.appSettings setShowMemoryPagingGraph:([sender state] == NSOnState)];
            break;
    }
    
    [self.memoryView setNeedsDisplay:YES];
}

- (IBAction)setTempUnits:(id)sender {
    [self.appSettings setTempUnits: [sender indexOfSelectedItem]];
    [self.temperatureView setNeedsDisplay:YES];
}

- (IBAction)setTempFG1Location:(id)sender {
    [self.appSettings setTempFG1Location:[sender indexOfSelectedItem]];
    [self.temperatureView setNeedsDisplay:YES];
}

- (IBAction)setTempFG2Location:(id)sender {
    [self.appSettings setTempFG2Location:[sender indexOfSelectedItem]];
    [self.temperatureView setNeedsDisplay:YES];
}

- (IBAction)setTempFG3Location:(id)sender {
    [self.appSettings setTempFG3Location:[sender indexOfSelectedItem]];
    [self.temperatureView setNeedsDisplay:YES];
}

- (IBAction)setNetGraphMode:(id)sender {
    [self.appSettings setNetGraphMode:[sender selectedRow]];
    [self.netView setNeedsDisplay:YES];
}

- (IBAction)setNetworkInterface:(id)sender {
    NSInteger selectedRow = [sender indexOfSelectedItem];
    if (selectedRow == 0) {
        [self.appSettings setNetworkInterface:@"All"];
    }
    else {
        NSArray *interfaces = [self.netView networkInterfaces];
        if (selectedRow - 1 < [interfaces count])
            [self.appSettings setNetworkInterface:[interfaces objectAtIndex:(selectedRow - 1)]];
        else
            [self.appSettings setNetworkInterface:@"All"];
    }
}

- (IBAction)setDiskGraphMode:(id)sender {
    [self.appSettings setDiskGraphMode:[sender selectedRow]];
    [self.diskView setNeedsDisplay:YES];
}

- (IBAction)setICAO:(id)sender {
    [self.appSettings setICAO:[sender stringValue]];

    [self.weatherView setURL: [self.appSettings ICAO]];
    [self.weatherView min30Update:nil];
}

- (IBAction)setSecondaryWeatherGraph:(id)sender {
    [self.appSettings setSecondaryWeatherGraph: [sender indexOfSelectedItem]];
    [self.weatherView setNeedsDisplay:YES];
}

- (IBAction)setTemperatureUnits:(id)sender {
    [self.appSettings setTemperatureUnits: [sender indexOfSelectedItem]];
    [self.weatherView setNeedsDisplay:YES];
}

- (IBAction)setDistanceUnits:(id)sender {
    [self.appSettings setDistanceUnits: [sender indexOfSelectedItem]];
    [self.weatherView setNeedsDisplay:YES];
}

- (IBAction)setPressureUnits:(id)sender {
    [self.appSettings setPressureUnits: [sender indexOfSelectedItem]];
    [self.weatherView setNeedsDisplay:YES];
}

- (IBAction)setStockSymbols:(id)sender {
    [self.appSettings setStockSymbols:[sender stringValue]];
    
    [self.stockView setStockSymbolsFromString:[sender stringValue]];
}

- (IBAction)setStockGraphTimeFrame:(id)sender {
    [self.appSettings setStockGraphTimeFrame:[sender indexOfSelectedItem]];
    [self.stockView setNeedsDisplay:YES];
}

- (IBAction)setStockShowChange:(id)sender {
    [self.appSettings setStockShowChange:([sender state] == NSOnState)];
    [self.stockView setNeedsDisplay:YES];
}

- (IBAction)setShowDJIA:(id)sender {
    [self.appSettings setShowDJIA:([sender state] == NSOnState)];
    [self.stockView setNeedsDisplay:YES];
}


///// End of Action Methods /////


///// Action Helpers /////

- (void)setWindowLevelHelper:(NSInteger)index
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

- (NSColor *)colorForTag:(NSInteger)aTag {
    switch (aTag) {
        case 21:  return [self.appSettings backgroundColor];
        case 22:  return [self.appSettings graphBGColor];
        case 23:  return [self.appSettings graphFG1Color];
        case 24:  return [self.appSettings graphFG2Color];
        case 25:  return [self.appSettings graphFG3Color];
        case 26:  return [self.appSettings borderColor];
        case 27:  return [self.appSettings textColor];
    }
    
    return nil;
}

- (float)transparencyForTag:(NSInteger)aTag {
    switch (aTag) {
        case 21: return [self.appSettings backgroundTransparency];
        case 22: return [self.appSettings graphBGTransparency];
        case 23: return [self.appSettings graphFG1Transparency];
        case 24: return [self.appSettings graphFG2Transparency];
        case 25: return [self.appSettings graphFG3Transparency];
        case 26: return [self.appSettings borderTransparency];
        case 27: return [self.appSettings textTransparency];
    }
    
    return 1.0;
}

- (void)setWindowSize:(NSSize)newSize {
    NSRect tmpRect = NSMakeRect([self frame].origin.x,
                                [self frame].origin.y,
                                newSize.width,
                                newSize.height);
    [self setMinSize:[self.moduleManager getMinSize]];
    [self.moduleManager windowChangedToSize:[self setWindowRect:tmpRect].size];
}

- (void)checkWindowSize {
    NSSize smallSizeLimit = [self.moduleManager getMinSize];
    NSSize newSize = [self frame].size;
    if (newSize.width < smallSizeLimit.width || newSize.height < smallSizeLimit.height) {
        [self setMinSize:[self.moduleManager getMinSize]];
        [self.moduleManager windowChangedToSize:[self setWindowRect:[self frame]].size];
    }
}

///// End of Action Helpers /////


///// Event Handlers /////

// Custom windows that use the NSBorderlessWindowMask can't become key by default.
- (BOOL) canBecomeKeyWindow {
    return YES;
}

- (void)performClose:(id)sender {
    if([[self delegate] windowShouldClose: self])
        [self close];
}

- (void)performMiniaturize:(id)sender {
    [self miniaturize: nil];
}

- (void)windowDidResize:(NSNotification *)aNotification {
    if (self.moduleManager)
        [self.moduleManager windowChangedToSize:[self frame].size];
}

- (void)cleanupBeforeExiting {
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	BOOL wasMinimized = [defs boolForKey:XRG_windowIsMinimized];
	[self.backgroundView expandWindow];
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
    [self.backgroundView mouseDownAction:theEvent];
    [super mouseDown:theEvent];
}


///// End of Event Handlers /////

@end

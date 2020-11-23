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
//  XRGGraphWindow.h
//

#import <Cocoa/Cocoa.h>
#import "XRGCPUView.h"
#import "XRGNetView.h"
#import "XRGDiskView.h"
#import "XRGMemoryView.h"
#import "XRGWeatherView.h"
#import "XRGStockView.h"
#import "XRGBatteryView.h"
#import "XRGGPUView.h"
#import "XRGTemperatureView.h"
#import "XRGBackgroundView.h"
#import "XRGSettings.h"
#import "XRGModuleManager.h"

@interface XRGGraphWindow : NSWindow

@property int borderWidth;
//@property NSSize minSize;
@property BOOL minimized;

// Timers
@property NSTimer *min30Timer;
@property NSTimer *min5Timer;
@property NSTimer *graphTimer;
@property NSTimer *fastTimer;

// Settings
@property NSFontManager *fontManager;
    
// Outlets
@property IBOutlet id preferenceWindow;
@property IBOutlet XRGAppDelegate *controller;
    
@property XRGURL *xrgCheckURL;

@property XRGSettings *appSettings;
@property XRGModuleManager *moduleManager;

@property XRGCPUView *cpuView;
@property XRGGPUView *gpuView;
@property XRGNetView *netView;
@property XRGDiskView *diskView;
@property XRGMemoryView *memoryView;
@property XRGWeatherView *weatherView;
@property XRGStockView *stockView;
@property XRGBatteryView *batteryView;
@property XRGTemperatureView *temperatureView;
@property (nonatomic) IBOutlet id backgroundView;

@property BOOL draggingWindow;
@property NSPoint originAtDragStart;
@property NSPoint dragStart;

// Initialization
+ (void)initialize;
+ (NSMutableDictionary*)getDefaultPrefs;
- (void)setupSettingsFromDictionary:(NSDictionary *) defs;
- (bool)systemJustWokeUp;
- (void)setSystemJustWokeUp:(bool)yesNo;
- (void)checkServerForUpdates;
- (void)checkServerForUpdatesPostProcess;
- (bool)isVersion:(NSString *)latestVersion laterThanVersion:(NSString *)currentVersion;
- (XRGSettings *)appSettings;
- (XRGModuleManager *)moduleManager;

// Timer methods
- (void)initTimers;
- (void)min30Update:(NSTimer *)aTimer;
- (void)min5Update:(NSTimer *)aTimer;
- (void)graphUpdate:(NSTimer *)aTimer;
- (void)fastUpdate:(NSTimer *)aTimer;

// Methods that set up module references
- (void)setBackgroundView:(id)background;

// Actions
- (IBAction)setShowCPUGraph:(id)sender;
- (IBAction)setShowGPUGraph:(id)sender;
- (IBAction)setShowNetGraph:(id)sender;
- (IBAction)setShowDiskGraph:(id)sender;
- (IBAction)setShowMemoryGraph:(id)sender;
- (IBAction)setShowWeatherGraph:(id)sender;
- (IBAction)setShowStockGraph:(id)sender;
- (IBAction)setShowBatteryGraph:(id)sender;
- (IBAction)setShowTemperatureGraph:(id)sender;
- (IBAction)setBorderWidthAction:(id)sender;
- (IBAction)setGraphOrientation:(id)sender;
- (IBAction)setAntiAliasing:(id)sender;
- (IBAction)setGraphRefreshActionPart2:(id)sender;
- (IBAction)setWindowLevel:(id)sender;
- (IBAction)setStickyWindow:(id)sender;
- (IBAction)setCheckForUpdates:(id)sender;
- (IBAction)setDropShadow:(id)sender;
- (IBAction)setShowTotalBandwidthSinceBoot:(id)sender;
- (IBAction)setShowTotalBandwidthSinceLoad:(id)sender;
- (IBAction)setWindowTitle:(id)sender;
- (IBAction)setAutoExpandGraph:(id)sender;
- (IBAction)setForegroundWhenExpanding:(id)sender;
- (IBAction)setShowSummary:(id)sender;
- (IBAction)setMinimizeUpDown:(id)sender;
- (IBAction)setAntialiasText:(id)sender;

- (IBAction)setObjectsToColor:(id)sender;
- (IBAction)setObjectsToTransparency:(id)sender;

- (IBAction)setFastCPUUsageCheckbox:(id)sender;
- (IBAction)setSeparateCPUColor:(id)sender;
- (IBAction)setShowLoadAverage:(id)sender;
- (IBAction)setShowCPUTemperature:(id)sender;
- (IBAction)setCPUTemperatureUnits:(id)sender;
- (IBAction)setCPUShowAverageUsage:(id)sender;
- (IBAction)setCPUShowUptime:(id)sender;

- (IBAction)setMemoryCheckbox:(id)sender;

- (IBAction)setTempUnits:(id)sender;
- (IBAction)setTempFG1Location:(NSMenuItem *)sender;
- (IBAction)setTempFG2Location:(NSMenuItem *)sender;
- (IBAction)setTempFG3Location:(NSMenuItem *)sender;

- (IBAction)setNetGraphMode:(id)sender;
- (IBAction)setNetworkInterface:(id)sender;

- (IBAction)setDiskGraphMode:(id)sender;

- (IBAction)setICAO:(id)sender;
- (IBAction)setSecondaryWeatherGraph:(id)sender;
- (IBAction)setTemperatureUnits:(id)sender;
- (IBAction)setDistanceUnits:(id)sender;
- (IBAction)setPressureUnits:(id)sender;

- (IBAction)setStockSymbols:(id)sender;
- (IBAction)setStockGraphTimeFrame:(id)sender;
- (IBAction)setStockShowChange:(id)sender;
- (IBAction)setShowDJIA:(id)sender;

// Action helpers
- (void)setWindowLevelHelper:(NSInteger)index;
- (NSColor *)colorForTag:(NSInteger)aTag;
- (float)transparencyForTag:(NSInteger)aTag;
- (void)checkWindowSize;

- (void)cleanupBeforeExiting;

@end

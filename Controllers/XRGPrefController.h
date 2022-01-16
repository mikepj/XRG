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
//  PrefController.h
//

#import <Cocoa/Cocoa.h>
#import "XRGTemperatureMiner.h"

@class XRGGraphWindow;

@interface XRGPrefController : NSObject<NSToolbarDelegate> {
    // toolbar objects
	NSToolbar *toolbar;
    NSMutableDictionary *toolbarItems;
    NSView *currentView;
    IBOutlet NSView *GeneralPrefView;
    IBOutlet NSView *ColorPrefView;
    IBOutlet NSView *CPUPrefView;
    IBOutlet NSView *MemoryPrefView;
    IBOutlet NSView *TemperaturePrefView;
    IBOutlet NSView *NetworkPrefView;
    IBOutlet NSView *DiskPrefView;
    IBOutlet NSView *WeatherPrefView;
    IBOutlet NSView *StockPrefView;

    IBOutlet NSWindow *window;

    IBOutlet id borderWidthSlider;
    IBOutlet id showCPUGraph;
	IBOutlet id showGPUGraph;
    IBOutlet id showMemoryGraph;
    IBOutlet id showBatteryGraph;
    IBOutlet id showTemperatureGraph;
    IBOutlet id showNetGraph;
    IBOutlet id showDiskGraph;
    IBOutlet id showWeatherGraph;
    IBOutlet id showStockGraph;
    IBOutlet id graphOrientation;
    IBOutlet id enableAntiAliasing;
    IBOutlet id graphRefreshValue;
    IBOutlet id graphRefreshText;
    IBOutlet id windowLevel;
    IBOutlet id stickyWindow;
    IBOutlet id checkForUpdates;
    IBOutlet id dropShadow;
    IBOutlet id windowTitle;
    IBOutlet id generalAutoExpandGraph;
    IBOutlet id generalForegroundWhenExpanding;
    IBOutlet id generalShowSummary;
    IBOutlet id generalMinimizeUpDown;

    IBOutlet id backgroundColorWell;
    IBOutlet id backgroundTransparency;
    IBOutlet id graphBGColorWell;
    IBOutlet id graphBGTransparency;
    IBOutlet id graphFG1ColorWell;
    IBOutlet id graphFG1Transparency;
    IBOutlet id graphFG2ColorWell;
    IBOutlet id graphFG2Transparency;
    IBOutlet id graphFG3ColorWell;
    IBOutlet id graphFG3Transparency;
    IBOutlet id borderColorWell;
    IBOutlet id borderTransparency;
    IBOutlet id textColorWell;
    IBOutlet id textTransparency;
    IBOutlet id font;
    IBOutlet id appearanceAntialiasText;
    
    IBOutlet id fastCPUUsageCheckbox;
    IBOutlet id separateCPUColor;
    IBOutlet id showCPUTemperature;
    IBOutlet id cpuTemperatureUnits;
    IBOutlet id cpuShowAverageUsage;
    IBOutlet id showLoadAverage;
    IBOutlet id cpuShowUptime;
    
    IBOutlet id memoryShowWired;
    IBOutlet id memoryShowActive;
    IBOutlet id memoryShowInactive;
    IBOutlet id memoryShowFree;
    IBOutlet id memoryShowCache;
    IBOutlet id memoryShowPage;
    IBOutlet id memoryShowPagingGraph;
    
    IBOutlet id tempUnits;
    IBOutlet NSPopUpButton *tempFG1Location;
    IBOutlet NSPopUpButton *tempFG2Location;
    IBOutlet NSPopUpButton *tempFG3Location;
    
    IBOutlet id networkInterface;
    IBOutlet id netMinGraphScaleUnits;
    IBOutlet id netMinGraphScaleValue;
    IBOutlet id netGraphMode;
    IBOutlet id showTotalBandwidthSinceBoot;
    IBOutlet id showTotalBandwidthSinceLoad;
    
    IBOutlet id diskGraphMode;
    
    IBOutlet id ICAOCode;
    IBOutlet id secondaryWeatherGraph;
    IBOutlet id temperatureUnits;
    IBOutlet id distanceUnits;
    IBOutlet id pressureUnits;
    IBOutlet id weatherStationListLink;
    
    IBOutlet id stockSymbols;
    IBOutlet id stockGraphTimeFrame;
    IBOutlet id stockShowChange;
    IBOutlet id showDJIA;
    
    IBOutlet id hiddenModules;
    IBOutlet id displayedModules;
}

@property (weak) XRGGraphWindow *xrgGraphWindow;
@property NSArray<XRGSensorData *> *temperatureSensors;

- (IBAction)save:(id)sender;
- (IBAction)revert:(id)sender;
- (IBAction)loadTheme:(id)sender;
- (void)loadTheme2:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
- (IBAction)saveTheme:(id)sender;
- (void)saveTheme2:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo;

- (NSWindow *)window;
- (void)setUpGeneralPanel;
- (void)setUpColorPanel;
- (void)setUpCPUPanel;
- (void)setUpMemoryPanel;
- (void)setUpTemperaturePanel;
- (void)setUpNetworkPanel;
- (void)setUpDiskPanel;
- (void)setUpWeatherPanel;
- (void)setUpStockPanel;

- (void)setUpWell:(NSColorWell *)well withTransparency:(NSSlider *)tSlider;
- (void)setUpModuleSelection;
- (IBAction)setGraphRefreshAction:(id)sender;
- (IBAction)setNetMinGraphValueAction:(id)sender;
- (IBAction)setNetMinGraphUnitsAction:(id)sender;
- (NSColorWell *)colorWellForTag:(int)aTag;

//Required NSToolbar delegate methods
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;    
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;

//Action methods
- (IBAction)General:(id)sender;
- (IBAction)Colors:(id)sender;
- (IBAction)CPU:(id)sender;
- (IBAction)RAM:(id)sender;
- (IBAction)Temperature:(id)sender;
- (IBAction)Network:(id)sender;
- (IBAction)Disk:(id)sender;
- (IBAction)Weather:(id)sender;
- (IBAction)Stocks:(id)sender;
- (IBAction)setFont:(id)sender;

- (IBAction)openWeatherStationList:(id)sender;

@end

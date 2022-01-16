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
//  XRGSettings.h
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, XRGTemperatureUnits) {
    XRGTemperatureUnitsF = 0,
    XRGTemperatureUnitsC
};

@interface XRGSettings : NSObject

// Colors
@property (nonatomic) NSColor		*backgroundColor;
@property (nonatomic) NSColor		*graphBGColor;
@property (nonatomic) NSColor		*graphFG1Color;
@property (nonatomic) NSColor		*graphFG2Color;
@property (nonatomic) NSColor		*graphFG3Color;
@property (nonatomic) NSColor		*borderColor;
@property (nonatomic) NSColor		*textColor;

// Transparencies
@property (nonatomic) CGFloat		backgroundTransparency;
@property (nonatomic) CGFloat		graphBGTransparency;
@property (nonatomic) CGFloat		graphFG1Transparency;
@property (nonatomic) CGFloat		graphFG2Transparency;
@property (nonatomic) CGFloat		graphFG3Transparency;
@property (nonatomic) CGFloat		borderTransparency;
@property (nonatomic) CGFloat		textTransparency;
    
// Text attributes
@property (nonatomic) NSFont		*graphFont;
@property CGFloat					textRectHeight;
@property NSMutableParagraphStyle	*alignRight;
@property NSMutableParagraphStyle	*alignLeft;
@property NSMutableParagraphStyle	*alignCenter;
@property NSMutableDictionary		*alignRightAttributes;
@property NSMutableDictionary		*alignLeftAttributes;
@property NSMutableDictionary		*alignCenterAttributes;

// Other user defined settings
@property BOOL			fastCPUUsage;
@property BOOL			separateCPUColor;
@property BOOL			showCPUTemperature;
@property NSInteger		cpuTemperatureUnits;
@property BOOL			antiAliasing;
@property NSString		*ICAO;
@property NSInteger		secondaryWeatherGraph;
@property NSInteger		temperatureUnits;
@property NSInteger		distanceUnits;
@property NSInteger		pressureUnits;
@property BOOL			showMemoryPagingGraph;
@property BOOL			memoryShowWired;
@property BOOL			memoryShowActive;
@property BOOL			memoryShowInactive;
@property BOOL			memoryShowFree;
@property BOOL			memoryShowCache;
@property BOOL			memoryShowPage;
@property CGFloat		graphRefresh;
@property BOOL			showLoadAverage;
@property NSInteger		netMinGraphScale;
@property NSString		*stockSymbols;
@property NSInteger		stockGraphTimeFrame;
@property BOOL			stockShowChange;
@property BOOL			showDJIA;
@property NSInteger		windowLevel;
@property BOOL			stickyWindow;
@property BOOL			checkForUpdates;
@property NSInteger		netGraphMode;
@property NSInteger		diskGraphMode;
@property BOOL			dropShadow;
@property BOOL			showTotalBandwidthSinceBoot;
@property BOOL			showTotalBandwidthSinceLoad;
@property NSString		*networkInterface;
@property NSString		*windowTitle;
@property BOOL			autoExpandGraph;
@property BOOL			foregroundWhenExpanding;
@property BOOL			showSummary;
@property NSInteger		minimizeUpDown;
@property BOOL			antialiasText;
@property BOOL			cpuShowAverageUsage;
@property BOOL			cpuShowUptime;
@property XRGTemperatureUnits tempUnits;
@property NSString		*tempFG1Location;
@property NSString		*tempFG2Location;
@property NSString		*tempFG3Location;
@property BOOL          isDockIconHidden;

- (void) readXTFDictionary:(NSDictionary *)xtfD;

@end

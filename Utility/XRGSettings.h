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
//  XRGSettings.h
//

#import <Cocoa/Cocoa.h>

@interface XRGSettings : NSObject {
	// Colors
	NSColor					*backgroundColor;
	NSColor					*graphBGColor;
	NSColor					*graphFG1Color;
	NSColor					*graphFG2Color;
	NSColor					*graphFG3Color;
	NSColor					*borderColor;
	NSColor					*textColor;
	
	// Transparencies
	CGFloat					backgroundTransparency;
	CGFloat					graphBGTransparency;
	CGFloat					graphFG1Transparency;
	CGFloat					graphFG2Transparency;
	CGFloat					graphFG3Transparency;
	CGFloat					borderTransparency;
	CGFloat					textTransparency;
    
	// Text attributes
	NSFont					*graphFont;
	NSInteger				textRectHeight;
	NSMutableParagraphStyle	*alignRight;
	NSMutableParagraphStyle	*alignLeft;
	NSMutableParagraphStyle	*alignCenter;
	NSMutableDictionary		*alignRightAttributes;
	NSMutableDictionary		*alignLeftAttributes;
	NSMutableDictionary		*alignCenterAttributes;
	
	// Other user defined settings
	BOOL					fastCPUUsage;
	BOOL					separateCPUColor;
	BOOL					showCPUTemperature;
	NSInteger				cpuTemperatureUnits;
	BOOL					antiAliasing;
	NSString				*ICAO;
	NSInteger				secondaryWeatherGraph;
	NSInteger				temperatureUnits;
	NSInteger				distanceUnits;
	NSInteger				pressureUnits;
	BOOL					showMemoryPagingGraph;
	BOOL					memoryShowWired;
	BOOL					memoryShowActive;
	BOOL					memoryShowInactive;
	BOOL					memoryShowFree;
	BOOL					memoryShowCache;
	BOOL					memoryShowPage;
	CGFloat					graphRefresh;
	BOOL					showLoadAverage;
	NSInteger				netMinGraphScale;
	NSString				*stockSymbols;
	NSInteger				stockGraphTimeFrame;
	BOOL					stockShowChange;
	BOOL					showDJIA;
	NSInteger				windowLevel;
	BOOL					stickyWindow;
	BOOL					checkForUpdates;
	NSInteger				netGraphMode;
	NSInteger				diskGraphMode;
	BOOL					dropShadow;
	BOOL					showTotalBandwidthSinceBoot;
	BOOL					showTotalBandwidthSinceLoad;
	NSString				*networkInterface;
	NSString				*windowTitle;
	BOOL					autoExpandGraph;
	BOOL					foregroundWhenExpanding;
	BOOL					showSummary;
	NSInteger				minimizeUpDown;
	BOOL					antialiasText;
	BOOL					cpuShowAverageUsage;
	BOOL					cpuShowUptime;
	NSInteger				tempUnits;
	NSInteger				tempFG1Location;
	NSInteger				tempFG2Location;
	NSInteger				tempFG3Location;
}

// Colors
@property (strong,nonatomic) NSColor		*backgroundColor;
@property (strong,nonatomic) NSColor		*graphBGColor;
@property (strong,nonatomic) NSColor		*graphFG1Color;
@property (strong,nonatomic) NSColor		*graphFG2Color;
@property (strong,nonatomic) NSColor		*graphFG3Color;
@property (strong,nonatomic) NSColor		*borderColor;
@property (strong,nonatomic) NSColor		*textColor;

// Transparencies
@property (assign,nonatomic) CGFloat		backgroundTransparency;
@property (assign,nonatomic) CGFloat		graphBGTransparency;
@property (assign,nonatomic) CGFloat		graphFG1Transparency;
@property (assign,nonatomic) CGFloat		graphFG2Transparency;
@property (assign,nonatomic) CGFloat		graphFG3Transparency;
@property (assign,nonatomic) CGFloat		borderTransparency;
@property (assign,nonatomic) CGFloat		textTransparency;
    
// Text attributes
@property (strong,nonatomic) NSFont			*graphFont;
@property (assign) NSInteger				textRectHeight;
@property (strong) NSMutableParagraphStyle	*alignRight;
@property (strong) NSMutableParagraphStyle	*alignLeft;
@property (strong) NSMutableParagraphStyle	*alignCenter;
@property (strong) NSMutableDictionary		*alignRightAttributes;
@property (strong) NSMutableDictionary		*alignLeftAttributes;
@property (strong) NSMutableDictionary		*alignCenterAttributes;

// Other user defined settings
@property (assign) BOOL			fastCPUUsage;
@property (assign) BOOL			separateCPUColor;
@property (assign) BOOL			showCPUTemperature;
@property (assign) NSInteger	cpuTemperatureUnits;
@property (assign) BOOL			antiAliasing;
@property (strong) NSString		*ICAO;
@property (assign) NSInteger	secondaryWeatherGraph;
@property (assign) NSInteger	temperatureUnits;
@property (assign) NSInteger	distanceUnits;
@property (assign) NSInteger	pressureUnits;
@property (assign) BOOL			showMemoryPagingGraph;
@property (assign) BOOL			memoryShowWired;
@property (assign) BOOL			memoryShowActive;
@property (assign) BOOL			memoryShowInactive;
@property (assign) BOOL			memoryShowFree;
@property (assign) BOOL			memoryShowCache;
@property (assign) BOOL			memoryShowPage;
@property (assign) CGFloat		graphRefresh;
@property (assign) BOOL			showLoadAverage;
@property (assign) NSInteger	netMinGraphScale;
@property (strong) NSString		*stockSymbols;
@property (assign) NSInteger	stockGraphTimeFrame;
@property (assign) BOOL			stockShowChange;
@property (assign) BOOL			showDJIA;
@property (assign) NSInteger	windowLevel;
@property (assign) BOOL			stickyWindow;
@property (assign) BOOL			checkForUpdates;
@property (assign) NSInteger	netGraphMode;
@property (assign) NSInteger	diskGraphMode;
@property (assign) BOOL			dropShadow;
@property (assign) BOOL			showTotalBandwidthSinceBoot;
@property (assign) BOOL			showTotalBandwidthSinceLoad;
@property (strong) NSString		*networkInterface;
@property (strong) NSString		*windowTitle;
@property (assign) BOOL			autoExpandGraph;
@property (assign) BOOL			foregroundWhenExpanding;
@property (assign) BOOL			showSummary;
@property (assign) NSInteger	minimizeUpDown;
@property (assign) BOOL			antialiasText;
@property (assign) BOOL			cpuShowAverageUsage;
@property (assign) BOOL			cpuShowUptime;
@property (assign) NSInteger	tempUnits;
@property (assign) NSInteger	tempFG1Location;
@property (assign) NSInteger	tempFG2Location;
@property (assign) NSInteger	tempFG3Location;

- (void) readXTFDictionary:(NSDictionary *)xtfD;

@end

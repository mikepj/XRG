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
    NSColor						*backgroundC;
    NSColor						*graphBGC;
    NSColor						*graphFG1C;
    NSColor						*graphFG2C;
    NSColor						*graphFG3C;
    NSColor						*borderC;
    NSColor						*textC;

    // Transparencies
    float						backgroundT;
    float						graphBGT;
    float						graphFG1T;
    float						graphFG2T;
    float						graphFG3T;
    float						borderT;
    float						textT;
    
    // Text attributes
    NSFont						*graphFont;
    int							textRectHeight;
    NSMutableParagraphStyle		*alignRight;
    NSMutableParagraphStyle		*alignLeft;
    NSMutableParagraphStyle		*alignCenter;
    NSMutableDictionary			*alignRightAttributes;
    NSMutableDictionary			*alignLeftAttributes;
    NSMutableDictionary			*alignCenterAttributes;
            
    // Other user defined settings
    bool						fastCPUUsage;
    bool						separateCPUColor;
    bool						showCPUTemperature;
    int							cpuTemperatureUnits;
    bool						antiAliasing;
    NSString					*icao;
    int							secondaryWeatherGraph;
    int							temperatureUnits;
    int							distanceUnits;
    int							pressureUnits;
    bool						showMemoryPagingGraph;
    bool						memoryShowWired;
    bool						memoryShowActive;
    bool						memoryShowInactive;
    bool						memoryShowFree;
    bool						memoryShowCache;
    bool						memoryShowPage;
    float						graphRefresh;
    bool						showLoadAverage;
    int							netMinGraphScale;
    NSString					*stockSymbols;
    int							stockGraphTimeFrame;
    bool						stockShowChange;
    bool						showDJIA;
    int							windowLevel;
    bool						stickyWindow;
    bool						checkForUpdates;
    int							netGraphMode;
    int							diskGraphMode;
    bool						dropShadow;
    bool						showTotalBandwidthSinceBoot;
    bool                        showTotalBandwidthSinceLoad;
    NSString                    *networkInterface;
    NSString                    *windowTitle;
    bool                        autoExpandGraph;
    bool                        foregroundWhenExpanding;
    bool                        showSummary;
    int                         minimizeUpDown;
    bool                        antialiasText;
    bool                        cpuShowAverageUsage;
    bool                        cpuShowUptime;
    int                         tempUnits;
    int                         tempFG1Location;
    int                         tempFG2Location;
    int                         tempFG3Location;
}
- (void)initVariables;

- (void) readXTFDictionary:(NSDictionary *)xtfD;

// Get methods
- (NSColor *)backgroundColor;
- (NSColor *)graphBGColor;
- (NSColor *)graphFG1Color;
- (NSColor *)graphFG2Color;
- (NSColor *)graphFG3Color;
- (NSColor *)borderColor;
- (NSColor *)textColor;

- (float) backgroundTransparency;
- (float) graphBGTransparency;
- (float) graphFG1Transparency;
- (float) graphFG2Transparency;
- (float) graphFG3Transparency;
- (float) borderTransparency;
- (float) textTransparency;

- (NSFont *)graphFont;
- (int)textRectHeight;
- (NSMutableParagraphStyle *)alignRight;
- (NSMutableParagraphStyle *)alignLeft;
- (NSMutableParagraphStyle *)alignCenter;
- (NSMutableDictionary *)alignRightAttributes;
- (NSMutableDictionary *)alignLeftAttributes;
- (NSMutableDictionary *)alignCenterAttributes;

- (bool)fastCPUUsage;
- (bool)antiAliasing;
- (bool)separateCPUColor;
- (bool)showCPUTemperature;
- (int)cpuTemperatureUnits;
- (NSString *)ICAO;
- (int)secondaryWeatherGraph;
- (int)temperatureUnits;
- (int)distanceUnits;
- (int)pressureUnits;
- (bool)showMemoryPagingGraph;
- (bool)memoryShowWired;
- (bool)memoryShowActive;
- (bool)memoryShowInactive;
- (bool)memoryShowFree;
- (bool)memoryShowCache;
- (bool)memoryShowPage;
- (float)graphRefresh;
- (bool)showLoadAverage;
- (int)netMinGraphScale;
- (NSString *)stockSymbols;
- (int)stockGraphTimeFrame;
- (bool)stockShowChange;
- (bool)showDJIA;
- (int)windowLevel;
- (bool)stickyWindow;
- (bool)checkForUpdates;
- (int)netGraphMode;
- (int)diskGraphMode;
- (bool)dropShadow;
- (bool)showTotalBandwidthSinceBoot;
- (bool)showTotalBandwidthSinceLoad;
- (NSString *)networkInterface;
- (NSString *)windowTitle;
- (bool)autoExpandGraph;
- (bool)foregroundWhenExpanding;
- (bool)showSummary;
- (int)minimizeUpDown;
- (bool)antialiasText;
- (bool)cpuShowAverageUsage;
- (bool)cpuShowUptime;
- (int)tempUnits;
- (int)tempFG1Location;
- (int)tempFG2Location;
- (int)tempFG3Location;


// Set methods
- (void)setBackgroundColor:(NSColor *) color;
- (void)setGraphBGColor:(NSColor *) color;
- (void)setGraphFG1Color:(NSColor *) color;
- (void)setGraphFG2Color:(NSColor *) color;
- (void)setGraphFG3Color:(NSColor *) color;
- (void)setBorderColor:(NSColor *) color;
- (void)setTextColor:(NSColor *) color;

- (void)setBackgroundTransparency:(float)transparency;
- (void)setGraphBGTransparency:(float)transparency;
- (void)setGraphFG1Transparency:(float)transparency;
- (void)setGraphFG2Transparency:(float)transparency;
- (void)setGraphFG3Transparency:(float)transparency;
- (void)setBorderTransparency:(float)transparency;
- (void)setTextTransparency:(float)transparency;

- (void)setGraphFont:(NSFont *)font;
- (void)setTextRectHeight:(int)height;

- (void)setFastCPUUsage:(bool)onOff;
- (void)setAntiAliasing:(bool)onOff;
- (void)setSeparateCPUColor:(bool)onOff;
- (void)setShowCPUTemperature:(bool)onOff;
- (void)setCPUTemperatureUnits:(int)value;
- (void)setICAO:(NSString *)newICAO;
- (void)setSecondaryWeatherGraph:(int)index;
- (void)setTemperatureUnits:(int)index;
- (void)setDistanceUnits:(int)index;
- (void)setPressureUnits:(int)index;
- (void)setShowMemoryPagingGraph:(bool)onOff;
- (void)setMemoryShowWired:(bool)onOff;
- (void)setMemoryShowActive:(bool)onOff;
- (void)setMemoryShowInactive:(bool)onOff;
- (void)setMemoryShowFree:(bool)onOff;
- (void)setMemoryShowCache:(bool)onOff;
- (void)setMemoryShowPage:(bool)onOff;
- (void)setGraphRefresh:(float)f;
- (void)setShowLoadAverage:(bool)onOff;
- (void)setNetMinGraphScale:(int)value;
- (void)setStockSymbols:(NSString *)newSymbols;
- (void)setStockGraphTimeFrame:(int)newTimeFrame;
- (void)setStockShowChange:(bool)yesNo;
- (void)setShowDJIA:(bool)yesNo;
- (void)setWindowLevel:(int)level;
- (void)setStickyWindow:(bool)onOff;
- (void)setCheckForUpdates:(bool)yesNo;
- (void)setNetGraphMode:(int)mode;
- (void)setDiskGraphMode:(int)mode;
- (void)setDropShadow:(bool)yesNo;
- (void)setShowTotalBandwidthSinceBoot:(bool)yesNo;
- (void)setShowTotalBandwidthSinceLoad:(bool)yesNo;
- (void)setNetworkInterface:(NSString *)interface;
- (void)setWindowTitle:(NSString *)title;
- (void)setAutoExpandGraph:(bool)yesNo;
- (void)setForegroundWhenExpanding:(bool)yesNo;
- (void)setShowSummary:(bool)yesNo;
- (void)setMinimizeUpDown:(int)value;
- (void)setAntialiasText:(bool)yesNo;
- (void)setCPUShowAverageUsage:(bool)yesNo;
- (void)setCPUShowUptime:(bool)yesNo;
- (void)setTempUnits:(int)value;
- (void)setTempFG1Location:(int)value;
- (void)setTempFG2Location:(int)value;
- (void)setTempFG3Location:(int)value;

@end

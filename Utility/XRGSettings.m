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
//  XRGSettings.m
//

#import "XRGSettings.h"
#import "definitions.h"

@implementation XRGSettings

- (void)initVariables {
    backgroundC = [[NSColor clearColor] retain];
    graphBGC    = [[NSColor clearColor] retain];
    graphFG1C   = [[NSColor clearColor] retain];
    graphFG2C   = [[NSColor clearColor] retain];
    graphFG3C   = [[NSColor clearColor] retain];
    borderC     = [[NSColor clearColor] retain];
    textC       = [[NSColor clearColor] retain];
    
    backgroundT = 0;
    graphBGT    = 0;
    graphFG1T   = 0;
    graphFG2T   = 0;
    graphFG3T   = 0;
    borderT     = 0;
    textT       = 0;
    
    graphFont      = [[NSFont fontWithName:@"Lucida Grande" size:8.0] retain];
    alignRight     = [[[NSParagraphStyle defaultParagraphStyle] mutableCopyWithZone: nil] retain];
    alignLeft      = [[[NSParagraphStyle defaultParagraphStyle] mutableCopyWithZone: nil] retain];
    alignCenter    = [[[NSParagraphStyle defaultParagraphStyle] mutableCopyWithZone: nil] retain];
    [alignRight  setAlignment: NSRightTextAlignment];
    [alignLeft   setAlignment: NSLeftTextAlignment];
    [alignCenter setAlignment: NSCenterTextAlignment];
	
	[alignLeft setLineBreakMode:NSLineBreakByTruncatingMiddle];
    
    alignRightAttributes = [[NSMutableDictionary dictionary] retain];
    [alignRightAttributes setObject:graphFont            forKey:NSFontAttributeName];
    [alignRightAttributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    [alignRightAttributes setObject:alignRight           forKey:NSParagraphStyleAttributeName];

    alignLeftAttributes = [[NSMutableDictionary dictionary] retain];
    [alignLeftAttributes setObject:graphFont            forKey:NSFontAttributeName];
    [alignLeftAttributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    [alignLeftAttributes setObject:alignLeft            forKey:NSParagraphStyleAttributeName];

    alignCenterAttributes = [[NSMutableDictionary dictionary] retain];
    [alignCenterAttributes setObject:graphFont            forKey:NSFontAttributeName];
    [alignCenterAttributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    [alignCenterAttributes setObject:alignCenter          forKey:NSParagraphStyleAttributeName];

    textRectHeight = [@"A" sizeWithAttributes:alignRightAttributes].height;

    fastCPUUsage                = NO;
    antiAliasing                = NO;
    separateCPUColor            = YES;
    showCPUTemperature          = NO;
    cpuTemperatureUnits         = 0;
    icao                        = @"";
    secondaryWeatherGraph       = YES;
    temperatureUnits            = 0;
    distanceUnits               = 0;
    pressureUnits               = 0;
    showMemoryPagingGraph       = YES;
    memoryShowWired             = YES;
    memoryShowActive            = YES;
    memoryShowInactive          = YES;
    memoryShowFree              = YES;
    memoryShowCache             = YES;
    memoryShowPage              = YES;
    graphRefresh                = 1;
    showLoadAverage             = YES;
    netMinGraphScale            = 1024;
    stockSymbols                = @"AAPL";
    stockGraphTimeFrame         = 3;
    stockShowChange             = YES;
    showDJIA                    = YES;
    windowLevel					= 0;
    stickyWindow                = YES;
    netGraphMode                = 0;
    diskGraphMode               = 0;
    dropShadow                  = NO;
    showTotalBandwidthSinceBoot = YES;
    showTotalBandwidthSinceLoad = YES;
    networkInterface            = @"All";
    windowTitle                 = @"";
}

- (void) readXTFDictionary:(NSDictionary *)xtfD {
	@try {
		NSData *d = [xtfD objectForKey:XRG_backgroundColor];
		[self setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = [xtfD objectForKey:XRG_graphBGColor];
		[self setGraphBGColor:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = [xtfD objectForKey:XRG_graphFG1Color];
		[self setGraphFG1Color:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = [xtfD objectForKey:XRG_graphFG2Color];
		[self setGraphFG2Color:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = [xtfD objectForKey:XRG_graphFG3Color];
		[self setGraphFG3Color:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = [xtfD objectForKey:XRG_borderColor];
		[self setBorderColor:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = [xtfD objectForKey:XRG_textColor];
		[self setTextColor:[NSUnarchiver unarchiveObjectWithData:d]];
		
		NSNumber *n = (NSNumber *)[xtfD objectForKey:XRG_backgroundTransparency];
		[self setBackgroundTransparency: [n floatValue]];
		
		n = (NSNumber *)[xtfD objectForKey:XRG_graphBGTransparency];
		[self setGraphBGTransparency:    [n floatValue]];
		
		n = (NSNumber *)[xtfD objectForKey:XRG_graphFG1Transparency];
		[self setGraphFG1Transparency:   [n floatValue]];
		
		n = (NSNumber *)[xtfD objectForKey:XRG_graphFG2Transparency];
		[self setGraphFG2Transparency:   [n floatValue]];
		
		n = (NSNumber *)[xtfD objectForKey:XRG_graphFG3Transparency];
		[self setGraphFG3Transparency:   [n floatValue]];
		
		n = (NSNumber *)[xtfD objectForKey:XRG_borderTransparency];
		[self setBorderTransparency:     [n floatValue]];
		
		n = (NSNumber *)[xtfD objectForKey:XRG_textTransparency];
		[self setTextTransparency:       [n floatValue]];
	} @catch (NSException *e) {
		NSRunInformationalAlertPanel(@"Error", @"The file dragged is not a valid theme file.", @"OK", nil, nil);
	}
	
	// Now save the new theme values to our prefs file
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	
    [defs setFloat: [self backgroundTransparency] forKey:XRG_backgroundTransparency];
    [defs setFloat: [self graphBGTransparency]    forKey:XRG_graphBGTransparency];
    [defs setFloat: [self graphFG1Transparency]   forKey:XRG_graphFG1Transparency];
    [defs setFloat: [self graphFG2Transparency]   forKey:XRG_graphFG2Transparency];
    [defs setFloat: [self graphFG3Transparency]   forKey:XRG_graphFG3Transparency];
    [defs setFloat: [self borderTransparency]     forKey:XRG_borderTransparency];
    [defs setFloat: [self textTransparency]       forKey:XRG_textTransparency];
    
    [defs setObject:
	 [NSArchiver archivedDataWithRootObject: [self backgroundColor]]
			 forKey: XRG_backgroundColor
	 ];
    [defs setObject:
	 [NSArchiver archivedDataWithRootObject:[self graphBGColor]]
			 forKey: XRG_graphBGColor
	 ];
    [defs setObject:
	 [NSArchiver archivedDataWithRootObject:[self graphFG1Color]]
			 forKey: XRG_graphFG1Color
	 ];
    [defs setObject:
	 [NSArchiver archivedDataWithRootObject: [self graphFG2Color]]
			 forKey: XRG_graphFG2Color
	 ];
    [defs setObject:
	 [NSArchiver archivedDataWithRootObject: [self graphFG3Color]]
			 forKey: XRG_graphFG3Color
	 ];
    [defs setObject:
	 [NSArchiver archivedDataWithRootObject: [self borderColor]]
			 forKey: XRG_borderColor
	 ];
    [defs setObject:
	 [NSArchiver archivedDataWithRootObject: [self textColor]]
			 forKey: XRG_textColor
	 ];
	
    [defs synchronize];
}

- (NSColor *) backgroundColor {
    return backgroundC;
}

- (NSColor *) graphBGColor {
    return graphBGC;
}

- (NSColor *) graphFG1Color {
    return graphFG1C;
}

- (NSColor *) graphFG2Color {
    return graphFG2C;
}

- (NSColor *) graphFG3Color {
    return graphFG3C;
}

- (NSColor *)borderColor {
    return borderC;
}

- (NSColor *)textColor {
    return textC;
}

- (float) backgroundTransparency {
    return backgroundT;
}

- (float) graphBGTransparency {
    return graphBGT;
}

- (float) graphFG1Transparency {
    return graphFG1T;
}

- (float) graphFG2Transparency {
    return graphFG2T;
}

- (float) graphFG3Transparency {
    return graphFG3T;
}

- (float) borderTransparency {
    return borderT;
}

- (float) textTransparency {
    return textT;
}

- (bool)fastCPUUsage {
    return fastCPUUsage;
}

- (bool)antiAliasing {
    return antiAliasing;
}

- (bool)separateCPUColor {
    return separateCPUColor;
}

- (bool)showCPUTemperature {
    return showCPUTemperature;
}

- (int)cpuTemperatureUnits {
    return cpuTemperatureUnits;
}

- (int)textRectHeight {
    return textRectHeight;
}

- (NSFont *)graphFont {
    return graphFont;
}

- (NSMutableParagraphStyle *)alignRight {
    return alignRight;
}

- (NSMutableParagraphStyle *)alignLeft {
    return alignLeft;
}

- (NSMutableParagraphStyle *)alignCenter {
    return alignCenter;
}

- (NSMutableDictionary *)alignRightAttributes {
    return alignRightAttributes;
}

- (NSMutableDictionary *)alignLeftAttributes {
    return alignLeftAttributes;
}

- (NSMutableDictionary *)alignCenterAttributes {
    return alignCenterAttributes;
}

- (NSString *)ICAO {
    return icao;
}

- (int)secondaryWeatherGraph {
    return secondaryWeatherGraph;
}

- (int)temperatureUnits {
    return temperatureUnits;
}

- (int)distanceUnits {
    return distanceUnits;
}

- (int)pressureUnits {
    return pressureUnits;
}

- (bool)showMemoryPagingGraph {
    return showMemoryPagingGraph;
}

- (bool)memoryShowWired {
    return memoryShowWired;
}

- (bool)memoryShowActive {
    return memoryShowActive;
}

- (bool)memoryShowInactive {
    return memoryShowInactive;
}

- (bool)memoryShowFree {
    return memoryShowFree;
}

- (bool)memoryShowCache {
    return memoryShowCache;
}

- (bool)memoryShowPage {
    return memoryShowPage;
}

- (float)graphRefresh {
    return graphRefresh;
}

- (bool)showLoadAverage {
    return showLoadAverage;
}

- (int)netMinGraphScale {
    return netMinGraphScale;
}

- (NSString *)stockSymbols {
    return stockSymbols;
}

- (int)stockGraphTimeFrame {
    return stockGraphTimeFrame;
}

- (bool)stockShowChange {
    return stockShowChange;
}

- (bool)showDJIA {
    return showDJIA;
}

- (int)windowLevel
{
    return windowLevel;
}

- (bool)stickyWindow {
    return stickyWindow;
}

- (bool)checkForUpdates {
    return checkForUpdates;
}

- (int)netGraphMode {
    return netGraphMode;
}

- (int)diskGraphMode {
    return diskGraphMode;
}

- (bool)dropShadow {
    return dropShadow;
}

- (bool)showTotalBandwidthSinceBoot {
    return showTotalBandwidthSinceBoot;
}

- (bool)showTotalBandwidthSinceLoad {
    return showTotalBandwidthSinceLoad;
}

- (NSString *)networkInterface {
    return networkInterface;
}

- (NSString *)windowTitle {
    return windowTitle;
}

- (bool)autoExpandGraph {
    return autoExpandGraph;
}

- (bool)foregroundWhenExpanding {
    return foregroundWhenExpanding;
}

- (bool)showSummary {
    return showSummary;
}

- (int)minimizeUpDown {
    return minimizeUpDown;
}

- (bool)antialiasText {
    return antialiasText;
}

- (bool)cpuShowAverageUsage {
    return cpuShowAverageUsage;
}

- (bool)cpuShowUptime {
    return cpuShowUptime;
}

- (int)tempUnits {
    return tempUnits;
}

- (int)tempFG1Location {
    return tempFG1Location;
}

- (int)tempFG2Location {
    return tempFG2Location;
}

- (int)tempFG3Location {
    return tempFG3Location;
}


- (void)setBackgroundColor:(NSColor *) color {
    NSColor *tmpColor;
    tmpColor = [color colorWithAlphaComponent:backgroundT];
    [backgroundC autorelease];
    backgroundC = [tmpColor copy];            
}

- (void)setGraphBGColor:(NSColor *) color {
    NSColor *tmpColor;
    tmpColor = [color colorWithAlphaComponent:graphBGT];
    [graphBGC autorelease];
    graphBGC = [tmpColor copy];            
}

- (void)setGraphFG1Color:(NSColor *) color {
    NSColor *tmpColor;
    tmpColor = [color colorWithAlphaComponent:graphFG1T];
    [graphFG1C autorelease];
    graphFG1C = [tmpColor copy];            
}

- (void)setGraphFG2Color:(NSColor *) color {
    NSColor *tmpColor;
    tmpColor = [color colorWithAlphaComponent:graphFG2T];
    [graphFG2C autorelease];
    graphFG2C = [tmpColor copy];            
}

- (void)setGraphFG3Color:(NSColor *) color {
    NSColor *tmpColor;
    tmpColor = [color colorWithAlphaComponent:graphFG3T];
    [graphFG3C autorelease];
    graphFG3C = [tmpColor copy];
}

- (void)setBorderColor:(NSColor *) color {
    NSColor *tmpColor;
    tmpColor = [color colorWithAlphaComponent:borderT];
    [borderC autorelease];
    borderC = [tmpColor copy];            
}

- (void)setTextColor:(NSColor *) color {
    NSColor *tmpColor;
    tmpColor = [color colorWithAlphaComponent:textT];
    [textC autorelease];
    textC = [tmpColor copy];
    [alignRightAttributes setObject:textC forKey:NSForegroundColorAttributeName];
    [alignCenterAttributes setObject:textC forKey:NSForegroundColorAttributeName];
    [alignLeftAttributes setObject:textC forKey:NSForegroundColorAttributeName];
}

- (void)setBackgroundTransparency:(float)transparency {
    NSColor *tmpColor;
    tmpColor = [backgroundC colorWithAlphaComponent:transparency];
    [backgroundC autorelease];
    backgroundC = [tmpColor copy];            
    backgroundT = transparency;
}

- (void)setGraphBGTransparency:(float)transparency {
    NSColor *tmpColor;
    tmpColor = [graphBGC colorWithAlphaComponent:transparency];
    [graphBGC autorelease];
    graphBGC = [tmpColor copy];            
    graphBGT = transparency;
}

- (void)setGraphFG1Transparency:(float)transparency {
    NSColor *tmpColor;
    tmpColor = [graphFG1C colorWithAlphaComponent:transparency];
    [graphFG1C autorelease];
    graphFG1C = [tmpColor copy];            
    graphFG1T = transparency;
}

- (void)setGraphFG2Transparency:(float)transparency {
    NSColor *tmpColor;
    tmpColor = [graphFG2C colorWithAlphaComponent:transparency];
    [graphFG2C autorelease];
    graphFG2C = [tmpColor copy];            
    graphFG2T = transparency;
}

- (void)setGraphFG3Transparency:(float)transparency {
    NSColor *tmpColor;
    tmpColor = [graphFG3C colorWithAlphaComponent:transparency];
    [graphFG3C autorelease];
    graphFG3C = [tmpColor copy];
    graphFG3T = transparency;
}

- (void)setBorderTransparency:(float)transparency {
    NSColor *tmpColor;
    tmpColor = [borderC colorWithAlphaComponent:transparency];
    [borderC autorelease];
    borderC = [tmpColor copy];            
    borderT = transparency;
}

- (void)setTextTransparency:(float)transparency {
    NSColor *tmpColor;
    tmpColor = [textC colorWithAlphaComponent:transparency];
    [textC autorelease];
    textC = [tmpColor copy];
    textT = transparency;
    [alignRightAttributes setObject:textC forKey:NSForegroundColorAttributeName];
    [alignCenterAttributes setObject:textC forKey:NSForegroundColorAttributeName];
    [alignLeftAttributes setObject:textC forKey:NSForegroundColorAttributeName];
}

- (void)setGraphFont:(NSFont *)font {
    if (font == graphFont) return;
    
    if (font) {
        if (graphFont) 
            [graphFont autorelease];

        graphFont = [font retain];
    
        [alignRightAttributes  setObject:graphFont forKey:NSFontAttributeName];
        [alignLeftAttributes   setObject:graphFont forKey:NSFontAttributeName];
        [alignCenterAttributes setObject:graphFont forKey:NSFontAttributeName];
    
		textRectHeight = [[NSString stringWithFormat:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234567890%C.:%", 0x00B0] sizeWithAttributes:alignRightAttributes].height;
    }
    else {
        NSLog(@"Couldn't change to a nil font.");
    }
}

- (void)setTextRectHeight:(int)height {
    textRectHeight = height;
}

- (void)setFastCPUUsage:(bool)onOff {
    fastCPUUsage = onOff;
}

- (void)setAntiAliasing:(bool)onOff {
    antiAliasing = onOff;
}

- (void)setSeparateCPUColor:(bool)onOff {
    separateCPUColor = onOff;
}

- (void)setShowCPUTemperature:(bool)onOff {
    showCPUTemperature = onOff;
}

- (void)setCPUTemperatureUnits:(int)value {
    cpuTemperatureUnits = value;
}

- (void)setICAO:(NSString *)newICAO {
    [icao autorelease];
    icao = [newICAO retain];
}

- (void)setSecondaryWeatherGraph:(int)index {
    secondaryWeatherGraph = index;
}

- (void)setTemperatureUnits:(int)index {
    temperatureUnits = index;
}

- (void)setDistanceUnits:(int)index {
    distanceUnits = index;
}

- (void)setPressureUnits:(int)index {
    pressureUnits = index;
}

- (void)setShowMemoryPagingGraph:(bool)onOff {
    showMemoryPagingGraph = onOff;
}

- (void)setMemoryShowWired:(bool)onOff {
    memoryShowWired = onOff;
}

- (void)setMemoryShowActive:(bool)onOff {
    memoryShowActive = onOff;
}

- (void)setMemoryShowInactive:(bool)onOff {
    memoryShowInactive = onOff;
}

- (void)setMemoryShowFree:(bool)onOff {
    memoryShowFree = onOff;
}

- (void)setMemoryShowCache:(bool)onOff {
    memoryShowCache = onOff;
}

- (void)setMemoryShowPage:(bool)onOff {
    memoryShowPage = onOff;
}

- (void)setGraphRefresh:(float)f {
    graphRefresh = f;
}

- (void)setShowLoadAverage:(bool)onOff {
    showLoadAverage = onOff;
}

- (void)setNetMinGraphScale:(int)value {
    netMinGraphScale = value;
}

- (void)setStockSymbols:(NSString *)newSymbols {
     if (stockSymbols != nil) [stockSymbols autorelease];
     stockSymbols = [newSymbols retain];
}

- (void)setStockGraphTimeFrame:(int)newTimeFrame {
    stockGraphTimeFrame = newTimeFrame;
}

- (void)setStockShowChange:(bool)yesNo {
    stockShowChange = yesNo;
}

- (void)setShowDJIA:(bool)yesNo {
    showDJIA = yesNo;
}

- (void)setWindowLevel:(int)index
{
    windowLevel = index;
}

- (void)setStickyWindow:(bool)onOff {
    stickyWindow = onOff;
}

- (void)setCheckForUpdates:(bool)yesNo {
    checkForUpdates = yesNo;
}

- (void)setNetGraphMode:(int)mode {
    netGraphMode = mode;
}

- (void)setDiskGraphMode:(int)mode {
    diskGraphMode = mode;
}

- (void)setDropShadow:(bool)yesNo {
    dropShadow = yesNo;
}

- (void)setShowTotalBandwidthSinceBoot:(bool)yesNo {
    showTotalBandwidthSinceBoot = yesNo;
}

- (void)setShowTotalBandwidthSinceLoad:(bool)yesNo {
    showTotalBandwidthSinceLoad = yesNo;
}

- (void)setNetworkInterface:(NSString *)interface {
     if (networkInterface != nil) [networkInterface autorelease];
     networkInterface = [interface retain];
}

- (void)setWindowTitle:(NSString *)title {
    if (windowTitle != nil) [windowTitle autorelease];
    windowTitle = [title retain];
}

- (void)setAutoExpandGraph:(bool)yesNo {
    autoExpandGraph = yesNo;
}

- (void)setForegroundWhenExpanding:(bool)yesNo {
    foregroundWhenExpanding = yesNo;
}

- (void)setShowSummary:(bool)yesNo {
    showSummary = yesNo;
}

- (void)setMinimizeUpDown:(int)value {
    minimizeUpDown = value;
}

- (void)setAntialiasText:(bool)yesNo {
    antialiasText = yesNo;
}

- (void)setCPUShowAverageUsage:(bool)yesNo {
    cpuShowAverageUsage = yesNo;
}

- (void)setCPUShowUptime:(bool)yesNo {
    cpuShowUptime = yesNo;
}

- (void)setTempUnits:(int)value {
    tempUnits = value;
}

- (void)setTempFG1Location:(int)value {
    tempFG1Location = value;
}

- (void)setTempFG2Location:(int)value {
    tempFG2Location = value;
}

- (void)setTempFG3Location:(int)value {
    tempFG3Location = value;
}

@end

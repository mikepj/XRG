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
@synthesize backgroundColor, graphBGColor, graphFG1Color, graphFG2Color, graphFG3Color, borderColor, textColor;
@synthesize backgroundTransparency, graphBGTransparency, graphFG1Transparency, graphFG2Transparency, graphFG3Transparency, borderTransparency, textTransparency;
@synthesize graphFont, textRectHeight, alignRight, alignLeft, alignCenter, alignRightAttributes, alignLeftAttributes, alignCenterAttributes;
@synthesize fastCPUUsage, separateCPUColor, showCPUTemperature, cpuTemperatureUnits, antiAliasing, ICAO, secondaryWeatherGraph, temperatureUnits, distanceUnits, pressureUnits, showMemoryPagingGraph, memoryShowWired, memoryShowActive, memoryShowInactive, memoryShowFree, memoryShowCache, memoryShowPage, graphRefresh, showLoadAverage, netMinGraphScale, stockSymbols, stockGraphTimeFrame, stockShowChange, showDJIA, windowLevel, stickyWindow, checkForUpdates, netGraphMode, diskGraphMode, dropShadow, showTotalBandwidthSinceBoot, showTotalBandwidthSinceLoad, networkInterface, windowTitle, autoExpandGraph, foregroundWhenExpanding, showSummary, minimizeUpDown, antialiasText, cpuShowAverageUsage, cpuShowUptime, tempUnits, tempFG1Location, tempFG2Location, tempFG3Location;

- (instancetype) init {
	self = [super init];
	if (self) {
		self.backgroundColor = [NSColor clearColor];
		self.graphBGColor    = [NSColor clearColor];
		self.graphFG1Color   = [NSColor clearColor];
		self.graphFG2Color   = [NSColor clearColor];
		self.graphFG3Color   = [NSColor clearColor];
		self.borderColor     = [NSColor clearColor];
		self.textColor       = [NSColor clearColor];

		self.backgroundTransparency = 0;
		self.graphBGTransparency    = 0;
		self.graphFG1Transparency   = 0;
		self.graphFG2Transparency   = 0;
		self.graphFG3Transparency   = 0;
		self.borderTransparency     = 0;
		self.textTransparency       = 0;

		self.graphFont = [NSFont fontWithName:@"Lucida Grande" size:8.0];
		self.alignRight = [[[NSParagraphStyle defaultParagraphStyle] mutableCopyWithZone: nil] autorelease];
		self.alignLeft = [[[NSParagraphStyle defaultParagraphStyle] mutableCopyWithZone: nil] autorelease];
		self.alignCenter = [[[NSParagraphStyle defaultParagraphStyle] mutableCopyWithZone: nil] autorelease];
		[alignRight  setAlignment:NSRightTextAlignment];
		[alignLeft   setAlignment:NSLeftTextAlignment];
		[alignCenter setAlignment:NSCenterTextAlignment];
		[alignLeft setLineBreakMode:NSLineBreakByTruncatingMiddle];

		self.alignRightAttributes = [NSMutableDictionary dictionary];
		alignRightAttributes[NSFontAttributeName] = graphFont;
		alignRightAttributes[NSForegroundColorAttributeName] = [NSColor blackColor];
		alignRightAttributes[NSParagraphStyleAttributeName] = alignRight;

		self.alignLeftAttributes = [NSMutableDictionary dictionary];
		alignLeftAttributes[NSFontAttributeName] = graphFont;
		alignLeftAttributes[NSForegroundColorAttributeName] = [NSColor blackColor];
		alignLeftAttributes[NSParagraphStyleAttributeName] = alignLeft;

		self.alignCenterAttributes = [NSMutableDictionary dictionary];
		alignCenterAttributes[NSFontAttributeName] = graphFont;
		alignCenterAttributes[NSForegroundColorAttributeName] = [NSColor blackColor];
		alignCenterAttributes[NSParagraphStyleAttributeName] = alignCenter;

		self.textRectHeight = [@"A" sizeWithAttributes:alignRightAttributes].height;

		self.fastCPUUsage                = NO;
		self.antiAliasing                = NO;
		self.separateCPUColor            = YES;
		self.showCPUTemperature          = NO;
		self.cpuTemperatureUnits         = 0;
		self.ICAO                        = @"";
		self.secondaryWeatherGraph       = YES;
		self.temperatureUnits            = 0;
		self.distanceUnits               = 0;
		self.pressureUnits               = 0;
		self.showMemoryPagingGraph       = YES;
		self.memoryShowWired             = YES;
		self.memoryShowActive            = YES;
		self.memoryShowInactive          = YES;
		self.memoryShowFree              = YES;
		self.memoryShowCache             = YES;
		self.memoryShowPage              = YES;
		self.graphRefresh                = 1;
		self.showLoadAverage             = YES;
		self.netMinGraphScale            = 1024;
		self.stockSymbols                = @"AAPL";
		self.stockGraphTimeFrame         = 3;
		self.stockShowChange             = YES;
		self.showDJIA                    = YES;
		self.windowLevel					= 0;
		self.stickyWindow                = YES;
		self.netGraphMode                = 0;
		self.diskGraphMode               = 0;
		self.dropShadow                  = NO;
		self.showTotalBandwidthSinceBoot = YES;
		self.showTotalBandwidthSinceLoad = YES;
		self.networkInterface            = @"All";
		self.windowTitle                 = @"";
	}
	
	return self;
}

- (void) dealloc {
	self.backgroundColor = nil;
	self.graphBGColor = nil;
	self.graphFG1Color = nil;
	self.graphFG2Color = nil;
	self.graphFG3Color = nil;
	self.borderColor = nil;
	self.textColor = nil;
	
	self.graphFont = nil;
	self.alignRight = nil;
	self.alignLeft = nil;
	self.alignCenter = nil;
	self.alignRightAttributes = nil;
	self.alignLeftAttributes = nil;
	self.alignCenterAttributes = nil;
	
	self.ICAO = nil;
	self.stockSymbols = nil;
	self.networkInterface = nil;
	self.windowTitle = nil;
	
	[super dealloc];
}

- (void) readXTFDictionary:(NSDictionary *)xtfD {
	@try {
		NSData *d = xtfD[XRG_backgroundColor];
		[self setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = xtfD[XRG_graphBGColor];
		[self setGraphBGColor:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = xtfD[XRG_graphFG1Color];
		[self setGraphFG1Color:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = xtfD[XRG_graphFG2Color];
		[self setGraphFG2Color:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = xtfD[XRG_graphFG3Color];
		[self setGraphFG3Color:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = xtfD[XRG_borderColor];
		[self setBorderColor:[NSUnarchiver unarchiveObjectWithData:d]];
		
		d = xtfD[XRG_textColor];
		[self setTextColor:[NSUnarchiver unarchiveObjectWithData:d]];
		
		NSNumber *n = (NSNumber *)xtfD[XRG_backgroundTransparency];
		[self setBackgroundTransparency: [n floatValue]];
		
		n = (NSNumber *)xtfD[XRG_graphBGTransparency];
		[self setGraphBGTransparency:    [n floatValue]];
		
		n = (NSNumber *)xtfD[XRG_graphFG1Transparency];
		[self setGraphFG1Transparency:   [n floatValue]];
		
		n = (NSNumber *)xtfD[XRG_graphFG2Transparency];
		[self setGraphFG2Transparency:   [n floatValue]];
		
		n = (NSNumber *)xtfD[XRG_graphFG3Transparency];
		[self setGraphFG3Transparency:   [n floatValue]];
		
		n = (NSNumber *)xtfD[XRG_borderTransparency];
		[self setBorderTransparency:     [n floatValue]];
		
		n = (NSNumber *)xtfD[XRG_textTransparency];
		[self setTextTransparency:       [n floatValue]];
	} @catch (NSException *e) {
		NSRunInformationalAlertPanel(@"Error", @"The file dragged is not a valid theme file.", @"OK", nil, nil);
	}
	
	// Now save the new theme values to our prefs file
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	
    [defs setFloat:[self backgroundTransparency] forKey:XRG_backgroundTransparency];
    [defs setFloat:[self graphBGTransparency]    forKey:XRG_graphBGTransparency];
    [defs setFloat:[self graphFG1Transparency]   forKey:XRG_graphFG1Transparency];
    [defs setFloat:[self graphFG2Transparency]   forKey:XRG_graphFG2Transparency];
    [defs setFloat:[self graphFG3Transparency]   forKey:XRG_graphFG3Transparency];
    [defs setFloat:[self borderTransparency]     forKey:XRG_borderTransparency];
    [defs setFloat:[self textTransparency]       forKey:XRG_textTransparency];
    
    [defs setObject:[NSArchiver archivedDataWithRootObject:[self backgroundColor]] forKey:XRG_backgroundColor];
    [defs setObject:[NSArchiver archivedDataWithRootObject:[self graphBGColor]] forKey: XRG_graphBGColor];
    [defs setObject:[NSArchiver archivedDataWithRootObject:[self graphFG1Color]] forKey: XRG_graphFG1Color];
    [defs setObject:[NSArchiver archivedDataWithRootObject: [self graphFG2Color]] forKey: XRG_graphFG2Color];
    [defs setObject:[NSArchiver archivedDataWithRootObject: [self graphFG3Color]] forKey: XRG_graphFG3Color];
    [defs setObject:[NSArchiver archivedDataWithRootObject: [self borderColor]] forKey: XRG_borderColor];
    [defs setObject:[NSArchiver archivedDataWithRootObject: [self textColor]] forKey: XRG_textColor];
	
    [defs synchronize];
}

- (void) setBackgroundColor:(NSColor *)color {
    [backgroundColor autorelease];
    backgroundColor = [[color colorWithAlphaComponent:backgroundTransparency] retain];            
}

- (void) setGraphBGColor:(NSColor *)color {
    [graphBGColor autorelease];
    graphBGColor = [[color colorWithAlphaComponent:graphBGTransparency] retain];            
}

- (void) setGraphFG1Color:(NSColor *)color {
    [graphFG1Color autorelease];
    graphFG1Color = [[color colorWithAlphaComponent:graphFG1Transparency] retain];            
}

- (void) setGraphFG2Color:(NSColor *)color {
    [graphFG2Color autorelease];
    graphFG2Color = [[color colorWithAlphaComponent:graphFG2Transparency] retain];            
}

- (void) setGraphFG3Color:(NSColor *)color {
    [graphFG3Color autorelease];
    graphFG3Color = [[color colorWithAlphaComponent:graphFG3Transparency] retain];
}

- (void) setBorderColor:(NSColor *)color {
    [borderColor autorelease];
    borderColor = [[color colorWithAlphaComponent:borderTransparency] retain];            
}

- (void) setTextColor:(NSColor *)color {
    [textColor autorelease];
    textColor = [[color colorWithAlphaComponent:textTransparency] retain];
    alignRightAttributes[NSForegroundColorAttributeName] = textColor;
    alignCenterAttributes[NSForegroundColorAttributeName] = textColor;
    alignLeftAttributes[NSForegroundColorAttributeName] = textColor;
}

- (void) setBackgroundTransparency:(CGFloat)transparency {
    backgroundTransparency = transparency;
    self.backgroundColor = [backgroundColor colorWithAlphaComponent:transparency];
}

- (void) setGraphBGTransparency:(CGFloat)transparency {
    graphBGTransparency = transparency;
    self.graphBGColor = [graphBGColor colorWithAlphaComponent:transparency];
}

- (void) setGraphFG1Transparency:(CGFloat)transparency {
    graphFG1Transparency = transparency;
    self.graphFG1Color = [graphFG1Color colorWithAlphaComponent:transparency];
}

- (void) setGraphFG2Transparency:(CGFloat)transparency {
    graphFG2Transparency = transparency;
    self.graphFG2Color = [graphFG2Color colorWithAlphaComponent:transparency];
}

- (void) setGraphFG3Transparency:(CGFloat)transparency {
    graphFG3Transparency = transparency;
    self.graphFG3Color = [graphFG3Color colorWithAlphaComponent:transparency];
}

- (void) setBorderTransparency:(CGFloat)transparency {
    borderTransparency = transparency;
    self.borderColor = [borderColor colorWithAlphaComponent:transparency];
}

- (void) setTextTransparency:(CGFloat)transparency {
    textTransparency = transparency;
    self.textColor = [textColor colorWithAlphaComponent:transparency];
    alignRightAttributes[NSForegroundColorAttributeName] = textColor;
    alignCenterAttributes[NSForegroundColorAttributeName] = textColor;
    alignLeftAttributes[NSForegroundColorAttributeName] = textColor;
}

- (void) setGraphFont:(NSFont *)font {
    if (font == graphFont) return;
    
    if (font) {
		[graphFont autorelease];
        graphFont = [font retain];
    
        alignRightAttributes[NSFontAttributeName] = graphFont;
        alignLeftAttributes[NSFontAttributeName] = graphFont;
        alignCenterAttributes[NSFontAttributeName] = graphFont;
    
		self.textRectHeight = [[NSString stringWithFormat:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234567890%C.:%%", (unsigned short)0x00B0] sizeWithAttributes:alignRightAttributes].height;
    }
    else {
        NSLog(@"Couldn't change to a nil font.");
    }
}

@end

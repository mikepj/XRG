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
//  XRGSettings.m
//

#import "XRGSettings.h"
#import "definitions.h"

@implementation XRGSettings

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

		self.graphFont = [NSFont systemFontOfSize:10.];
		self.alignRight = [[NSParagraphStyle defaultParagraphStyle] mutableCopyWithZone: nil];
		self.alignLeft = [[NSParagraphStyle defaultParagraphStyle] mutableCopyWithZone: nil];
		self.alignCenter = [[NSParagraphStyle defaultParagraphStyle] mutableCopyWithZone: nil];
		[self.alignRight  setAlignment:NSRightTextAlignment];
		[self.alignLeft   setAlignment:NSLeftTextAlignment];
		[self.alignCenter setAlignment:NSCenterTextAlignment];
		[self.alignLeft setLineBreakMode:NSLineBreakByTruncatingMiddle];

		self.alignRightAttributes = [NSMutableDictionary dictionary];
		self.alignRightAttributes[NSFontAttributeName] = self.graphFont;
		self.alignRightAttributes[NSForegroundColorAttributeName] = [NSColor blackColor];
		self.alignRightAttributes[NSParagraphStyleAttributeName] = self.alignRight;

		self.alignLeftAttributes = [NSMutableDictionary dictionary];
		self.alignLeftAttributes[NSFontAttributeName] = self.graphFont;
		self.alignLeftAttributes[NSForegroundColorAttributeName] = [NSColor blackColor];
		self.alignLeftAttributes[NSParagraphStyleAttributeName] = self.alignLeft;

		self.alignCenterAttributes = [NSMutableDictionary dictionary];
		self.alignCenterAttributes[NSFontAttributeName] = self.graphFont;
		self.alignCenterAttributes[NSForegroundColorAttributeName] = [NSColor blackColor];
		self.alignCenterAttributes[NSParagraphStyleAttributeName] = self.alignCenter;

		self.textRectHeight = [@"A" sizeWithAttributes:self.alignRightAttributes].height;

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
        self.isDockIconHidden            = NO;
	}
	
	return self;
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
    _backgroundColor = [color colorWithAlphaComponent:self.backgroundTransparency];
}

- (void) setGraphBGColor:(NSColor *)color {
    _graphBGColor = [color colorWithAlphaComponent:self.graphBGTransparency];
}

- (void) setGraphFG1Color:(NSColor *)color {
    _graphFG1Color = [color colorWithAlphaComponent:self.graphFG1Transparency];
}

- (void) setGraphFG2Color:(NSColor *)color {
    _graphFG2Color = [color colorWithAlphaComponent:self.graphFG2Transparency];
}

- (void) setGraphFG3Color:(NSColor *)color {
    _graphFG3Color = [color colorWithAlphaComponent:self.graphFG3Transparency];
}

- (void) setBorderColor:(NSColor *)color {
    _borderColor = [color colorWithAlphaComponent:self.borderTransparency];
}

- (void) setTextColor:(NSColor *)color {
    _textColor = [color colorWithAlphaComponent:self.textTransparency];
    self.alignRightAttributes[NSForegroundColorAttributeName] = _textColor;
    self.alignCenterAttributes[NSForegroundColorAttributeName] = _textColor;
    self.alignLeftAttributes[NSForegroundColorAttributeName] = _textColor;
}

- (void) setBackgroundTransparency:(CGFloat)transparency {
    _backgroundTransparency = transparency;
    self.backgroundColor = [self.backgroundColor colorWithAlphaComponent:transparency];
}

- (void) setGraphBGTransparency:(CGFloat)transparency {
    _graphBGTransparency = transparency;
    self.graphBGColor = [self.graphBGColor colorWithAlphaComponent:transparency];
}

- (void) setGraphFG1Transparency:(CGFloat)transparency {
    _graphFG1Transparency = transparency;
    self.graphFG1Color = [self.graphFG1Color colorWithAlphaComponent:transparency];
}

- (void) setGraphFG2Transparency:(CGFloat)transparency {
    _graphFG2Transparency = transparency;
    self.graphFG2Color = [self.graphFG2Color colorWithAlphaComponent:transparency];
}

- (void) setGraphFG3Transparency:(CGFloat)transparency {
    _graphFG3Transparency = transparency;
    self.graphFG3Color = [self.graphFG3Color colorWithAlphaComponent:transparency];
}

- (void) setBorderTransparency:(CGFloat)transparency {
    _borderTransparency = transparency;
    self.borderColor = [self.borderColor colorWithAlphaComponent:transparency];
}

- (void) setTextTransparency:(CGFloat)transparency {
    _textTransparency = transparency;
    self.textColor = [self.textColor colorWithAlphaComponent:transparency];
    self.alignRightAttributes[NSForegroundColorAttributeName] = self.textColor;
    self.alignCenterAttributes[NSForegroundColorAttributeName] = self.textColor;
    self.alignLeftAttributes[NSForegroundColorAttributeName] = self.textColor;
}

- (void) setGraphFont:(NSFont *)font {
    if (font == self.graphFont) return;
    
    if (font) {
		_graphFont = font;
    
        self.alignRightAttributes[NSFontAttributeName] = self.graphFont;
        self.alignLeftAttributes[NSFontAttributeName] = self.graphFont;
        self.alignCenterAttributes[NSFontAttributeName] = self.graphFont;
    
		self.textRectHeight = [[NSString stringWithFormat:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234567890%C.:%%", (unsigned short)0x00B0] sizeWithAttributes:self.alignRightAttributes].height;
    }
    else {
        NSLog(@"Couldn't change to a nil font.");
    }
}

@end

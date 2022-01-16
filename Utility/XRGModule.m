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
//  XRGModule.m
//


#import "XRGModule.h"
#import "XRGGenericView.h"

@implementation XRGModule

+ (void) saveSizeForModule:(XRGModule *)module {
	if ([module name] == nil) return;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setFloat:[module currentSize].width forKey:[NSString stringWithFormat:@"XRGModule_%@_width", [module name]]];
	[defaults setFloat:[module currentSize].height forKey:[NSString stringWithFormat:@"XRGModule_%@_height", [module name]]];
	[defaults synchronize];
}

+ (NSSize) savedSizeForModule:(XRGModule *)module {
	if ([module name] == nil) return NSMakeSize(55.0f, 65.0f);
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	float width = [defaults floatForKey:[NSString stringWithFormat:@"XRGModule_%@_width", [module name]]];
	if (width == 0 || !isfinite(width)) width = 55.f;
	
	float height = [defaults floatForKey:[NSString stringWithFormat:@"XRGModule_%@_height", [module name]]];
	if (height == 0 || !isfinite(height)) height = 65.f;
	
	return NSMakeSize(width, height);
}

- (XRGModule *)init {
	if (self = [super init]) {
		self.name = nil;
		self.reference = nil;
		
		self.isDisplayed = YES;
		self.displayOrder = -1;
		
		self.maxHeight = 1000.0f;
		self.minHeight = 30.0f;
		self.minWidth = 30.0f;
		self.currentSize = [XRGModule savedSizeForModule:nil];
		
		self.doesMin30Update = NO;
		self.doesMin5Update = NO;
		self.doesGraphUpdate = YES;
		self.doesFastUpdate = NO;
		self.alwaysDoesGraphUpdate = NO;
		
		self.isEmptyModule = YES;
	}
	
    return self;
}

- (XRGModule *)initWithName:(NSString *)n {
	if (self = [self init]) {
		self.name = n;
		self.currentSize = [XRGModule savedSizeForModule:self];
		self.isEmptyModule = NO;
	}
	
    return self;
}

- (XRGModule *)initWithName:(NSString *)n andReference:(XRGGenericView *)r {
	if (self = [self init]) {
		self.name = n;
		self.reference = r;
		self.currentSize = [XRGModule savedSizeForModule:self];
		self.isEmptyModule = NO;
	}
	
    return self;
}

- (void)setName:(NSString *)n {
	_name = n;
	if (_name) self.isEmptyModule = NO;
}

- (void)setReference:(XRGGenericView *)r {
	_reference = r;
	if (_reference) self.isEmptyModule = NO;
}

- (void)setIsDisplayed:(BOOL)d {
    _isDisplayed = d;
    self.isEmptyModule = NO;
}

- (void)setDisplayOrder:(NSInteger)order {
    _displayOrder = order;
    self.isEmptyModule = NO;
}

- (void)setMaxHeight:(CGFloat)h {
    _maxHeight = h;
    self.isEmptyModule = NO;
}

- (void)setMinHeight:(CGFloat)h {
    _minHeight = h;
	self.isEmptyModule = NO;
}

- (void)setMinWidth:(CGFloat)w {
    _minWidth = w;
	self.isEmptyModule = NO;
}

- (void)setCurrentSize:(NSSize)newSize {
    _currentSize = newSize;
	[XRGModule saveSizeForModule:self];
	self.isEmptyModule = NO;
}

- (void)setDoesMin30Update:(BOOL)yesNo {
    _doesMin30Update = yesNo;
	self.isEmptyModule = NO;
}

- (void)setDoesMin5Update:(BOOL)yesNo {
    _doesMin5Update = yesNo;
	self.isEmptyModule = NO;
}

- (void)setDoesGraphUpdate:(BOOL)yesNo {
    _doesGraphUpdate = yesNo;
	self.isEmptyModule = NO;
}

- (void)setDoesFastUpdate:(BOOL)yesNo {
    _doesFastUpdate = yesNo;
	self.isEmptyModule = NO;
}

- (void)setAlwaysDoesGraphUpdate:(BOOL)yesNo {
    _alwaysDoesGraphUpdate = yesNo;
	self.isEmptyModule = NO;
}

@end

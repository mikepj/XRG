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
//  XRGModule.m
//


#import "XRGModule.h"


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
    name = nil;
    reference = nil;
    
    isDisplayed = YES;
    displayOrder = -1;
    
    maxHeight = 1000.0f;
    minHeight = 30.0f;
    minWidth = 30.0f;
    currentSize = [XRGModule savedSizeForModule:nil];
    
    doesMin30Update = NO;
    doesMin5Update = NO;
    doesGraphUpdate = YES;
    doesFastUpdate = NO;
    alwaysDoesGraphUpdate = NO;
    
    isEmptyModule = YES;
    
    return self;
}

- (XRGModule *)initWithName:(NSString *)n {
    if (n != nil) {
        name = [n retain];
    }
    else {
        name = nil;
    }
    reference = nil;
    
    isDisplayed = YES;
    displayOrder = -1;
    
    maxHeight = 1000.0f;
    minHeight = 30.0f;
    minWidth = 30.0f;
    currentSize = [XRGModule savedSizeForModule:self];
    
    doesMin30Update = NO;
    doesMin5Update = NO;
    doesGraphUpdate = YES;
    doesFastUpdate = NO;
    alwaysDoesGraphUpdate = NO;
    
    isEmptyModule = NO;
    
    return self;
}

- (XRGModule *)initWithName:(NSString *)n andReference:(XRGGenericView *)r {
    if (n != nil) name = [n retain];
    else          name = nil;
    
    if (r != nil) reference = [r retain];
    else          reference = nil;
    
    isDisplayed = YES;
    displayOrder = -1;
    
    maxHeight = 1000.0f;
    minHeight = 30.0f;
    minWidth = 30.0f;
    currentSize = [XRGModule savedSizeForModule:self];
    
    doesMin30Update = NO;
    doesMin5Update = NO;
    doesGraphUpdate = YES;
    doesFastUpdate = NO;
    alwaysDoesGraphUpdate = NO;
    
    isEmptyModule = NO;
    
    return self;
}

- (void)setName:(NSString *)n {
    if (name != nil) [name autorelease];
    if (n != nil) {
        name = [n retain];
        isEmptyModule = NO;
    }
    else {
        name = nil;
    }
}

- (void)setReference:(XRGGenericView *)r {
    if (reference != nil) [reference autorelease];
    if (r != nil) {
        reference = [r retain];
        isEmptyModule = NO;
    }
    else {
        reference = nil;
    }
}

- (void)setIsDisplayed:(bool)d {
    isDisplayed = d;
    
    isEmptyModule = NO;
}

- (void)setDisplayOrder:(int)order {
    displayOrder = order;
    
    isEmptyModule = NO;
}

- (void)setMaxHeight:(float)h {
    maxHeight = h;
    
    isEmptyModule = NO;
}

- (void)setMinHeight:(float)h {
    minHeight = h;
    
    isEmptyModule = NO;
}

- (void)setMinWidth:(float)w {
    minWidth = w;
    
    isEmptyModule = NO;
}

- (void)setCurrentSize:(NSSize)newSize {
    currentSize = newSize;
    
	[XRGModule saveSizeForModule:self];
	
    isEmptyModule = NO;
}

- (void)setDoesMin30Update:(bool)yesNo {
    doesMin30Update = yesNo;
    
    isEmptyModule = NO;
}

- (void)setDoesMin5Update:(bool)yesNo {
    doesMin5Update = yesNo;
    
    isEmptyModule = NO;
}

- (void)setDoesGraphUpdate:(bool)yesNo {
    doesGraphUpdate = yesNo;
    
    isEmptyModule = NO;
}

- (void)setDoesFastUpdate:(bool)yesNo {
    doesFastUpdate = yesNo;
    
    isEmptyModule = NO;
}

- (void)setAlwaysDoesGraphUpdate:(bool)yesNo {
    alwaysDoesGraphUpdate = yesNo;
    
    isEmptyModule = NO;
}

- (NSString *)name {
    return name;
}

- (XRGGenericView *)reference {
    return reference;
}

- (bool)isDisplayed {
    return isDisplayed;
}

- (int)displayOrder {
    return displayOrder;
}

- (float)maxHeight {
    return maxHeight;
}

- (float)minHeight {
    return minHeight;
}

- (float)minWidth {
    return minWidth;
}

- (NSSize)currentSize {
    return currentSize;
}

- (bool)doesMin30Update {
    return doesMin30Update;
}

- (bool)doesMin5Update {
    return doesMin5Update;
}

- (bool)doesGraphUpdate {
    return doesGraphUpdate;
}

- (bool)doesFastUpdate {
    return doesFastUpdate;
}

- (bool)alwaysDoesGraphUpdate {
    return alwaysDoesGraphUpdate;
}

- (bool)isEmptyModule {
    return isEmptyModule;
}

@end

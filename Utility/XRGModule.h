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
//  XRGModule.h
//


#import <Foundation/Foundation.h>

@class XRGGenericView;

@interface XRGModule : NSObject {
    // Identifying variables
    NSString 		*name;
    XRGGenericView	*reference;
    
    // Display variables
    bool			isDisplayed;
    int				displayOrder;
    
    // Size variables
    float			maxHeight;		
    float			minHeight;
    float			minWidth;			// none of the modules have a max width
    NSSize			currentSize;
    
    // Update variables
    bool			doesMin30Update;
    bool            doesMin5Update;
    bool			doesGraphUpdate;
    bool			doesFastUpdate;
    bool            alwaysDoesGraphUpdate;
    
    bool			isEmptyModule;
}

+ (void) saveSizeForModule:(XRGModule *)module;
+ (NSSize) savedSizeForModule:(XRGModule *)module;

- (XRGModule *)initWithName:(NSString *)n;
- (XRGModule *)initWithName:(NSString *)n andReference:(XRGGenericView *)r;

- (void)setName:(NSString *)n;
- (void)setReference:(XRGGenericView *)r;

- (void)setIsDisplayed:(bool)d;
- (void)setDisplayOrder:(int)order;

- (void)setMaxHeight:(float)h;
- (void)setMinHeight:(float)h;
- (void)setMinWidth:(float)w;
- (void)setCurrentSize:(NSSize)newSize;

- (void)setDoesMin30Update:(bool)yesNo;
- (void)setDoesMin5Update:(bool)yesNo;
- (void)setDoesGraphUpdate:(bool)yesNo;
- (void)setDoesFastUpdate:(bool)yesNo;
- (void)setAlwaysDoesGraphUpdate:(bool)yesNo;


- (NSString *)name;
- (XRGGenericView *)reference;

- (bool)isEmptyModule;

- (bool)isDisplayed;
- (int)displayOrder;

- (float)maxHeight;
- (float)minHeight;
- (float)minWidth;
- (NSSize)currentSize;

- (bool)doesMin30Update;
- (bool)doesMin5Update;
- (bool)doesGraphUpdate;
- (bool)doesFastUpdate;
- (bool)alwaysDoesGraphUpdate;

@end

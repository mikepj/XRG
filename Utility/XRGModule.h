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
//  XRGModule.h
//


#import <Foundation/Foundation.h>

@class XRGGenericView;

@interface XRGModule : NSObject
// Identifying variables
@property (nonatomic) NSString *name;
@property (nonatomic) XRGGenericView *reference;

// Display variables
@property (nonatomic) BOOL isDisplayed;
@property (nonatomic) NSInteger displayOrder;

// Size variables
@property (nonatomic) CGFloat maxHeight;
@property (nonatomic) CGFloat minHeight;
@property (nonatomic) CGFloat minWidth;			// none of the modules have a max width
@property (nonatomic) NSSize currentSize;

// Update variables
@property (nonatomic) BOOL doesMin30Update;
@property (nonatomic) BOOL doesMin5Update;
@property (nonatomic) BOOL doesGraphUpdate;
@property (nonatomic) BOOL doesFastUpdate;
@property (nonatomic) BOOL alwaysDoesGraphUpdate;

@property BOOL isEmptyModule;

+ (void) saveSizeForModule:(XRGModule *)module;
+ (NSSize) savedSizeForModule:(XRGModule *)module;

- (XRGModule *)initWithName:(NSString *)n;
- (XRGModule *)initWithName:(NSString *)n andReference:(XRGGenericView *)r;

- (void)setName:(NSString *)n;
- (void)setReference:(XRGGenericView *)r;

- (void)setIsDisplayed:(BOOL)d;
- (void)setDisplayOrder:(NSInteger)order;

- (void)setMaxHeight:(CGFloat)h;
- (void)setMinHeight:(CGFloat)h;
- (void)setMinWidth:(CGFloat)w;
- (void)setCurrentSize:(NSSize)newSize;

- (void)setDoesMin30Update:(BOOL)yesNo;
- (void)setDoesMin5Update:(BOOL)yesNo;
- (void)setDoesGraphUpdate:(BOOL)yesNo;
- (void)setDoesFastUpdate:(BOOL)yesNo;
- (void)setAlwaysDoesGraphUpdate:(BOOL)yesNo;

@end

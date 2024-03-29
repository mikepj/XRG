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
//  XRGStockView.h
//

#import <Cocoa/Cocoa.h>
#import "XRGStock.h"
#import "XRGModule.h"
#import "XRGGenericView.h"

@interface XRGStockView : XRGGenericView {
@private
    XRGModule           *m;

    NSMutableArray		*stockSymbols;
    NSMutableArray		*stockObjects;
    XRGStock			*djia;
    NSInteger			slowIncrementer;
    NSInteger			slowTime;
    NSInteger			switchIncrementer;
    NSInteger			switchTime;
    NSInteger			stockToShow;
}

@property NSSize graphSize;
@property BOOL gettingData;

- (void)updateMinSize;
- (void)ticker;
- (void)graphUpdate:(NSTimer *)aTimer;
- (void)min30Update:(NSTimer *)aTimer;
- (void)setStockSymbolsFromString:(NSString *)s;
- (void)resetStockObjects;
- (void)reloadStockData;
- (bool)dataIsReady;
- (int)convertHeight:(int) yComponent;

@end

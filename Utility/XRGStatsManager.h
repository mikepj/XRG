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
//  XRGStatsManager.h
//

#import <Foundation/Foundation.h>
#import "XRGDataSet.h"

typedef NS_ENUM(NSInteger, XRGStatsModule) {
    XRGStatsModuleNameCPU,
    XRGStatsModuleNameGPU,
    XRGStatsModuleNameMemory,
    XRGStatsModuleNameTemperature,
    XRGStatsModuleNameBattery,
    XRGStatsModuleNameDisk,
    XRGStatsModuleNameNetwork,
    XRGStatsModuleNameWeather,
    XRGStatsModuleNameStock
};

NS_ASSUME_NONNULL_BEGIN

#pragma mark - XRGStatsContentItem
@interface XRGStatsContentItem: NSObject

@property NSString *key;

@property double last;
@property double min;
@property double max;
@property double average;

- (instancetype)initWithKey:(NSString *)key initialValue:(double)initialValue;
- (void)observeStat:(double)value;

@end


#pragma mark - XRGStatsModuleContent
@interface XRGStatsModuleContent: NSObject

- (NSArray<NSString *> *)keys;

- (nullable XRGStatsContentItem *)statsForKey:(NSString *)key;
- (void)observeStat:(double)value forKey:(NSString *)key;

@end


#pragma mark - XRGStatsManager
@interface XRGStatsManager : NSObject

+ (instancetype)shared;

- (void)clearHistory;
- (void)clearHistoryForModule:(XRGStatsModule)module;

- (nullable XRGStatsContentItem *)statForKey:(NSString *)key inModule:(XRGStatsModule)module;
- (void)observeStat:(double)value forKey:(NSString *)key inModule:(XRGStatsModule)module;

@end

NS_ASSUME_NONNULL_END

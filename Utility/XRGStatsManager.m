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
//  XRGStatsManager.m
//

#import "XRGStatsManager.h"

#pragma mark - XRGStatsManager
@interface XRGStatsManager ()

@property NSDictionary<NSString *, XRGStatsModuleContent *> *modulesContent;

@end

@implementation XRGStatsManager

+ (NSString *)nameOfModule:(XRGStatsModule)module {
    switch (module) {
        case XRGStatsModuleNameCPU:
            return @"XRG_CPU";

        case XRGStatsModuleNameGPU:
            return @"XRG_GPU";

        case XRGStatsModuleNameMemory:
            return @"XRG_Memory";

        case XRGStatsModuleNameTemperature:
            return @"XRG_Temperature";

        case XRGStatsModuleNameBattery:
            return @"XRG_Battery";

        case XRGStatsModuleNameDisk:
            return @"XRG_Disk";

        case XRGStatsModuleNameNetwork:
            return @"XRG_Network";

        case XRGStatsModuleNameWeather:
            return @"XRG_Weather";

        case XRGStatsModuleNameStock:
            return @"XRG_Stock";
            
    }
}

+ (instancetype)shared {
    static XRGStatsManager *sharedManager = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[XRGStatsManager alloc] init];
    });

    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.modulesContent = [NSDictionary dictionary];
    }
    return self;
}

- (void)clearHistory {
    self.modulesContent = [NSDictionary dictionary];
}

- (void)clearHistoryForModule:(XRGStatsModule)module {
    NSString *moduleName = [XRGStatsManager nameOfModule:module];

    NSMutableDictionary *newStats = [self.modulesContent mutableCopy];
    [newStats removeObjectForKey:moduleName];
    self.modulesContent = newStats;
}

- (XRGStatsContentItem *)statForKey:(NSString *)key inModule:(XRGStatsModule)module {
    return [[self contentForModule:module] statsForKey:key];
}

- (void)observeStat:(double)value forKey:(NSString *)key inModule:(XRGStatsModule)module {
    [[self contentForModule:module] observeStat:value forKey:key];
}

- (XRGStatsModuleContent *)contentForModule:(XRGStatsModule)module {
    NSString *moduleName = [XRGStatsManager nameOfModule:module];

    XRGStatsModuleContent *content = self.modulesContent[moduleName];
    if (content) return content;

    XRGStatsModuleContent *newContent = [[XRGStatsModuleContent alloc] init];

    NSMutableDictionary *newModulesContent = [self.modulesContent mutableCopy];
    newModulesContent[moduleName] = newContent;
    self.modulesContent = newModulesContent;

    return newContent;
}

@end


#pragma mark - XRGStatsModuleContent
@interface XRGStatsModuleContent ()

@property NSDictionary<NSString *, XRGStatsContentItem *> *items;

@end

@implementation XRGStatsModuleContent: NSObject

- (instancetype)init {
    self = [super init];
    if (self) {
        self.items = [NSDictionary dictionary];
    }
    return self;
}

- (NSArray<NSString *> *)keys {
    return self.items.allKeys;
}

- (nullable XRGStatsContentItem *)statsForKey:(NSString *)key {
    return self.items[key];
}

- (void)observeStat:(double)value forKey:(NSString *)key {
    XRGStatsContentItem *item = [self statItemForKey:key initialValue:value];

    [item observeStat:value];
}

#pragma mark Private
- (XRGStatsContentItem *)statItemForKey:(NSString *)key initialValue:(double)initialValue {
    XRGStatsContentItem *existingItem = self.items[key];
    if (existingItem) return existingItem;

    XRGStatsContentItem *newItem = [[XRGStatsContentItem alloc] initWithKey:key initialValue:initialValue];

    NSMutableDictionary *newItems = [self.items mutableCopy];
    newItems[key] = newItem;
    self.items = newItems;

    return newItem;
}

@end


#pragma mark - XRGStatsContentItem
@interface XRGStatsContentItem ()
@property NSUInteger statsObservedCount;
@end

@implementation XRGStatsContentItem

- (instancetype)initWithKey:(NSString *)key initialValue:(double)initialValue {
    self = [super init];
    if (self) {
        self.key = key;
        self.last = initialValue;
        self.min = initialValue;
        self.max = initialValue;
        self.average = initialValue;
        self.statsObservedCount = 1;
    }
    return self;
}

- (void)observeStat:(double)value {
    if (value < self.min) {
        self.min = value;
    }
    if (value > self.max) {
        self.max = value;
    }

    self.average = (self.average * self.statsObservedCount + value) / (self.statsObservedCount + 1);
    self.statsObservedCount++;

    self.last = value;
}

@end

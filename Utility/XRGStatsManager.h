//
//  XRGStatsManager.h
//  XRG
//
//  Created by Mike Piatek-Jimenez on 11/3/20.
//  Copyright © 2020 Gaucho Software. All rights reserved.
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

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
//  XRGStock.m
//

#import "XRGStock.h"
#include <regex.h>
#include <sys/types.h>

@implementation XRGStock

- (instancetype)init {
	self = [super init];
	
	if (self) {
		_symbol = nil;
		_label = nil;

        _closingPrices = nil;
        
		_currentPrice = 0;
		_lastChange = 0;
		_highWeekPrice = 0;
		_lowWeekPrice = 0;
		
		_gettingData = NO;
		_haveGoodURL = NO;
		_haveGoodStockArray = NO;
		_haveGoodDisplayData = NO;
	}
    
    return self;
}

- (void)setSymbol:(NSString *)s {
    if ([s isEqualToString:@""]) return;
    if (s != nil) {
        _label = s;
        
        NSMutableString *ms = [NSMutableString stringWithString:s];
        [ms replaceOccurrencesOfString:@"^" withString:@"%5E" options:NSLiteralSearch range:NSMakeRange(0, [ms length])];
    
        _symbol = ms;
        
        [self setURL];
    }
}

- (void)setURL {
    self.haveGoodURL = NO;
    if (self.symbol == nil) return;
                                                                        
    NSString *URLString = [NSString stringWithFormat:@"https://query1.finance.yahoo.com/v7/finance/chart/%@?range=1y&interval=1d&indicators=quote&includeTimestamps=true", self.symbol];
    self.sURL = [NSURL URLWithString:URLString];
	
	NSString *immediateURLString = [NSString stringWithFormat:@"https://query1.finance.yahoo.com/v8/finance/chart/%@?region=US&lang=en-US&includePrePost=false&interval=15m&range=1d", self.symbol];
    self.immediateURL = [NSURL URLWithString:immediateURLString];

	if (self.sURL && self.immediateURL) self.haveGoodURL = YES;

    self.gettingData = NO;
    
    [self loadData];
}

- (void)resetData {
    self.haveGoodStockArray = NO;
    self.haveGoodDisplayData = NO;
    
    self.closingPrices = nil;
    
    self.currentPrice = 0;
    self.highWeekPrice = 0;
    self.lowWeekPrice = 0;
    
    self.gettingData = NO;
}

- (void)loadData {
    if (!self.haveGoodURL) {
        self.haveGoodStockArray = NO;
        self.haveGoodDisplayData = NO;
        return;
    }
    
    self.gettingData = YES;
    [[[NSURLSession sharedSession] dataTaskWithURL:self.sURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [self parseWebData:data];
        
        [self checkIfFinished];
    }] resume];
    
    [[[NSURLSession sharedSession] dataTaskWithURL:self.immediateURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [self parseImmediateData:data];
        
        [self checkIfFinished];
    }] resume];
}

- (void)checkIfFinished {
    if ((self.closingPrices.count > 0) || ((self.currentPrice != 0) && (self.lastChange != 0))) {
        self.haveGoodStockArray = YES;
        self.haveGoodDisplayData = YES;
        self.gettingData = NO;
    }
    else {
        self.haveGoodStockArray = NO;
        self.haveGoodDisplayData = NO;
        self.gettingData = NO;
    }
}

- (void)parseWebData:(NSData *)data {
    if (!data) return;

    NSError *error = nil;
    id jsonObject = nil;
    
    @try {
        jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    }
    @catch (NSException *) {
        return;
    }

    if (error) return;
    if (![jsonObject isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *jsonD = jsonObject;
    
    id chart = jsonD[@"chart"];
    if (![chart isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *chartD = chart;
    
    id result = chartD[@"result"];
    if (![result isKindOfClass:[NSArray class]]) return;
    NSArray *resultA = result;
    
    id firstResult = [resultA firstObject];
    if (![firstResult isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *firstResultD = firstResult;
    
    id indicators = firstResultD[@"indicators"];
    if (![indicators isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *indicatorsD = indicators;
    
    id quote = indicatorsD[@"quote"];
    if (![quote isKindOfClass:[NSArray class]]) return;
    NSArray *quoteA = quote;
    
    id firstQuote = [quoteA firstObject];
    if (![firstQuote isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *firstQuoteD = firstQuote;
    
    id close = firstQuoteD[@"close"];
    if (![close isKindOfClass:[NSArray class]]) return;
    NSArray *closeA = close;
    
    NSMutableArray<NSNumber *> *newClosingPrices = [NSMutableArray array];
    for (id closingPrice in closeA) {
        if ([closingPrice isKindOfClass:[NSNumber class]]) {
            [newClosingPrices addObject:(NSNumber *)closingPrice];
        }
    }
    self.closingPrices = [NSArray arrayWithArray:newClosingPrices];
}

- (void)parseImmediateData:(NSData *)data {
    if (!data) return;
    
    NSError *error = nil;
    id jsonObject = nil;
    
    @try {
        jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    }
    @catch (NSException *) {
        return;
    }

    if (error) return;
    if (![jsonObject isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *jsonD = jsonObject;
    
    id chart = jsonD[@"chart"];
    if (![chart isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *chartD = chart;
    
    id result = chartD[@"result"];
    if (![result isKindOfClass:[NSArray class]]) return;
    NSArray *resultA = result;
    
    id firstResult = [resultA firstObject];
    if (![firstResult isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *firstResultD = firstResult;
    
    id meta = firstResultD[@"meta"];
    if (![meta isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *metaD = meta;
    
    self.currentPrice = [metaD[@"regularMarketPrice"] floatValue];
    CGFloat previousClose = [metaD[@"previousClose"] floatValue];
    self.lastChange = self.currentPrice - previousClose;
}

- (BOOL)errorOccurred {
    return (!self.gettingData && self.haveGoodDisplayData);
}

- (nullable NSArray<NSNumber *> *)get1MonthValues {
	return [self getValuesForDays:self.closingPrices.count / 12];
}

- (nullable NSArray<NSNumber *> *)get3MonthValues {
	return [self getValuesForDays:self.closingPrices.count / 4];
}

- (nullable NSArray<NSNumber *> *)get6MonthValues {
	return [self getValuesForDays:self.closingPrices.count / 2];
}

- (nullable NSArray<NSNumber *> *)get12MonthValues {
	return [self getValuesForDays:self.closingPrices.count];
}

- (nullable NSArray<NSNumber *> *)getValuesForDays:(NSInteger)daysCount {
	if (!self.haveGoodDisplayData) return nil;
	
	NSInteger numClosingPrices = self.closingPrices.count;
    if (daysCount > numClosingPrices) return self.closingPrices;
    
    return [self.closingPrices subarrayWithRange:NSMakeRange(numClosingPrices - daysCount, daysCount)];
}

- (NSArray *)getCurrentPriceAndChange {
    if (!self.haveGoodDisplayData) return nil;
    if (self.closingPrices.count < 2) return nil;
    
    NSMutableArray *retvals = [NSMutableArray arrayWithCapacity:2];
	if ((self.currentPrice == 0) || (self.currentPrice == HUGE_VAL) || (self.currentPrice == -HUGE_VAL) || (self.lastChange == HUGE_VAL) || (self.lastChange == -HUGE_VAL)) {
        NSInteger closingPriceCount = self.closingPrices.count;
        
		[retvals addObject:self.closingPrices[closingPriceCount - 1]];
		[retvals addObject:@([self.closingPrices[closingPriceCount - 1] floatValue] - [self.closingPrices[closingPriceCount - 2] floatValue])];
	}
	else {
		[retvals addObject:@(self.currentPrice)];
		[retvals addObject:@(self.lastChange)];
	}
    
    return retvals;
}

- (NSString *)priceString {
    NSArray *a = [self getCurrentPriceAndChange];
    if (a != nil) {
        if ([a[0] intValue] == 0) {
            return @"n/a";
        }
        else {
            return [NSString stringWithFormat:@"$%2.2f", [a[0] floatValue]];
        }
    }
    else {  // there isn't good pricing info for this stock
        return @"n/a";
    }
}

- (NSString *)changeString {
    NSArray *a = [self getCurrentPriceAndChange];
    if (a != nil) {
        CGFloat change = [a[1] floatValue];
        if (change == 0) {
            return @"unch";
        }
        else if (change > 0) {
            return [NSString stringWithFormat:@"%C%2.2f", (unsigned short)0x25B2, change];
        }
        else { // change < 0
            return [NSString stringWithFormat:@"%C%2.2f", (unsigned short)0x25BC, change * -1];
        }
    }
    else {  // there isn't good pricing info for this stock
        return @"n/a";
    }
}

@end

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

		_closingPrices = [NSMutableArray arrayWithCapacity:160];
		_volumes = [NSMutableArray arrayWithCapacity:160];
		
		_currentPrice = 0;
		_lastChange = 0;
		_highWeekPrice = 0;
		_lowWeekPrice = 0;
		
		_surl = [[XRGURL alloc] init];
		_immediateURL = [[XRGURL alloc] init];
		
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
        self.label = s;
        
        NSMutableString *ms = [NSMutableString stringWithString:s];
        [ms replaceOccurrencesOfString:@"^" withString:@"%5E" options:NSLiteralSearch range:NSMakeRange(0, [ms length])];
    
        _symbol = ms;
    }
}

- (void)setURL {
    NSInteger a, b, c, d, e, f; // to match the url parameters below
    NSCalendarDate *today = [NSCalendarDate calendarDate];
    NSCalendarDate *lastYear = [[NSCalendarDate calendarDate] dateByAddingYears:-1 
                                                                         months:0 
                                                                           days:0 
                                                                          hours:0 
                                                                        minutes:0 
                                                                        seconds:0]; 
                                                                        
    self.haveGoodURL = NO;
    if (self.symbol == nil) return;
                                                                        
    a = [lastYear monthOfYear] - 1;
    b = [lastYear dayOfMonth];
    c = [lastYear yearOfCommonEra];
    d = [today monthOfYear] - 1;
    e = [today dayOfMonth];
    f = [today yearOfCommonEra];
        
    // http://table.finance.yahoo.com/table.csv?a=5&b=24&c=2002&d=0&e=25&f=2003&s=aapl&y=0&g=d&ignore=.csv
    // a = from month (0-11)
    // b = from day
    // c = from year
    // d = to month (0-11)
    // e = to day
    // f = to year
    // s = stock symbol
    // y = 0 (static)
    // g = d/w/m/v  daily, weekly, monthly, dividends
    NSString *URLString = [NSString stringWithFormat:@"http://itable.finance.yahoo.com/table.csv?a=%ld&b=%ld&c=%ld&d=%ld&e=%ld&f=%ld&y=0&g=d&ignore=.csv&s=%@", (long)a, (long)b, (long)c, (long)d, (long)e, (long)f, self.symbol];
    [self.surl setURLString: URLString];
	
	NSString *immediateURLString = [NSString stringWithFormat:@"http://download.finance.yahoo.com/d/quotes.csv?s=%@&f=sl1d1t1c1ohgv&e=.csv", self.symbol];
	[self.immediateURL setURLString:immediateURLString];

	if ([self.surl haveGoodURL] && [self.immediateURL haveGoodURL]) self.haveGoodURL = YES;

    self.gettingData = NO;
}

- (void)resetData {
    if (self.surl != nil) [self.surl cancelLoading];
    
    self.haveGoodStockArray = NO;
    self.haveGoodDisplayData = NO;
    
    [self.closingPrices removeAllObjects];
    [self.volumes removeAllObjects];
    
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
    [self.surl loadURLInBackground];
	[self.immediateURL loadURLInBackground];
}

- (void)checkForData {
    if (self.gettingData == NO) return;
    if (self.surl == nil) {
        self.haveGoodStockArray = NO;
        self.haveGoodDisplayData = NO;
        self.gettingData = NO;
        return;
    }
    if ([self.surl didErrorOccur]) {
        self.haveGoodStockArray = NO;
        self.haveGoodDisplayData = NO;
        [self.surl cancelLoading];
        self.gettingData = NO;
        return;
    }
    
    if ([self.surl isDataReady] && [self.immediateURL isDataReady]) {
        NSString *s = [[NSString alloc] initWithData:[self.surl getData] encoding:NSASCIIStringEncoding];
        [self parseWebData:s];
		
		NSString *immediateString = [[NSString alloc] initWithData:[self.immediateURL getData] encoding:NSASCIIStringEncoding];
		NSArray *elements = [immediateString componentsSeparatedByString:@","];
		if ([elements count] >= 5) {			// ^DJI (and probably some others) won't return immediate data, so catch that case here.
			self.currentPrice = [elements[1] floatValue];
			self.lastChange = [elements[4] floatValue];
		}
		
		[self.surl setData:nil];
		[self.immediateURL setData:nil];
		
        if (((self.closingPrices.count > 0) && (self.volumes.count > 0)) || ((self.currentPrice != 0) && (self.lastChange != 0))) {
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
}

- (void)parseWebData:(NSString *)webData {
	int i;
	
    [self.closingPrices removeAllObjects];
    [self.volumes removeAllObjects];

	NSArray *lines = [webData componentsSeparatedByString:@"\n"];
	for (i = 1; i < [lines count]; i++) {		// Skip the first line containing the column headers.
		NSString *line = lines[i];
		NSArray *lineElements = [line componentsSeparatedByString:@","];
		if ([lineElements count] >= 7) {
			[self.closingPrices addObject:@([lineElements[6] floatValue])];
			[self.volumes addObject:@([lineElements[5] intValue])];
		}
	}
	
	NSInteger count = self.closingPrices.count;
	if (count > 0) {
		float high, low;
		high = [self.closingPrices[0] floatValue];
		low = [self.closingPrices[0] floatValue];
		
		for (i = 1; i < count; i++) {
			float val = [self.closingPrices[i] floatValue];
			high = MAX(val, high);
			low = MIN(val, low);
		}
		
		self.highWeekPrice = high;
		self.lowWeekPrice = low;
	}
}

- (BOOL)errorOccurred {
    return (!self.gettingData && self.haveGoodDisplayData);
}

- (NSArray *)get1MonthValues:(int)max {
	return [self getValuesForDays:self.closingPrices.count / 12 max:max];
}

- (NSArray *)get3MonthValues:(int)max {
	return [self getValuesForDays:self.closingPrices.count / 4 max:max];
}

- (NSArray *)get6MonthValues:(int)max {
	return [self getValuesForDays:self.closingPrices.count / 2 max:max];
}

- (NSArray *)get12MonthValues:(int)max {
	return [self getValuesForDays:self.closingPrices.count max:max];
}

- (NSArray *)getValuesForDays:(NSInteger)daysCount max:(NSInteger)max {
	if (!self.haveGoodDisplayData) return nil;
	
	NSInteger numClosingPrices = self.closingPrices.count;
	NSInteger baseIndex = MAX(numClosingPrices - 1 - daysCount, 0);
	NSMutableArray *retvals = [NSMutableArray array];
	
	if (max > numClosingPrices - baseIndex) {
		[retvals addObjectsFromArray:[self.closingPrices subarrayWithRange:NSMakeRange(0, daysCount)]];
	}
	else {
		for (NSInteger i = 0; i < max; i++) {
			[retvals addObject:self.closingPrices[(baseIndex + (int)((float)i / (float)max * (numClosingPrices - 1 - baseIndex)))]];
		}
	}
	
	return retvals;
}

- (NSArray *)getCurrentPriceAndChange {
    if (!self.haveGoodDisplayData) return nil;
    
    NSMutableArray *retvals = [NSMutableArray arrayWithCapacity:2];
	if ((self.currentPrice == 0) || (self.currentPrice == HUGE_VAL) || (self.currentPrice == -HUGE_VAL) || (self.lastChange == HUGE_VAL) || (self.lastChange == -HUGE_VAL)) {
		[retvals addObject:self.closingPrices[0]];
		[retvals addObject:@([self.closingPrices[0] floatValue] - [self.closingPrices[1] floatValue])];
	}
	else {
		[retvals addObject:@(self.currentPrice)];
		[retvals addObject:@(self.lastChange)];
	}
    
    return retvals;
}

@end

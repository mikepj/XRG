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

- (id)init {
    symbol = nil;
    label = nil;

    closingPrices = [[NSMutableArray arrayWithCapacity:160] retain];
    volumes = [[NSMutableArray arrayWithCapacity:160] retain];
    
	currentPrice = 0;
	lastChange = 0;
    highWeekPrice = 0;
    lowWeekPrice = 0;
    
    surl = [[XRGURL alloc] init];
	immediateURL = [[XRGURL alloc] init];
    
    gettingData = NO;
    haveGoodURL = NO;
    haveGoodStockArray = NO;
    haveGoodDisplayData = NO;
    
    return self;
}

- (void)dealloc {
	[closingPrices release]; closingPrices = nil;
	[volumes release]; volumes = nil;
	
	[surl release]; surl = nil;
	[immediateURL release]; immediateURL = nil;
	
	[symbol release]; symbol = nil;
	[label release]; label = nil;
	
	[super dealloc];
}

- (void)setSymbol:(NSString *)s {
    if ([s isEqualToString:@""]) return;
    if (symbol != nil) {
        [symbol autorelease];
		symbol = nil;
    }
    if (label != nil) {
        [label autorelease];
		label = nil;
    }
    
    if (s != nil) {
        label = [s retain];
        
        NSMutableString *ms = [NSMutableString stringWithString:s];
        [ms replaceOccurrencesOfString:@"^" withString:@"%5E" options:NSLiteralSearch range:NSMakeRange(0, [ms length])];
    
        symbol = [ms retain];
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
                                                                        
    haveGoodURL = NO;
    if (symbol == nil) return;
                                                                        
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
    NSString *URLString = [NSString stringWithFormat:@"http://itable.finance.yahoo.com/table.csv?a=%d&b=%d&c=%d&d=%d&e=%d&f=%d&y=0&g=d&ignore=.csv&s=%@", a, b, c, d, e, f, symbol];
    [surl setURLString: URLString];
	
	NSString *immediateURLString = [NSString stringWithFormat:@"http://download.finance.yahoo.com/d/quotes.csv?s=%@&f=sl1d1t1c1ohgv&e=.csv", symbol];
	[immediateURL setURLString:immediateURLString];

    if ([surl haveGoodURL] && [immediateURL haveGoodURL]) haveGoodURL = YES;

    gettingData = NO;
}

- (void)resetData {
    if (surl != nil) [surl cancelLoading];
    
    haveGoodStockArray = NO;
    haveGoodDisplayData = NO;
    
    [closingPrices removeAllObjects];
    [volumes removeAllObjects];
    
    currentPrice = 0;
    highWeekPrice = 0;
    lowWeekPrice = 0;
    
    gettingData = NO;
}

- (void)loadData {
    if (!haveGoodURL) {
        haveGoodStockArray = NO;
        haveGoodDisplayData = NO;
        return;
    }
    
    gettingData = YES;
    [surl loadURLInBackground];
	[immediateURL loadURLInBackground];
}

- (void)checkForData {
    if (gettingData == NO) return;
    if (surl == nil) {
        haveGoodStockArray = NO;
        haveGoodDisplayData = NO;
        gettingData = NO;
        return;
    }
    if ([surl didErrorOccur]) {
        haveGoodStockArray = NO;
        haveGoodDisplayData = NO;
        [surl cancelLoading];
        gettingData = NO;
        return;
    }
    
    if ([surl isDataReady] && [immediateURL isDataReady]) {
        NSString *s = [[NSString alloc] initWithData:[surl getData] encoding:NSASCIIStringEncoding];
        [self parseWebData:s];
		[s release];
		
		NSString *immediateString = [[[NSString alloc] initWithData:[immediateURL getData] encoding:NSASCIIStringEncoding] autorelease];
		NSArray *elements = [immediateString componentsSeparatedByString:@","];
		if ([elements count] >= 5) {			// ^DJI (and probably some others) won't return immediate data, so catch that case here.
			currentPrice = [[elements objectAtIndex:1] floatValue];
			lastChange = [[elements objectAtIndex:4] floatValue];
		}
		
		[surl setData:nil];
		[immediateURL setData:nil];
		
        if ((([closingPrices count] > 0) && ([volumes count] > 0)) || ((currentPrice != 0) && (lastChange != 0))) {
            haveGoodStockArray = YES;
            haveGoodDisplayData = YES;
            gettingData = NO;
        }
        else {
            haveGoodStockArray = NO;
            haveGoodDisplayData = NO;
            gettingData = NO;
        }
    }
}

- (void)parseWebData:(NSString *)webData {
	int i;
	
    [closingPrices removeAllObjects];
    [volumes removeAllObjects];

	NSArray *lines = [webData componentsSeparatedByString:@"\n"];
	for (i = 1; i < [lines count]; i++) {		// Skip the first line containing the column headers.
		NSString *line = [lines objectAtIndex:i];
		NSArray *lineElements = [line componentsSeparatedByString:@","];
		if ([lineElements count] >= 7) {
			[closingPrices addObject:[NSNumber numberWithFloat:[[lineElements objectAtIndex:6] floatValue]]];
			[volumes addObject:[NSNumber numberWithInt:[[lineElements objectAtIndex:5] intValue]]];
		}
	}
	
	NSInteger count = [closingPrices count];
	if (count > 0) {
		float high, low;
		high = [[closingPrices objectAtIndex:0] floatValue];
		low = [[closingPrices objectAtIndex:0] floatValue];
		
		for (i = 1; i < count; i++) {
			float val = [[closingPrices objectAtIndex:i] floatValue];
			high = MAX(val, high);
			low = MIN(val, low);
		}
		
		highWeekPrice = high;
		lowWeekPrice = low;
	}
}

- (float)currentPrice {
    return currentPrice;
}

- (float)highWeekPrice {
    return highWeekPrice;
}

- (float)lowWeekPrice {
    return lowWeekPrice;
}

- (bool)haveGoodDisplayData {
    return haveGoodDisplayData;
}

- (bool)gettingData {
    return gettingData;
}

- (bool)errorOccurred {
    return (!gettingData && haveGoodDisplayData);
}

- (NSArray *)closingPrices {
    return closingPrices;
}

- (NSArray *)volumes {
    return volumes;
}

- (NSArray *)get1MonthValues:(int)max {
    if (!haveGoodDisplayData) return nil;

    NSInteger i;
	NSInteger numClosingPrices = [closingPrices count];
    NSInteger baseIndex = numClosingPrices * (float)(11./12.);
    NSMutableArray *retvals = [NSMutableArray arrayWithCapacity:max];

    if (max > numClosingPrices - baseIndex) {
        for (i = 0; i < numClosingPrices - 1 - baseIndex; i++) {
            [retvals addObject:[closingPrices objectAtIndex:i]];
        }
    }
    else {
        for (i = 0; i < max; i++) {
            [retvals addObject:[closingPrices objectAtIndex:(baseIndex + ((float)i / (float)max * (numClosingPrices - 1 - baseIndex)))]];
        }
    }

    return retvals;
}

- (NSArray *)get3MonthValues:(int)max {
    if (!haveGoodDisplayData) return nil;

    NSInteger i;
	NSInteger numClosingPrices = [closingPrices count];
    NSInteger baseIndex = numClosingPrices * (float)(3./4.);
    NSMutableArray *retvals = [NSMutableArray arrayWithCapacity:max];

    if (max > numClosingPrices - baseIndex) {
        for (i = 0; i < numClosingPrices - 1 - baseIndex; i++) {
            [retvals addObject:[closingPrices objectAtIndex:i]];
        }
    }
    else {
        for (i = 0; i < max; i++) {
            [retvals addObject:[closingPrices objectAtIndex:(baseIndex + ((float)i / (float)max * (numClosingPrices - 1 - baseIndex)))]];
        }
    }

    return retvals;
}

- (NSArray *)get6MonthValues:(int)max {
    if (!haveGoodDisplayData) return nil;

    NSInteger i;
	NSInteger numClosingPrices = [closingPrices count];
    NSInteger baseIndex = numClosingPrices / 2;
    NSMutableArray *retvals = [NSMutableArray arrayWithCapacity:max];

    if (max > numClosingPrices - baseIndex) {
        for (i = 0; i < numClosingPrices - 1 - baseIndex; i++) {
            [retvals addObject:[closingPrices objectAtIndex:i]];
        }
    }
    else {
        for (i = 0; i < max; i++) {
            [retvals addObject:[closingPrices objectAtIndex:(baseIndex + ((float)i / (float)max * (numClosingPrices - 1 - baseIndex)))]];
        }
    }

    return retvals;
}

- (NSArray *)get12MonthValues:(int)max {
    if (!haveGoodDisplayData) return nil;

    NSInteger i;
	NSInteger numClosingPrices = [closingPrices count];
    NSInteger baseIndex = 0;
    NSMutableArray *retvals = [NSMutableArray arrayWithCapacity:max];

    if (max > numClosingPrices - baseIndex) {
        for (i = 0; i < numClosingPrices - 1 - baseIndex; i++) {
            [retvals addObject:[closingPrices objectAtIndex:i]];
        }
    }
    else {
        for (i = 0; i < max; i++) {
            [retvals addObject:[closingPrices objectAtIndex:(baseIndex + ((float)i / (float)max * (float)(numClosingPrices - 1 - baseIndex)))]];
        }
    }

    return retvals;
}

- (NSArray *)getCurrentPriceAndChange {
    if (!haveGoodDisplayData) return nil;
    
    NSMutableArray *retvals = [NSMutableArray arrayWithCapacity:2];
	if (currentPrice == 0 || currentPrice == HUGE_VAL || currentPrice == -HUGE_VAL || lastChange == HUGE_VAL || lastChange == -HUGE_VAL) {
		[retvals addObject:[closingPrices objectAtIndex:0]];
		[retvals addObject:[NSNumber numberWithFloat:[[closingPrices objectAtIndex:0] floatValue] - [[closingPrices objectAtIndex:1] floatValue]]];
	}
	else {
		[retvals addObject:[NSNumber numberWithFloat:currentPrice]];
		[retvals addObject:[NSNumber numberWithFloat:lastChange]];
	}
    
    return retvals;
}

- (NSString *)symbol {
    return symbol;
}

- (NSString *)label {
    return label;
}

@end

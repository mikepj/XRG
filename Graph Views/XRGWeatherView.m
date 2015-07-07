/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2012 Gaucho Software, LLC.
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
//  XRGWeatherView.m
//

#import "XRGWeatherView.h"
#import "XRGGraphWindow.h"
#import "NSStringUtil.h"
#include <stdio.h>
#include <regex.h>
#include <math.h>
#include <unistd.h>

@implementation XRGWeatherView

- (void)awakeFromNib {  
    parentWindow = (XRGGraphWindow *)[self window];
    [parentWindow setWeatherView:self];
    [parentWindow initTimers];  
    appSettings = [parentWindow appSettings];
    moduleManager = [parentWindow moduleManager];

    gettingData          = NO;
    processing           = NO;
    haveGoodURL          = NO;
    haveGoodMETARArray   = NO;
    haveGoodDisplayData  = NO;
    stationName = @"";
    metarArray = [NSMutableArray arrayWithCapacity:30];
    secondaryGraphLowerBound = 0;
    
    STATION_WIDE       = 0;
    TEMPERATURE_WIDE   = 0;
    TEMPERATURE_NORMAL = 0;
    TEMPERATURE_SMALL  = 0;
    HL_WIDE            = 0;
    WIND_WIDE          = 0;
    WIND_NORMAL        = 0;
    WIND_SMALL         = 0;
    HUMIDITY_WIDE      = 0;
    HUMIDITY_NORMAL    = 0;
    VISIBILITY_WIDE    = 0;
    DEWPOINT_WIDE      = 0;
    PRESSURE_WIDE      = 0;
    PRESSURE_NORMAL    = 0;
    
    wurl1 = [[XRGURL alloc] init];
    wurl2 = [[XRGURL alloc] init];
    [self setURL:[appSettings ICAO]];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];    
    m = [[XRGModule alloc] initWithName:@"Weather" andReference:self];
    m.doesFastUpdate = NO;
    m.doesGraphUpdate = YES;
    m.doesMin5Update = NO;
    m.doesMin30Update = YES;
    m.displayOrder = 7;
    [self updateMinSize];
    m.isDisplayed = [defs boolForKey:XRG_showWeatherGraph];

    [[parentWindow moduleManager] addModule:m];
    [self setGraphSize:[m currentSize]];

    shortTemp       = @"T:";
    longTemp        = @"Temp:";
    shortHL         = @"H/L:";
    longHL          = @"High/Low:";
    shortWind       = @"W:";
    longWind        = @"Wind:";
    shortHumidity   = @"RH:";
    longHumidity    = @"Rel Humidity:";
    shortVisibility = @"Vis:";
    longVisibility  = @"Visibility:";
    shortDewpoint   = @"Dpt:";
    longDewpoint    = @"Dewpoint:";
    shortPressure   = @"Pr:";
    longPressure    = @"Pressure:";
    
    // show the first set of data if this module is being displayed
    if ([m isDisplayed]) [parentWindow min30Update:nil];
	
	[NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(ticker) userInfo:nil repeats:YES];
}

- (void)setGraphSize:(NSSize)newSize {
    graphSize = newSize;
}

- (void)updateMinSize {
    NSMutableDictionary *textAttributes = [appSettings alignRightAttributes];

    float width, height;
    height = [appSettings textRectHeight] * 2;
    width = [@"H/L:199/99" sizeWithAttributes:textAttributes].width + 6;
    
    [m setMinWidth: width];
    [m setMinHeight: height];
    
    // Update the text width cache.
    STATION_WIDE       = [@"Station: WWWW" sizeWithAttributes:textAttributes].width;	
	
    TEMPERATURE_WIDE   = [[NSString stringWithFormat:@"Current Temperature: 99.9%CC", (unsigned short)0x00B0] sizeWithAttributes:textAttributes].width;
    TEMPERATURE_NORMAL = [[NSString stringWithFormat:@"Temperature: 99.9%CC", (unsigned short)0x00B0] sizeWithAttributes:textAttributes].width;
    TEMPERATURE_SMALL  = [[NSString stringWithFormat:@"Temp: 99.9%CC", (unsigned short)0x00B0] sizeWithAttributes:textAttributes].width;
                           
    HL_WIDE            = [[NSString stringWithFormat:@"High/Low: 99.9%CC/99.9%CC", (unsigned short)0x00B0, (unsigned short)0x00B0] sizeWithAttributes:textAttributes].width;

    WIND_WIDE          = [@"Wind: WSW 99 Gusts: 99" sizeWithAttributes:textAttributes].width;
    WIND_NORMAL        = [@"Wind: WSW 99 G: 99" sizeWithAttributes:textAttributes].width;
    WIND_SMALL         = [@"Wind: WSW 99" sizeWithAttributes:textAttributes].width;

    HUMIDITY_WIDE      = [@"Relative Humidity: 100%" sizeWithAttributes:textAttributes].width;
    HUMIDITY_NORMAL    = [@"Rel Humidity: 100%" sizeWithAttributes:textAttributes].width;
                       
    VISIBILITY_WIDE    = [@"Visibility: 99 km" sizeWithAttributes:textAttributes].width;

    DEWPOINT_WIDE      = [[NSString stringWithFormat:@"Dewpoint: 99.9%CC", (unsigned short)0x00B0] sizeWithAttributes:textAttributes].width;

    PRESSURE_WIDE      = [@"Barometric Pressure: 1999hPa" sizeWithAttributes:textAttributes].width;
    PRESSURE_NORMAL    = [@"Pressure: 1999hPa" sizeWithAttributes:textAttributes].width;
}

- (void)setURL:(NSString *)icao {
    if ([icao isEqualToString: stationName] && haveGoodMETARArray) {
        return;
    }

    haveGoodURL          = NO;
    haveGoodMETARArray   = NO;
    haveGoodDisplayData  = NO;

    stationName = [icao uppercaseString];
    NSString *URLString1 = @"http://adds.aviationweather.gov/metars/index.php?submit=1&chk_metars=on&hoursStr=24&station_ids=";
    //NSString *URLString1 = @"http://www.rap.ucar.edu/weather/surface/index.php?hoursStr=24&metarIds=";
    NSString *URLString2 = @"http://www.rap.ucar.edu/weather/surface/index.php?hoursStr=24&metarIds=";
        
    // Set the new URL strings
    [wurl1 setURLString: [URLString1 stringByAppendingString:stationName]];
    [wurl2 setURLString: [URLString2 stringByAppendingString:stationName]];

    if ([wurl1 haveGoodURL] || [wurl2 haveGoodURL]) haveGoodURL = YES;

    [wurl1 cancelLoading];
    [wurl2 cancelLoading];
    processing = NO;
    gettingData = NO;
}

- (void)cancelLoading {
    if (wurl1 != nil) [wurl1 cancelLoading];
    if (wurl2 != nil) [wurl2 cancelLoading];
}

- (void)ticker {
	// If we have a long update time, then we should check for post processing data here.
    if ([self gettingData]) {
        [self min30UpdatePostProcessing];
    }	
}

- (void)graphUpdate:(NSTimer *)aTimer {
    if ([parentWindow systemJustWokeUp]) {
        [self cancelLoading];
        [self min30Update:nil];
        [parentWindow setSystemJustWokeUp:NO];
    }
    
    if ([self hasInvalidData]) {
        interval += [appSettings graphRefresh];
        if (interval >= 300) {
            interval = 0;
            [self min30Update:aTimer];
        }
    }
}

- (void)min30Update:(NSTimer *)aTimer {
    if (processing) {
        [self cancelLoading];
    }
    gettingData = YES;
    processing  = YES;
	
	haveGoodDisplayData = NO;
	[self setNeedsDisplay:YES];
	
    if (wurl1 != nil) {
        [wurl1 loadURLInBackground];
    }
    if (wurl2 != nil) {
        [wurl2 loadURLInBackground];
    }
    
    triedWURL1 = NO;
    triedWURL2 = NO;
}

- (void)min30UpdatePostProcessing {
    if (wurl1 == nil) triedWURL1 = YES;
    if (wurl2 == nil) triedWURL2 = YES;
    
    bool newDataToTry = NO;
    
    if (!triedWURL1) {
        @try {
            if (![wurl1 didErrorOccur] && [wurl1 isDataReady]) {
                triedWURL1 = YES;
                NSString *s = [[NSString alloc] initWithData:[wurl1 getData] encoding:NSASCIIStringEncoding];
                [self setMETARFromText:s];
                newDataToTry = YES;
            }
            else if ([wurl1 didErrorOccur]) {
                triedWURL1 = YES;
            }
            else {
                haveGoodMETARArray = NO;
            }
        } @catch (NSException *e) {
            haveGoodMETARArray = NO;
        }
    }
    
    if (!triedWURL2 && !newDataToTry) {
        if (!haveGoodMETARArray) {
            @try {
                if (![wurl2 didErrorOccur] && [wurl2 isDataReady]) {
                    triedWURL2 = YES;
                    NSString *s = [[NSString alloc] initWithData:[wurl2 getData] encoding:NSASCIIStringEncoding];
                    [self setMETARFromText:s];
                    newDataToTry = YES;
                }
                else if ([wurl2 didErrorOccur]) {
                    triedWURL2 = YES;
                }
                else {
                    haveGoodMETARArray = NO;
                }
			} @catch (NSException *e) {
                haveGoodMETARArray = NO;
            }
        }
    }
    
    if ((!triedWURL1 || !triedWURL2) && !newDataToTry) {
        return;
    }

    gettingData = NO;
    temperatureF = -273;
    temperatureC = -273;
    windDirection = -2;
    windSpeed = -1;
    visibilityInMiles = -1;
    visibilityInKilometers = -1;
    dewpointF = -273;
    dewpointC = -273;
    pressureIn = 0;
    pressureHPA = 0;
        
    @try {
        [self setCurrentWeatherDataFromMETAR];
    } @catch (NSException *e) {
        haveGoodDisplayData = NO;
    }
    
    if (!haveGoodMETARArray) {
        high = low = -273;
    }
    else {
        // get the high/low from the metar data
        if (lastDayTemps) {
            free(lastDayTemps);
            lastDayTemps = NULL;
        }
        int i;
        lastDayTemps = malloc(sizeof(float) * [metarArray count]);
        for (i = 0; i < [metarArray count]; i++) {
            lastDayTemps[i] = [self getTemperatureFromMETARFields: [metarArray[i] componentsSeparatedByString: @" "]];
            if (i == 0) {
                high = lastDayTemps[0];
                low = lastDayTemps[0];
            }
            else {
                if (lastDayTemps[i] > high) high = lastDayTemps[i];
                if (lastDayTemps[i] < low && lastDayTemps[i] != -273) low = lastDayTemps[i];
            }
        }
    }

    [self setNeedsDisplay:YES];
    if (haveGoodMETARArray) {
        [wurl1 cancelLoading];
        [wurl2 cancelLoading];
        processing = NO;
    }
    else if (!triedWURL1 || !triedWURL2) {
        processing = YES;
        gettingData = YES;
    }
    else {
        [wurl1 cancelLoading];
        [wurl2 cancelLoading];
        processing = NO;
    }
}

- (void)setMETARFromText:(NSString *)s {
    NSInteger rmkLocation = 0, stationNameLocation = 0;
    NSMutableString *sms = [NSMutableString stringWithCapacity: 4096];
    
    if ([s rangeOfString:stationName].location == NSNotFound) {
        haveGoodMETARArray = NO;
        return;
    }
    
    // Take out all HTML tags
    [sms setString:[[s substringFromIndex: [s rangeOfString:stationName].location] stringWithoutXMLTags]]; 
        
    [metarArray removeAllObjects]; 
    while (true) {
        // Need to clean up the code in this while loop sometime.  
        
        rmkLocation = [[sms substringFromIndex: 4] rangeOfString:stationName].location;
        if (rmkLocation == NSNotFound) break;
        
        // Check if the next location is within 10 characters from the current one.
        // If so, we want to skip this dataset (it's probably invalid) and move on to the next one.
        if (rmkLocation <= 10) {
            [sms setString: [sms substringFromIndex:rmkLocation]];

            stationNameLocation = [sms rangeOfString:stationName].location;
            if (stationNameLocation == NSNotFound) break;
            
            [sms setString: [sms substringFromIndex:stationNameLocation]];
            continue;
        }
        
        [metarArray insertObject:[sms substringToIndex:rmkLocation - 1 + 4]
                        atIndex:[metarArray count]];
        
        [sms setString: [sms substringFromIndex:rmkLocation]];
        
        stationNameLocation = [sms rangeOfString:stationName].location;
        if (stationNameLocation == NSNotFound) break;
        
        [sms setString: [sms substringFromIndex:stationNameLocation]];
    }
    
    if ([metarArray count] > 0) 
        haveGoodMETARArray = YES;
    else
        haveGoodMETARArray = NO;
}

- (void)setCurrentWeatherDataFromMETAR {
    NSArray *metarFields;
    NSInteger numFields;
    
    if (!haveGoodMETARArray) {
        haveGoodDisplayData = NO;
        return;
    }
    
    // split up the metar data
    metarFields = [metarArray[0] componentsSeparatedByString: @" "];
    numFields = [metarFields count];
    if (numFields < 2) {
        haveGoodDisplayData = NO;
        return;
    }
    
    if (![metarFields[0] isEqualToString: stationName]) {
        // the data didn't parse correctly if we don't have the station name first
        haveGoodDisplayData = NO;
        return;	
    }

    time                   = [self getTimeFromMETARFields:                   metarFields];
    windDirection          = [self getWindDirectionFromMETARFields:          metarFields];
    windSpeed              = [self getWindSpeedFromMETARFields:              metarFields];
    gustSpeed              = [self getGustSpeedFromMETARFields:              metarFields];
    visibilityInMiles      = [self getVisibilityInMilesFromMETARFields:      metarFields];
    visibilityInKilometers = [self getVisibilityInKilometersFromMETARFields: metarFields];
    temperatureC           = [self getTemperatureFromMETARFields:            metarFields];
    temperatureF           = temperatureC == -273 ? temperatureC : temperatureC * 1.8 + 32;
    dewpointC              = [self getDewpointFromMETARFields:               metarFields];
    dewpointF              = dewpointC == -273 ? dewpointC : dewpointC * 1.8 + 32;
    pressureIn             = [self getPressureInFromMETARFields:             metarFields];
    pressureHPA            = [self getPressureHPAFromMETARFields:            metarFields];
    relativeHumidity       = [self getRelativeHumidityFromTemperature: temperatureF andDewpoint: dewpointF];
  
    if (visibilityInKilometers == -1 || visibilityInMiles != -1) {
        visibilityInKilometers = (visibilityInMiles == -1) ? -1 : visibilityInMiles * 1.609;
    }
    if (visibilityInMiles == -1) {
        visibilityInMiles = (visibilityInKilometers == -1) ? -1 : visibilityInKilometers / 1.609;
    }
    
    if ((int)(pressureIn + .5) == 0) {
        pressureIn = (pressureHPA == 0) ? 0 : pressureHPA * 0.02953;
    }
    if (pressureHPA == 0) {
        pressureHPA = (pressureIn == 0) ? 0 : pressureIn / 0.02953;
    }
    
    
    haveGoodDisplayData = YES;
}

- (int)getTimeFromMETARFields:(NSArray *)fields {
    // the time should always be in index 1
    return [[fields[1] substringWithRange: NSMakeRange(2, 4)] intValue];
}

- (int)getWindDirectionFromMETARFields:(NSArray *)fields {
    NSUInteger index = [self findString:"KT$" inArray:fields];
    if (index == NSNotFound) {
        return -2;
    }
    else {
        if ([fields[index] hasPrefix: @"VRB"]) {
            // the wind is variable
            return -1;
        }
        else {
            return [[fields[index] substringWithRange: NSMakeRange(0, 3)] intValue];
        }
    }
}

- (int)getWindSpeedFromMETARFields:(NSArray *)fields {
    NSInteger index = [self findString:"KT$" inArray:fields];
    if (index == NSNotFound) {
        return -1;
    }
    else {
        if ([fields[index] hasPrefix: @"VRB"]) {
            // the wind is variable
            return [[fields[index] substringWithRange: NSMakeRange(3, 3)] intValue];
        }
        else {
            return [[fields[index] substringWithRange: NSMakeRange(3, 2)] intValue];
        }
    }
}

- (int)getGustSpeedFromMETARFields:(NSArray *)fields {
    NSInteger index = [self findString:"KT$" inArray:fields];
    if (index == NSNotFound) {
        return -1;
    }
    else {
        if (![fields[index] hasPrefix: @"VRB"]) {
            if ((char) [fields[index] characterAtIndex: 5] == 'G') {
                return [[fields[index] substringWithRange: NSMakeRange(6, 2)] intValue];
            }
            else {
                return 0;
            }
        }
        else {
            return 0;
        }
    }
}

- (float)getVisibilityInMilesFromMETARFields:(NSArray *)fields {
    NSInteger index = [self findString:"SM$" inArray:fields];
    if (index == NSNotFound)
        return -1;
    else 
        return [[fields[index] substringToIndex: [fields[index] rangeOfString: @"SM"].location] floatValue];
}

- (float)getVisibilityInKilometersFromMETARFields:(NSArray *)fields {
    NSInteger index = [self findString:"^[0-9]{4}$" inArray:fields];
    if (index == NSNotFound)
        return -1;
    else
        return [fields[index] floatValue] / 1000.;
}

- (float)getTemperatureFromMETARFields:(NSArray *)fields {
    float tempC;
    NSInteger index = [self findString:"^T[01][0-9]{3}[01][0-9]{3}$" inArray:fields];
    if (index != NSNotFound) {
        // good, there are float degree values
        tempC = [[fields[index] substringWithRange: NSMakeRange(2, 3)] floatValue];
        if ((char) [fields[index] characterAtIndex:1] == '1') 
            tempC *= -1;
            
        tempC /= 10;
    }
    else {
        // fall back on the integer degree values
        index = [self findString:"^M?[0-9]{2}/(M?[0-9]{2})?$" inArray:fields];
        if (index == NSNotFound) {
            return -273;
        }
        else {
            if ((char) [fields[index] characterAtIndex:0] == 'M') {
                tempC = [[fields[index] substringWithRange: NSMakeRange(1, 2)] intValue] * -1;
            }
            else {
                tempC = [[fields[index] substringToIndex: 2] intValue];
            }
        }
    }
    return tempC;
}

- (float)getDewpointFromMETARFields:(NSArray *)fields {
    float dptC;
    NSInteger index = [self findString:"^T[01][0-9]{3}[01][0-9]{3}$" inArray:fields];
    if (index != NSNotFound) {
        // good, there are float degree values
        dptC = [[fields[index] substringWithRange: NSMakeRange(6, 3)] floatValue];
        if ((char) [fields[index] characterAtIndex:5] == '1')
            dptC *= -1;
            
        dptC /= 10;
    }
    else {
        // fall back on the integer degree values
        index = [self findString:"^M?[0-9]{2}/M?[0-9]{2}$" inArray:fields];
        if (index == NSNotFound) {
            return -273;
        }
        else {
            int offset = 0;
            if ((char) [fields[index] characterAtIndex:0] == 'M')
                offset = 1;
            
            if ((char) [fields[index] characterAtIndex: 3 + offset] == 'M') 
                dptC = [[fields[index] substringFromIndex: 4 + offset] intValue] * -1;
            else 
                dptC = [[fields[index] substringFromIndex: 3 + offset] intValue];
        }
    }
    return dptC;
}

- (float)getPressureInFromMETARFields:(NSArray *)fields {
    NSInteger index = [self findString:"^A[123]" inArray:fields];
    if (index == NSNotFound) {
        return 0.;
    }
    else {
        return [[fields[index] substringFromIndex: 1] intValue] / 100.;
    }
}

- (int)getPressureHPAFromMETARFields:(NSArray *)fields {
    NSInteger index = [self findString:"^Q[0-9]{3,4}" inArray:fields];
    if (index == NSNotFound) {
        return 0.;
    }
    else {
        return [[fields[index] substringFromIndex: 1] intValue];
    }
}

- (int)getRelativeHumidityFromTemperature: (float)t andDewpoint: (float)d {
    // after getting the temperature and dewpoint, calculate the relative humidity
    if (t != -273 && d != -273) {
        float e_s, e;
        e_s = 6.11 * pow(10.0, 7.5 * t / (237.7 + t));
        e = 6.11 * pow(10.0, 7.5 * d / (237.7 + d));
        
        return (e / e_s) * 100;
    }
    else {
        return -1;
    }
}

- (NSInteger) findString:(char *)s inArray:(NSArray *)inArray {
    NSInteger i;
    if (s[0] == '\0') return NSNotFound;
        
    for (i = 0; i < [inArray count]; i++) {
        int retval = matchRegex(s, (char *)[inArray[i] lossyCString]);
        if (retval > 0)
            return i;
    }
    return NSNotFound;
}

int matchRegex(char *pattern, char *inString) {
    regex_t *preparedRegex;
    int checkval, retval;
    
    preparedRegex = malloc(sizeof(regex_t));
    
    checkval = regcomp(preparedRegex, pattern, REG_EXTENDED);    
    if (checkval == 0) {
        // prepared correctly
        checkval = regexec(preparedRegex, inString, 0, NULL, 0);
        
        if (checkval == 0) retval = 1;
        else {
            //char *errbuf = malloc(sizeof(char) * 80);
            //regerror(checkval, preparedRegex, errbuf, 80);
            //printf("%s\n", errbuf);
            retval = -2;
        }
            
        regfree(preparedRegex);
        free(preparedRegex);
    }
    else {
        // failed prepare
        retval = -1;
        free(preparedRegex);
    }
    
    return retval;
}

- (NSArray *)getSecondaryGraphList {
    return @[@"None",
			 @"Wind Speed",
			 @"Relative Humidity",
			 @"Visibility",
			 @"Dewpoint",
			 @"Pressure"];
}

- (void)drawRect:(NSRect)rect {
    if ([self isHidden]) return;

    #ifdef XRG_DEBUG
        NSLog(@"In Weather DrawRect."); 
    #endif

    NSGraphicsContext *gc = [NSGraphicsContext currentContext]; 

    NSInteger i;
    
    // first draw the background
    [[appSettings graphBGColor] set];    
    NSRectFill([self bounds]);

    [gc setShouldAntialias:[appSettings antiAliasing]];
    
    // if we don't have good data, don't draw a graph
    if (haveGoodMETARArray) {
        NSInteger numTemps = [metarArray count];
        CGFloat *data = (CGFloat *)alloca(numTemps * sizeof(CGFloat));
        
        for (i = numTemps - 1; i >= 0; i--) {
            if (lastDayTemps[i] < -272) {
                data[(numTemps - 1) - i] = NOVALUE;
            }
            else {
                data[(numTemps - 1) - i] = lastDayTemps[i];
            }
        }
            
        [self drawRangedGraphWithData:data 
								 size:[metarArray count] 
						 currentIndex:[metarArray count] - 1 
						   upperBound:(float)(high + 10) 
						   lowerBound:(float)(low - 10) 
							   inRect:[self bounds] 
							  flipped:NO 
							   filled:YES 
								color:[appSettings graphFG1Color]];
        
        // draw the secondary graph
        if ([appSettings secondaryWeatherGraph] != 0) {
            [self setUpSecondaryGraph];
            for (i = 0; i < numTemps; i++) {
                data[i] = lastDaySecondary[i];
            }
            
            [self drawRangedGraphWithData:data 
									 size:[metarArray count] 
							 currentIndex:[metarArray count] - 1 
							   upperBound:secondaryGraphUpperBound 
							   lowerBound:secondaryGraphLowerBound 
								   inRect:[self bounds] 
								  flipped:NO 
								   filled:NO 
									color:[appSettings graphFG2Color]];
        }
    }

    [gc setShouldAntialias:YES];

        
    // now draw the text
    [gc setShouldAntialias:[appSettings antialiasText]];

    NSInteger textRectHeight = [appSettings textRectHeight];
    char *tmpChar;
    NSRect textRect = NSMakeRect(3, graphSize.height - textRectHeight, graphSize.width - 6, textRectHeight);
    if ([self hasGoodDisplayData]) {  // valid data
        NSMutableString *leftS = [[NSMutableString alloc] init];
        NSMutableString *rightS = [[NSMutableString alloc] init];
        [leftS setString:@""];
        [rightS setString:@""];
   
        if (STATION_WIDE <= textRect.size.width) {
            [leftS appendString:@"Station:"];
            [rightS setString:[appSettings ICAO]];
        }
        else {
            [leftS appendString:[appSettings ICAO]];
        }
        
        if (textRect.origin.y - textRectHeight >= 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            if (TEMPERATURE_WIDE <= textRect.size.width) {
                [leftS appendString:@"\nCurrent Temperature:"];
            }
            else if (TEMPERATURE_NORMAL <= textRect.size.width) {
                [leftS appendString:@"\nTemperature:"];
            }
            else if (TEMPERATURE_SMALL <= textRect.size.width) {
                [leftS appendString:@"\nTemp:"];
            }
            else {
                [leftS appendString:@"\nT:"];
            }
            
            if (temperatureF == -273) 
                [rightS appendString:@"\nn/a"];
            else { 
                if ([appSettings temperatureUnits] == XRGWEATHER_TEMPERATURE_F) 
                    [rightS appendFormat:@"\n%d%CF", temperatureF, (unsigned short)0x00B0];
                else
                    [rightS appendFormat:@"\n%2.1f%CC", temperatureC, (unsigned short)0x00B0];
            }
        }

        if (textRect.origin.y - textRectHeight >= 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            if (HL_WIDE <= textRect.size.width) {
                [leftS appendString:@"\nHigh/Low:"];
                if ([self getHigh] == -273 || [self getLow] == -273) {
                    [rightS appendString:@"\nn/a"];
                }
                else {
                    if ([appSettings temperatureUnits] == XRGWEATHER_TEMPERATURE_C)
                        [rightS appendFormat:@"\n%2.0f%C/%2.0f%C", [self getHigh], (unsigned short)0x00B0, [self getLow], (unsigned short)0x00B0];
                    else
                        [rightS appendFormat:@"\n%d%C/%d%C", (int)([self getHigh] * 1.8) + 32, (unsigned short)0x00B0, (int)([self getLow] * 1.8) + 32, (unsigned short)0x00B0];
                }
            }
            else {
                [leftS appendString:@"\nH/L:"];
                if ([self getHigh] == -273 || [self getLow] == -273) {
                    [rightS appendString:@"\nn/a"];
                }
                else {
                    if ([appSettings temperatureUnits] == XRGWEATHER_TEMPERATURE_C)
                        [rightS appendFormat:@"\n%2.0f/%2.0f", [self getHigh], [self getLow]];
                    else
                        [rightS appendFormat:@"\n%d/%d", (int)([self getHigh] * 1.8 + 32.), (int)([self getLow] * 1.8 + 32.)];
                }
            }
        }
        
        if (textRect.origin.y - textRectHeight >= 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            tmpChar = [self getWindDirection];
            if (windSpeed == 0) {
                [leftS appendString:@"\nWind:"];
                [rightS appendString:@"\ncalm"];
            }
            else {
                if (WIND_WIDE <= textRect.size.width) {
                    if ([self getGustSpeed]) {
                        [leftS appendFormat:@"\nWind: %s %d", tmpChar, windSpeed];
                        [rightS appendFormat:@"\nGusts: %d", [self getGustSpeed]];
                    }
                    else {
                        [leftS appendFormat:@"\nWind:"];
                        [rightS appendFormat:@"\n%s %d", tmpChar, windSpeed];
                    }
                }
                else if (WIND_NORMAL <= textRect.size.width) {
                    if ([self getGustSpeed]) {
                        [leftS appendFormat:@"\nWind: %s %d", tmpChar, windSpeed];
                        [rightS appendFormat:@"\nG: %d", [self getGustSpeed]];
                    }
                    else {
                        [leftS appendFormat:@"\nWind:"];
                        [rightS appendFormat:@"\n%s %d", tmpChar, windSpeed];
                    }
                }
                else if (WIND_SMALL <= textRect.size.width) {
                    [leftS appendString:@"\nWind:"];
                    [rightS appendFormat:@"\n%s %d", tmpChar, windSpeed];
                }
                else {
                    [leftS appendString:@"\nW:"];
                    [rightS appendFormat:@"\n%s %d", tmpChar, windSpeed];
                }
            
            }
        }

        if (textRect.origin.y - textRectHeight >= 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            if (HUMIDITY_WIDE <= textRect.size.width) {
                [leftS appendString:@"\nRelative Humidity:"];
            }
            else if (HUMIDITY_NORMAL <= textRect.size.width) {
                [leftS appendString:@"\nRel Humidity:"];
            }
            else {
                [leftS appendString:@"\nRH:"];
            }
            if (relativeHumidity == -1)
                [rightS appendString:@"\nn/a"];
            else 
                [rightS appendFormat:@"\n%d%%", relativeHumidity];
        }
        
        if (textRect.origin.y - textRectHeight >= 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            if (VISIBILITY_WIDE <= textRect.size.width) {
                [leftS appendString:@"\nVisibility:"];
            }
            else {
                [leftS appendString:@"\nV:"];
            }
            
            if ([appSettings distanceUnits] == XRGWEATHER_DISTANCE_MI) {
                if (visibilityInMiles == -1)
                    [rightS appendString:@"\nn/a"];
                else {
                    if (visibilityInMiles >= 1)
                        [rightS appendFormat:@"\n%2.f mi", visibilityInMiles];
                    else
                        [rightS appendFormat:@"\n%.2f mi", visibilityInMiles];
                }
            }
            else {
                if (visibilityInKilometers == -1) 
                    [rightS appendString:@"\nn/a"];
                else {
                    [rightS appendFormat:@"\n%2.1f km", visibilityInKilometers];
                }
            }
        }
        
        if (textRect.origin.y - textRectHeight >= 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            if (DEWPOINT_WIDE <= textRect.size.width) {
                [leftS appendString:@"\nDewpoint:"];
            }
            else {
                [leftS appendString:@"\nD:"];
            }
            
            if (dewpointF == -273)
                [rightS appendString:@"\nn/a"];
            else {
                if ([appSettings temperatureUnits] == XRGWEATHER_TEMPERATURE_F)
                    [rightS appendFormat:@"\n%d%CF", dewpointF, (unsigned short)0x00B0];
                else
                    [rightS appendFormat:@"\n%2.1f%CC", dewpointC, (unsigned short)0x00B0];
            }
        }
                                    
        if (textRect.origin.y - textRectHeight >= 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            if (PRESSURE_WIDE <= textRect.size.width) {
                [leftS appendString:@"\nBarometric Pressure:"];
            }
            else if (PRESSURE_NORMAL <= textRect.size.width) {
                [leftS appendString:@"\nPressure:"];
            }
            else {
                [leftS appendString:@"\nP:"];
            }
            
            if ([appSettings pressureUnits] == XRGWEATHER_PRESSURE_IN) {
                if (pressureIn == 0.) 
                    [rightS appendString:@"\nn/a"];
                else
                    [rightS appendFormat:@"\n%2.2fin", pressureIn];
            }
            else {
                if (pressureHPA == 0.) 
                    [rightS appendString:@"\nn/a"];
                else
                    [rightS appendFormat:@"\n%dhPa", pressureHPA];
            }
        }
        
        [leftS drawAtPoint:textRect.origin withAttributes:[appSettings alignLeftAttributes]];
        [rightS drawInRect:textRect withAttributes:[appSettings alignRightAttributes]];
	}
    else {             // invalid data
        if (gettingData) [@"Fetching Data" drawInRect:textRect withAttributes:[appSettings alignLeftAttributes]];
        else [@"Invalid Data" drawInRect:textRect withAttributes:[appSettings alignLeftAttributes]];
    }
    
    [gc setShouldAntialias:YES];
}

- (int)convertHeight:(int) yComponent {
    return (yComponent >= 0 ? yComponent : 0) * (graphSize.height - [appSettings textRectHeight]) / 100;
}

- (void)setUpSecondaryGraph {
    NSInteger i;
    secondaryGraphLowerBound = secondaryGraphUpperBound = 0;
    
    if (lastDaySecondary) {
        free(lastDaySecondary);
        lastDaySecondary = NULL;
    }
    lastDaySecondary = (float *)calloc([metarArray count], sizeof(float));
    

    switch ([appSettings secondaryWeatherGraph]) {
        case XRGWEATHER_NONE:	
            break;
        case XRGWEATHER_WIND:
            secondaryGraphUpperBound = (float)windSpeed;
            for (i = [metarArray count] - 1; i >= 0; i--) {
                NSInteger index = [metarArray count] - 1 - i;
                NSArray *metarFields = [metarArray[i] componentsSeparatedByString: @" "];
                lastDaySecondary[index] = [self getWindSpeedFromMETARFields: metarFields];
                
                if (lastDaySecondary[index] == -1)
                    lastDaySecondary[index] = NOVALUE;
                    
                if (lastDaySecondary[index] > secondaryGraphUpperBound)
                    secondaryGraphUpperBound = lastDaySecondary[index];
            }
            
            secondaryGraphLowerBound = 0;
            secondaryGraphUpperBound *= 1.1;
            break;
        case XRGWEATHER_HUMIDITY:
            for (i = [metarArray count] - 1; i >= 0; i--) {
                NSInteger index = [metarArray count] - 1 - i;
                NSArray *metarFields = [metarArray[i] componentsSeparatedByString: @" "];
                lastDaySecondary[index] = [self getRelativeHumidityFromTemperature:[self getTemperatureFromMETARFields: metarFields] andDewpoint:[self getDewpointFromMETARFields: metarFields]];
                
                if (lastDaySecondary[index] == -1)
                    lastDaySecondary[index] = NOVALUE;
            }
                        
            secondaryGraphLowerBound = 0;            
            secondaryGraphUpperBound = 100;
            break;
        case XRGWEATHER_VISIBILITY:
            secondaryGraphUpperBound = visibilityInMiles;
            for (i = [metarArray count] - 1; i >= 0; i--) {
                NSInteger index = [metarArray count] - 1 - i;
                NSArray *metarFields = [metarArray[i] componentsSeparatedByString: @" "];
                lastDaySecondary[index] = [self getVisibilityInMilesFromMETARFields: metarFields];
                
                if (lastDaySecondary[index] == -1)
                    lastDaySecondary[index] = [self getVisibilityInKilometersFromMETARFields:metarFields];
                                        
                if (lastDaySecondary[index] == -1)
                    lastDaySecondary[index] = NOVALUE;

                if (lastDaySecondary[index] > secondaryGraphUpperBound)
                    secondaryGraphUpperBound = lastDaySecondary[index];
            }
            
            secondaryGraphLowerBound = 0;
            secondaryGraphUpperBound *= 1.1;
            break;
        case XRGWEATHER_DEWPOINT:
            secondaryGraphLowerBound = secondaryGraphUpperBound = dewpointC;
            for (i = [metarArray count] - 1; i >= 0; i--) {
                NSInteger index = [metarArray count] - 1 - i;
                NSArray *metarFields = [metarArray[i] componentsSeparatedByString: @" "];
                lastDaySecondary[index] = [self getDewpointFromMETARFields: metarFields];
                
                if (lastDaySecondary[index] < -272.)
                    lastDaySecondary[index] = NOVALUE;
                
                if (lastDaySecondary[index] > secondaryGraphUpperBound)
                    secondaryGraphUpperBound = lastDaySecondary[index];
                if (lastDaySecondary[index] < secondaryGraphLowerBound) 
                    secondaryGraphLowerBound = lastDaySecondary[index];
            }
            
            secondaryGraphLowerBound += (secondaryGraphLowerBound > 0) ? secondaryGraphLowerBound * -.1 : secondaryGraphLowerBound * .1;
            secondaryGraphUpperBound += (secondaryGraphUpperBound > 0) ? secondaryGraphUpperBound * .1 : secondaryGraphUpperBound * -.1;
            break;
        case XRGWEATHER_PRESSURE:
            secondaryGraphLowerBound = pressureHPA;
            for (i = [metarArray count] - 1; i >= 0; i--) {
                NSArray *metarFields = [metarArray[i] componentsSeparatedByString: @" "];
                float tmpPressure = [self getPressureInFromMETARFields: metarFields];
                if ((int)(tmpPressure + .5) == 0)
                    tmpPressure = (float)[self getPressureHPAFromMETARFields: metarFields] * 0.02953;
                
                if ((int)(tmpPressure + .5) == 0)
                    tmpPressure = NOVALUE;
                
                lastDaySecondary[[metarArray count] - 1 - i] = tmpPressure;
                                
                if (lastDaySecondary[[metarArray count] - 1 - i] > secondaryGraphUpperBound)
                    secondaryGraphUpperBound = lastDaySecondary[[metarArray count] - 1 - i];
                if (lastDaySecondary[[metarArray count] - 1 - i] < secondaryGraphLowerBound && lastDaySecondary[[metarArray count] - 1 - i] != NOVALUE)
                    secondaryGraphLowerBound = lastDaySecondary[[metarArray count] - 1 - i];
            }
                        
            secondaryGraphUpperBound *= 1.01;
            secondaryGraphLowerBound *= 0.99;
            break;
    }
}

- (void)setUpTertiaryGraph {
}

- (bool)gettingData {
    return gettingData;
}

- (bool)hasGoodDisplayData {
    return haveGoodDisplayData;
}

- (bool)hasInvalidData {
    return (!haveGoodDisplayData && !gettingData);
}

- (int)getTemperatureF {
    return temperatureF;
}

- (float)getTemperatureC {
    return temperatureC;
}

- (char *)getWindDirection {
    if (windDirection == -1) 
        return "VRB";
    if (windDirection == -2)
        return "n/a";

    float differences[17];
    differences[0]  = fabs(N1  - windDirection);
    differences[1]  = fabs(NNE - windDirection);
    differences[2]  = fabs(NE  - windDirection);
    differences[3]  = fabs(ENE - windDirection);
    differences[4]  = fabs(E   - windDirection);
    differences[5]  = fabs(ESE - windDirection);
    differences[6]  = fabs(SE  - windDirection);
    differences[7]  = fabs(SSE - windDirection);
    differences[8]  = fabs(S   - windDirection);
    differences[9]  = fabs(SSW - windDirection);
    differences[10] = fabs(SW  - windDirection);
    differences[11] = fabs(WSW - windDirection);
    differences[12] = fabs(W   - windDirection);
    differences[13] = fabs(WNW - windDirection);
    differences[14] = fabs(NW  - windDirection);
    differences[15] = fabs(NNW - windDirection);
    differences[16] = fabs(N2  - windDirection);
    
    float min = 11.25;
    int minIndex = 0;
    int i;
    for (i = 0; i < sizeof(differences) / sizeof(float); i++) {
        if (differences[i] < min) {
            minIndex = i;
            min = differences[i];
        }
    }
    
    switch (minIndex) {
        case 0:
            return "N";
        case 1:
            return "NNE";
        case 2:
            return "NE";
        case 3:
            return "ENE";
        case 4:
            return "E";
        case 5:
            return "ESE";
        case 6:
            return "SE";
        case 7:
            return "SSE";
        case 8:
            return "S";
        case 9:
            return "SSW";
        case 10:
            return "SW";
        case 11:
            return "WSW";
        case 12:
            return "W";
        case 13:
            return "WNW";
        case 14:
            return "NW";
        case 15:
            return "NNW";
        case 16:
            return "N";
        default:
            return "";
    }
}

- (int)getWindSpeed {
    return windSpeed;
}

- (int)getGustSpeed {
    return gustSpeed;
}

- (int)getVisibility {
    return visibilityInMiles;
}

- (int)getDewpointF {
    return dewpointF;
}

- (float)getDewpointC {
    return dewpointC;
}

- (float)getPressureIn {
    return pressureIn;
}

- (int)getPressureHPA {
    return pressureHPA;
}

- (float)getHigh {
    return high;
}

- (float)getLow {
    return low;
}

- (int)getRelativeHumidity {
    return relativeHumidity;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {       
    return YES;
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Weather View"];
    NSMenuItem *tMI;

    NSString *icao = [appSettings ICAO];
    
    NSMutableString *line = [NSMutableString stringWithFormat:@"Current Conditions for %@...", icao];
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle: line action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];
      
    if ([self getTemperatureF] == -273) {
        [line setString:@"Temperature: n/a"];
    }
    else {
        [line setString:@"Temperature: "];
        if ([appSettings temperatureUnits] == XRGWEATHER_TEMPERATURE_F) 
            [line appendFormat:@"%d%CF", [self getTemperatureF], (unsigned short)0x00B0];
        else
            [line appendFormat:@"%1.1f%CC", [self getTemperatureC], (unsigned short)0x00B0];
    }
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle: line action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];
      
    if ([self getHigh] == -273) {
        [line setString:@"Last 24 hour high temperature: n/a"];
    }
    else {
        [line setString:@"Last 24 hour high temperature: "];
        if ([appSettings temperatureUnits] == XRGWEATHER_TEMPERATURE_C)
            [line appendFormat:@"%1.1f%CC", [self getHigh], (unsigned short)0x00B0];
        else
            [line appendFormat:@"%1.1f%CF", [self getHigh] * 1.8 + 32., (unsigned short)0x00B0];
    }
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle: line action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    if ([self getLow] == -273) {
        [line setString:@"Last 24 hour low temperature: n/a"];
    }
    else {
        [line setString:@"Last 24 hour low temperature: "];
        if ([appSettings temperatureUnits] == XRGWEATHER_TEMPERATURE_C)
            [line appendFormat:@"%1.1f%CC", [self getLow], (unsigned short)0x00B0];
        else
            [line appendFormat:@"%1.1f%CF", [self getLow] * 1.8 + 32., (unsigned short)0x00B0];
    }
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle: line action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    if ([self getWindSpeed] == 0) 
        [line setString:@"Wind: calm"];
    else if (windDirection == -1) {
        [line setString:@""];
        [line appendFormat:@"Wind: Variable at %d mph", [self getWindSpeed]];
    }
    else {
        [line setString:@""];
        [line appendFormat:@"Wind: %s (%d%C) at %d mph", [self getWindDirection], windDirection, (unsigned short)0x00B0, [self getWindSpeed]];
    }
    if ([self getGustSpeed]) [line appendFormat:@" with gusts of %d mph", [self getGustSpeed]];
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle: line action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    if ([self getRelativeHumidity] == -1)
        [line setString:@"Relative Humidity: n/a"];
    else {
        [line setString:@""];
        [line appendFormat:@"Relative Humidity: %d%%", [self getRelativeHumidity]];
    }
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle: line action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    if ([appSettings distanceUnits] == XRGWEATHER_DISTANCE_MI) {
        if (visibilityInMiles == -1 && visibilityInKilometers == -1)
            [line setString:@"Visibility: n/a"];
        else if (visibilityInMiles == -1 && visibilityInKilometers != -1) {
            [line setString:@""];
            [line appendFormat:@"Visibility: %1.1f kilometers", visibilityInKilometers];
        }
        else {
            [line setString:@""];
            [line appendFormat:@"Visibility: %1.1f miles", visibilityInMiles];
        }
    }
    else {
        if (visibilityInMiles == -1 && visibilityInKilometers == -1)
            [line setString:@"Visibility: n/a"];
        else if (visibilityInMiles != -1 && visibilityInKilometers == -1) {
            [line setString:@""];
            [line appendFormat:@"Visibility: %1.1f miles", visibilityInMiles];
        }
        else {
            [line setString:@""];
            [line appendFormat:@"Visibility: %1.1f kilometers", visibilityInKilometers];
        }
    }
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle: line action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    if ([appSettings temperatureUnits] == XRGWEATHER_TEMPERATURE_F) {
        if ([self getDewpointF] == -273)
            [line setString:@"Dewpoint: n/a"];
        else {
            [line setString:@""];
            [line appendFormat:@"Dewpoint: %d%CF", [self getDewpointF], (unsigned short)0x00B0];
        }
    }
    else {
        if ([self getDewpointC] == -273)
            [line setString:@"Dewpoint: n/a"];
        else {
            [line setString:@""];
            [line appendFormat:@"Dewpoint: %1.1f%CC", [self getDewpointC], (unsigned short)0x00B0];
        }
    }
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle: line action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    [line setString:@"Barometric Pressure: "];
    if ([appSettings pressureUnits] == XRGWEATHER_PRESSURE_IN) {
        if (pressureIn == 0.) 
            [line appendFormat:@"n/a"];
        else
            [line appendFormat:@"%2.2fin", pressureIn];
    }
    else {
        if (pressureHPA == 0.) 
            [line appendFormat:@"n/a"];
        else
            [line appendFormat:@"%dhPa", pressureHPA];
    }
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle: line action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] 
                       initWithTitle:@"Update Weather Graph Now"
                              action:@selector(min30Update:) 
                       keyEquivalent:@""];
    [myMenu addItem:tMI];
	
    
    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open XRG Weather Preferences..." action:@selector(openWeatherPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    return myMenu;
}

- (void)openWeatherPreferences:(NSEvent *)theEvent {
    [[parentWindow controller] showPrefsWithPanel:@"Weather"];
}

- (void)emptyEvent:(NSEvent *)theEvent {
}

- (void)mouseDown:(NSEvent *)theEvent {
    [parentWindow mouseDown:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent {
    [parentWindow mouseDragged:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent {
    [parentWindow mouseUp:theEvent];
}

@end

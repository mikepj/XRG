/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2016 Gaucho Software, LLC.
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
//  XRGWeatherView.h
//

#import <Cocoa/Cocoa.h>
#import "XRGURL.h"
#import "XRGGenericView.h"

#define XRGWEATHER_NONE           0
#define XRGWEATHER_WIND           1
#define XRGWEATHER_HUMIDITY       2
#define XRGWEATHER_VISIBILITY     3
#define XRGWEATHER_DEWPOINT       4
#define XRGWEATHER_PRESSURE       5

#define XRGWEATHER_TEMPERATURE_F  0
#define XRGWEATHER_TEMPERATURE_C  1

#define XRGWEATHER_DISTANCE_MI    0
#define XRGWEATHER_DISTANCE_KM    1

#define XRGWEATHER_PRESSURE_IN    0
#define XRGWEATHER_PRESSURE_HPA   1

NSInteger matchRegex(char *pattern, char *inString);

@interface XRGWeatherView : XRGGenericView {
@private
    NSSize				graphSize;
    XRGModule           *m;

    // Caching variables
    CGFloat             STATION_WIDE;
    CGFloat             TEMPERATURE_WIDE;
    CGFloat             TEMPERATURE_NORMAL;
    CGFloat             TEMPERATURE_SMALL;
    CGFloat             HL_WIDE;
    CGFloat             WIND_WIDE;
    CGFloat             WIND_NORMAL;
    CGFloat             WIND_SMALL;
    CGFloat             HUMIDITY_WIDE;
    CGFloat             HUMIDITY_NORMAL;
    CGFloat             VISIBILITY_WIDE;
    CGFloat             DEWPOINT_WIDE;
    CGFloat             PRESSURE_WIDE;
    CGFloat             PRESSURE_NORMAL;

    XRGURL				*wurl1;
    XRGURL				*wurl2;
    BOOL				triedWURL1;
    BOOL				triedWURL2;
    
    NSString			*stationName;
    NSMutableArray		*metarArray;
    BOOL				gettingData;
    BOOL				processing;
    BOOL				hasGoodURL;
    BOOL				hasGoodMETARArray;
    BOOL				hasGoodDisplayData;
    
    NSInteger			time;
    NSInteger			windDirection;
    NSInteger			windSpeed;
    NSInteger			gustSpeed;
    CGFloat				visibilityInMiles;
    CGFloat				visibilityInKilometers;
    NSInteger			temperatureF;
    CGFloat				temperatureC;
    NSInteger			dewpointF;
    CGFloat				dewpointC;
    CGFloat				pressureIn;
    NSInteger			pressureHPA;
    CGFloat				high;
    CGFloat				low;
    NSInteger			relativeHumidity;
    CGFloat				*lastDayTemps;
    CGFloat				*lastDaySecondary;
    
    CGFloat				secondaryGraphLowerBound;
    CGFloat				secondaryGraphUpperBound;
    
    NSString			*shortTemp;
    NSString			*longTemp;
    NSString			*shortHL;
    NSString			*longHL;
    NSString			*shortWind;
    NSString			*longWind;
    NSString			*shortHumidity;
    NSString			*longHumidity;
    NSString			*shortVisibility;
    NSString			*longVisibility;
    NSString			*shortDewpoint;
    NSString			*longDewpoint;
    NSString			*shortPressure;
    NSString			*longPressure;
    
    NSInteger			interval;
}
- (void)setGraphSize:(NSSize)newSize;
- (void)updateMinSize;
- (CGFloat)convertHeight:(CGFloat)yComponent;
- (void)ticker;
- (void)graphUpdate:(NSTimer *)aTimer;
- (void)min30Update:(NSTimer *)aTimer;
- (void)min30UpdatePostProcessing;
- (void)setMETARFromText:(NSString *)s;
- (void)setCurrentWeatherDataFromMETAR;
- (void)setURL:(NSString *)icao;
- (NSInteger)findString:(char *)s inArray:(NSArray *)inArray;
- (NSArray *)getSecondaryGraphList;
- (void)setUpSecondaryGraph;
- (void)cancelLoading;
- (bool)hasInvalidData;

- (char *)getWindDirection;

- (NSInteger)getTimeFromMETARFields:(NSArray *)fields;
- (NSInteger)getWindDirectionFromMETARFields:(NSArray *)fields;
- (NSInteger)getWindSpeedFromMETARFields:(NSArray *)fields;
- (NSInteger)getGustSpeedFromMETARFields:(NSArray *)fields;
- (CGFloat)getVisibilityInMilesFromMETARFields:(NSArray *)fields;
- (CGFloat)getVisibilityInKilometersFromMETARFields:(NSArray *)fields;
- (CGFloat)getTemperatureFromMETARFields:(NSArray *)fields;
- (CGFloat)getDewpointFromMETARFields:(NSArray *)fields;
- (CGFloat)getPressureInFromMETARFields:(NSArray *)fields;
- (NSInteger)getPressureHPAFromMETARFields:(NSArray *)fields;
- (NSInteger)getRelativeHumidityFromTemperature: (CGFloat)t andDewpoint: (CGFloat)d;

@end

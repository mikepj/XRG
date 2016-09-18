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

int matchRegex(char *pattern, char *inString);

@interface XRGWeatherView : XRGGenericView {
@private
    NSSize				graphSize;
    XRGModule           *m;

    // Caching variables
    float               STATION_WIDE;
    float               TEMPERATURE_WIDE;
    float               TEMPERATURE_NORMAL;
    float               TEMPERATURE_SMALL;
    float               HL_WIDE;
    float               WIND_WIDE;
    float               WIND_NORMAL;
    float               WIND_SMALL;
    float               HUMIDITY_WIDE;
    float               HUMIDITY_NORMAL;
    float               VISIBILITY_WIDE;
    float               DEWPOINT_WIDE;
    float               PRESSURE_WIDE;
    float               PRESSURE_NORMAL;

    XRGURL				*wurl1;
    XRGURL				*wurl2;
    bool				triedWURL1;
    bool				triedWURL2;
    
    NSString			*stationName;
    NSMutableArray		*metarArray;
    bool				gettingData;
    bool				processing;
    bool				haveGoodURL;
    bool				haveGoodMETARArray;
    bool				haveGoodDisplayData;
    
    int					time;
    int					windDirection;
    int					windSpeed;
    int					gustSpeed;
    float				visibilityInMiles;
    float				visibilityInKilometers;
    int					temperatureF;
    float				temperatureC;
    int					dewpointF;
    float				dewpointC;
    float				pressureIn;
    int					pressureHPA;
    float				high;
    float				low;
    int					relativeHumidity;
    float				*lastDayTemps;
    float				*lastDaySecondary;
    
    float				secondaryGraphLowerBound;
    float				secondaryGraphUpperBound;
    
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
    
    int					interval;
}
- (void)setGraphSize:(NSSize)newSize;
- (void)updateMinSize;
- (int)convertHeight:(int) yComponent;
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
- (void)setUpTertiaryGraph;
- (void)cancelLoading;
- (bool)hasInvalidData;

- (bool)hasGoodDisplayData;
- (bool)gettingData;
- (int)getTemperatureF;
- (float)getTemperatureC;
- (char *)getWindDirection;
- (int)getWindSpeed;
- (int)getGustSpeed;
- (int)getVisibility;
- (int)getDewpointF;
- (float)getDewpointC;
- (float)getPressureIn;
- (float)getHigh;
- (float)getLow;
- (int)getRelativeHumidity;

- (int)getTimeFromMETARFields:(NSArray *)fields;
- (int)getWindDirectionFromMETARFields:(NSArray *)fields;
- (int)getWindSpeedFromMETARFields:(NSArray *)fields;
- (int)getGustSpeedFromMETARFields:(NSArray *)fields;
- (float)getVisibilityInMilesFromMETARFields:(NSArray *)fields;
- (float)getVisibilityInKilometersFromMETARFields:(NSArray *)fields;
- (float)getTemperatureFromMETARFields:(NSArray *)fields;
- (float)getDewpointFromMETARFields:(NSArray *)fields;
- (float)getPressureInFromMETARFields:(NSArray *)fields;
- (int)getPressureHPAFromMETARFields:(NSArray *)fields;
- (int)getRelativeHumidityFromTemperature: (float)t andDewpoint: (float)d;

@end

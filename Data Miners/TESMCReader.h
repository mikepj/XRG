/*
 * The following code is derived from Apple System Management Control (SMC) Tool under the GPL 
 * Copyright (C) 2006 devnull 
 * Converted 2007 by Thomas Engelmeier
 */

#import <Cocoa/Cocoa.h>

@interface TESMCReader : NSObject {
	io_connect_t conn; 
} 
- (void) reset;

// returns an plain dict of values with their 4cc IDs
- (NSDictionary *)allValues;

// as far as their meaning is known (==guessable), the values have human readable keys
// Fan values
- (NSDictionary *)fanValues;

// temp sensors:
- (NSDictionary *)temperatureValuesExtended:(BOOL) withUnknownSensors;

// additional sensors (motion etc.) 
- (NSDictionary *)sensorValues;

- (int) c4String:(char *)string matchesPattern:(char *)pattern;

@end
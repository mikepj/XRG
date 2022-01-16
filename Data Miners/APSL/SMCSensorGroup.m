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
//  SMCSensorGroup.m
//

#import "SMCSensorGroup.h"

NSArray<NSString *> *__SMCSensorGroup_wildcardOrder = nil;

@implementation SMCSensorSeries

- (instancetype)initWithStartingCharacter:(NSString *)character {
    if (self = [super init]) {
        self.characters = @[character];
    }
    
    return self;
}

/// Add another subsequent character.
- (void)addCharacter:(NSString *)character {
    self.characters = [self.characters arrayByAddingObject:character];
}

/// The number of concurrent characters in this series that are valid SMC keys.
- (NSInteger)concurrentValues {
    return self.characters.count;
}

- (BOOL)isFullNumericSeries {
    return self.characters.count == 10 && [self.characters[0] isEqualToString:@"0"];
}

@end

@interface SMCSensorGroup ()
@property NSArray<NSString *> *wildcardOrder;
@end

@implementation SMCSensorGroup

+ (nonnull NSArray<SMCSensorSeries *> *)seriesForPattern:(NSString *)pattern inSensorList:(NSSet<NSString *> *)sensorList {
    NSArray *wildcardCharacters = [SMCSensorGroup wildcardOrder];
    
    NSMutableArray<SMCSensorSeries *> *prefixGroups = [NSMutableArray array];
    SMCSensorSeries *currentSeries = nil;
    
    for (NSString *wildcardCharacter in wildcardCharacters) {
        NSString *checkString = [pattern stringByReplacingOccurrencesOfString:@"?" withString:wildcardCharacter];
        
        if ([sensorList containsObject:checkString]) {
            if (currentSeries) {
                [currentSeries addCharacter:wildcardCharacter];
            }
            else {
                currentSeries = [[SMCSensorSeries alloc] initWithStartingCharacter:wildcardCharacter];
            }
        }
        else if (currentSeries) {
            [prefixGroups addObject:currentSeries];
            currentSeries = nil;
        }
    }
    
    // Check for a 0-9 prefix.
    NSInteger fullNumericIndex = NSNotFound;
    for (int i = 0; i < prefixGroups.count; i++) {
        if ([prefixGroups[i] isFullNumericSeries]) {
            fullNumericIndex = i;
            break;
        }
    }
    
    // Check for a prefix starting with 'a'.
    NSInteger lowerAPrefixIndex = NSNotFound;
    for (int i = 0; i < prefixGroups.count; i++) {
        if ([prefixGroups[i].characters[0] isEqualToString:@"a"]) {
            lowerAPrefixIndex = i;
        }
    }
    
    if (fullNumericIndex != NSNotFound && lowerAPrefixIndex != NSNotFound) {
        // Concatenate the "a" prefix onto the 0-9 prefix.
        SMCSensorSeries *numericSeries = prefixGroups[fullNumericIndex];
        SMCSensorSeries *lowerASeries = prefixGroups[lowerAPrefixIndex];
        
        numericSeries.characters = [numericSeries.characters arrayByAddingObjectsFromArray:lowerASeries.characters];
        
        // Remove the "a" prefix series.
        [prefixGroups removeObjectAtIndex:lowerAPrefixIndex];
    }
    
    return prefixGroups;
}

+ (nonnull NSArray<NSString *> *)wildcardOrder {
    if (__SMCSensorGroup_wildcardOrder == nil) {
        // Populate the wildcard order.
        NSMutableArray *order = [NSMutableArray array];
        
        for (int i = 0; i <= 9; i++) {
            [order addObject:[NSString stringWithFormat:@"%d", i]];
        }
        for (char c = 'A'; c <= 'Z'; c++) {
            [order addObject:[NSString stringWithFormat:@"%c", c]];
        }
        for (char c = 'a'; c <= 'z'; c++) {
            [order addObject:[NSString stringWithFormat:@"%c", c]];
        }
        
        __SMCSensorGroup_wildcardOrder = order;
    }
    
    return __SMCSensorGroup_wildcardOrder;
}

- (instancetype)initWithPattern:(NSString *)pattern usingAvailableSensors:(NSSet<NSString *> *)sensorList description:(NSString *)description {
    NSArray *seriesArray = [SMCSensorGroup seriesForPattern:pattern inSensorList:sensorList];
    if (!seriesArray.count) {
        return nil;
    }
    
    seriesArray = [self filteredSeriesArray:seriesArray];
    if (!seriesArray) {
        return nil;
    }
    
    if (self = [super init]) {
        [self processSeries:seriesArray pattern:pattern description:description];
    }
    
    return self;
}

- (void)processSeries:(NSArray<SMCSensorSeries *> *)seriesArray pattern:(NSString *)pattern description:(NSString *)description {
    NSMutableArray *names = [NSMutableArray array];
    NSMutableDictionary *parsedSensors = [NSMutableDictionary dictionary];
    
    if (seriesArray.count == 1) {
        // We only have one series in this group.  Interpret as several individual sensors in order.
        SMCSensorSeries *series = seriesArray[0];
        
        if (series.concurrentValues > 1 && ([series.characters[0] isEqualToString:@"0"] || [series.characters[0] isEqualToString:@"1"] )) {
            for (int i = 0; i < series.concurrentValues; i++) {
                NSString *sensorDescription = [NSString stringWithFormat:@"%@ %d", description, i + 1];
                NSString *sensorKey = [pattern stringByReplacingOccurrencesOfString:@"?" withString:series.characters[i]];
                
                parsedSensors[sensorKey] = sensorDescription;
                [names addObject:sensorKey];
            }
        }
        else if (series.concurrentValues == 1) {
            NSString *sensorDescription = description;
            NSString *sensorKey = [pattern stringByReplacingOccurrencesOfString:@"?" withString:series.characters[0]];
            
            parsedSensors[sensorKey] = sensorDescription;
            [names addObject:sensorKey];
        }
    }
    else {
        // We have multiple series matching this group.  Check that each series has 2 or 3 values.  If so, then take the 2nd value of each series and add it as the sensor.  Most Apple silicon sensors use this to monitor min/current/max sensor values.
        for (int i = 0; i < seriesArray.count; i++) {
            SMCSensorSeries *series = seriesArray[i];
            
            if (series.concurrentValues == 2 || series.concurrentValues == 3) {
                NSString *sensorDescription = [NSString stringWithFormat:@"%@ %d", description, i + 1];
                NSString *sensorKey = [pattern stringByReplacingOccurrencesOfString:@"?" withString:series.characters[1]];
                
                parsedSensors[sensorKey] = sensorDescription;
                [names addObject:sensorKey];
            }
        }
    }
    
    self.sensorKeyOrder = names;
    self.sensorKeyDescriptions = parsedSensors;
}

- (nullable NSArray<SMCSensorSeries *> *)filteredSeriesArray:(NSArray<SMCSensorSeries *> *)seriesArray {
    if (!seriesArray.count) {
        return nil;
    }
    
    // Check for an array of equal-length series.
    NSInteger firstDetectedConcurrentValues = seriesArray[0].concurrentValues;
    BOOL hasConcurrentSeries = YES;
    for (SMCSensorSeries *series in seriesArray) {
        if (series.concurrentValues != firstDetectedConcurrentValues) {
            hasConcurrentSeries = NO;
        }
    }
    if (hasConcurrentSeries) return seriesArray;
    
    // If we don't have equal-length series, then just return the first series.
    return @[seriesArray[0]];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"SMCSensorGroup %@", self.sensorKeyDescriptions];
}

@end

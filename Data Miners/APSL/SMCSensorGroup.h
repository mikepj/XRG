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
//  SMCSensorGroup.h
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A series is a group of SMC keys that happen in order.  An example might be if the group being looked at was Tp0?, then a series might be Tp0a, Tp0b, Tp0c.  In that case, `characters` would be ["a", "b", "c"] and `concurrentValues` would be 3.
@interface SMCSensorSeries: NSObject
/// The wildcard character for the series.
@property NSArray<NSString *> *characters;

- (instancetype)initWithStartingCharacter:(NSString *)character;

/// Add another subsequent character.
- (void)addCharacter:(NSString *)character;
/// The number of concurrent characters in this series that are valid SMC keys.
- (NSInteger)concurrentValues;

@end

@interface SMCSensorGroup : NSObject

/// The order of the sensor data.  These are raw SMC keys that act as keys in sensorKeyDescriptions.
@property NSArray<NSString *> *sensorKeyOrder;
/// The group raw SMC keys and their cooresponding description values.
@property NSDictionary *sensorKeyDescriptions;

/// Creates a key group from the sensor data or nil if no group could be matched for this pattern.
- (instancetype)initWithPattern:(NSString *)pattern usingAvailableSensors:(NSSet<NSString *> *)sensorList description:(NSString *)description;

@end

NS_ASSUME_NONNULL_END

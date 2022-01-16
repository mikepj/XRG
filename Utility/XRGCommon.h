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
//  XRGCommon.h
//

#import <Foundation/Foundation.h>

@interface XRGCommon : NSObject

/*! Calculates a damped max value using the previous max value, the current max value, and a base number the max should never fall below.
 * @param previousMax: The last max value.
 * @param currentMax: The current max value.
 * @param baseMax: The lowest max that should be returned.
 */
+ (CGFloat)dampedMaxUsingPreviousMax:(CGFloat)previousMax currentMax:(CGFloat)currentMax baseMax:(CGFloat)baseMax;

/*! Calculates a damped value using the previous value and the current value.
 * @param previousValue: The last value.
 * @param currentValue: The current value.
 */
+ (CGFloat)dampedValueUsingPreviousValue:(CGFloat)previousValue currentValue:(CGFloat)currentValue;

/*! Calculates a damped value using the previous value and the current value.
 * @param previousValue: The last value.
 * @param currentValue: The current value.
 * @param dampingCoefficient: The coefficient to use (between 0 and 1) that will dictate how much of a factor the previous value will have in the calculation.
 */
+ (CGFloat)dampedValueUsingPreviousValue:(CGFloat)previousValue currentValue:(CGFloat)currentValue dampingCoefficient:(CGFloat)dampingCoefficient;

+ (NSString *)formattedStringForBytes:(double)bytes;

@end

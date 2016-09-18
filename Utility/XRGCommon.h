//
//  XRGCommon.h
//  XRG
//
//  Created by Mike Piatek-Jimenez on 9/13/16.
//  Copyright © 2016 Gaucho Software. All rights reserved.
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

@end

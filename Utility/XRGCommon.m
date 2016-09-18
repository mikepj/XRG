//
//  XRGCommon.m
//  XRG
//
//  Created by Mike Piatek-Jimenez on 9/13/16.
//  Copyright © 2016 Gaucho Software. All rights reserved.
//

#import "XRGCommon.h"

@implementation XRGCommon

+ (CGFloat)dampedMaxUsingPreviousMax:(CGFloat)previousMax currentMax:(CGFloat)currentMax baseMax:(CGFloat)baseMax {
    return MAX(baseMax, [XRGCommon dampedValueUsingPreviousValue:previousMax currentValue:currentMax dampingCoefficient:0.95]);
}

+ (CGFloat)dampedValueUsingPreviousValue:(CGFloat)previousValue currentValue:(CGFloat)currentValue {
    return [XRGCommon dampedValueUsingPreviousValue:previousValue currentValue:currentValue dampingCoefficient:0.8];
}

+ (CGFloat)dampedValueUsingPreviousValue:(CGFloat)previousValue currentValue:(CGFloat)currentValue dampingCoefficient:(CGFloat)dampingCoefficient {
    return (previousValue * dampingCoefficient) + (currentValue * (1 - dampingCoefficient));
}

@end

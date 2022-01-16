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
//  XRGCommon.m
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

+ (NSString *)formattedStringForBytes:(double)bytes {
    if (bytes >= 112589990684262400.)
        return [NSString stringWithFormat:@"%.1fP", (bytes / 1125899906842624.)];
    else if (bytes >= 1125899906842624.)
        return [NSString stringWithFormat:@"%.2fP", (bytes / 1125899906842624.)];
    else if (bytes >= 109951162777600.)
        return [NSString stringWithFormat:@"%.1fT", (bytes / 1099511627776.)];
    else if (bytes >= 1099511627776.)
        return [NSString stringWithFormat:@"%.2fT", (bytes / 1099511627776.)];
    else if (bytes >= 107374182400.)
        return [NSString stringWithFormat:@"%.1fG", (bytes / 1073741824.)];
    else if (bytes >= 1073741824.)
        return [NSString stringWithFormat:@"%.2fG", (bytes / 1073741824.)];
    else if (bytes >= 104857600.)
        return [NSString stringWithFormat:@"%.1fM", (bytes / 1048576.)];
    else if (bytes >= 1048576.)
        return [NSString stringWithFormat:@"%.2fM", (bytes / 1048576.)];
    else if (bytes >= 102400.)
        return [NSString stringWithFormat:@"%.0fK", (bytes / 1024.)];
    else if (bytes >= 1024.)
        return [NSString stringWithFormat:@"%.1fK", (bytes / 1024.)];
    else
        return [NSString stringWithFormat:@"%ldB", (long)bytes];
}

@end

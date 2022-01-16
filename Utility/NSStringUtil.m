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
//  NSStringUtil.m
//

#import "NSStringUtil.h"

@implementation NSString (NSStringUtil)

- (BOOL)boolValue {
    if ([self isEqualToString:@""] || [self isEqualToString:@"0"] || [[self lowercaseString] isEqualToString:@"no"])
        return NO;
    else 
        return YES;
}

- (NSString *) stringWithoutXMLTags {
    NSInteger openIndex;
    NSInteger lastStringLength = [self length] + 1;
    
    if ([self length] == 0) return self;

    NSMutableString *newString = [NSMutableString stringWithCapacity:[self length]];
    [newString appendString:self];
    
    while ([newString length] < lastStringLength) {
        lastStringLength = [newString length];
        
        openIndex = [newString rangeOfString:@"<"].location;
        if (openIndex == NSNotFound) break;
        
        NSInteger tagLength = [[newString substringFromIndex:openIndex] rangeOfString:@">"].location;
        if (tagLength == NSNotFound || tagLength <= 0) break;
        tagLength++;
        
        if (openIndex + tagLength <= lastStringLength) 
            [newString replaceCharactersInRange:NSMakeRange(openIndex, tagLength) withString:@""];
        else
            break;
    }
    
    return newString;
}

@end

/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2009 Gaucho Software, LLC.
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
//  XRGListNode.m
//

#import "XRGListNode.h"


@implementation XRGListNode

- (XRGListNode *)init {
    object = nil;
    prev = nil;
    next = nil;
    
    return self;
}

- (XRGListNode *)initWithObject:(id)o {
    if (o != nil) object = [o retain];
    else          object = nil;
    
    prev = nil;
    next = nil;
    
    return self;
}

- (id)object {
    return object;
}

- (XRGListNode *)prev {
    return prev;
}

- (XRGListNode *)next {
    return next;
}

- (void)setObject:(id)o {
    if (object != nil) [object autorelease];
    object = nil;
    if (object != nil) object = [o retain];
}

- (void)setPrev:(XRGListNode *)p {
    if (prev != nil) [prev autorelease];
    prev = nil;
    if (p != nil) prev = [p retain];
}

- (void)setNext:(XRGListNode *)n {
    if (next != nil) [next autorelease];
    next = nil;
    if (n != nil) next = [n retain];
}

- (void)dealloc {
    if (object != nil) [object autorelease];
    if (next != nil)   [next autorelease];
    if (prev != nil)   [prev autorelease];
	
	[super dealloc];
}

@end

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
//  XRGList.m
//

#import "XRGList.h"


@implementation XRGList

- (XRGList *)init {
    startNode = nil;
    endNode = nil;
    numNodes = 0;
    
    return self;
}

- (void)addObject:(id)o {
    XRGListNode *newNode = [[[XRGListNode alloc] initWithObject:o] retain];
    if (numNodes == 0) {
        // set the startNode and the endNode to be this inital object, increment numNodes and return
        startNode = [newNode retain];
        endNode   = [newNode retain];
        numNodes++;
    }
    else {
        [endNode setNext:newNode];
        [newNode setPrev:endNode];
        [endNode autorelease];
        endNode = [newNode retain];
        numNodes++;
    }
    
    return;
}

- (void)addObject:(id)o atIndex:(int)index {
    if (index >= numNodes) {	// add it at the end
        [self addObject:o];
        return;
    }
    else if (index <= 0) {	// add it at the beginning
        XRGListNode *newNode = [[[XRGListNode alloc] initWithObject:o] retain];
        [newNode setNext:startNode];
        [startNode setPrev:newNode];
        [startNode autorelease];
        startNode = [newNode retain];
        numNodes++;
        return;
    }
    else {
        XRGListNode *newNode = [[[XRGListNode alloc] initWithObject:o] retain];
    
        // find the node right before the specified index
        int i = 0;
        XRGListNode *currentNode = startNode;
        for (i = 1; i < index; i++) {
            currentNode = [currentNode next];
        }
        
        // set up the new next node
        [newNode setNext:[currentNode next]];
        [[currentNode next] setPrev:newNode];
        
        // set up the new prev node (currentNode)
        [currentNode setNext:newNode];
        [newNode setPrev:currentNode];
        numNodes++;    
        return;
    }
}

- (NSArray *)getArray {
    if (startNode == nil) {
        return nil;
    }

    NSMutableArray *a = [NSMutableArray arrayWithCapacity:numNodes];
    XRGListNode *currentNode = startNode;
    while ([currentNode next] != nil) {
        [a addObject:[currentNode object]];
        currentNode = [currentNode next];
    }
    // add the last object
    [a addObject:[currentNode object]];
    
    return a;
}

- (id)getObjectAtIndex:(int)index {
    int i;
    XRGListNode *currentNode = startNode;
    
    for (i = 1; i <= index; i++) {
        currentNode = [currentNode next];
    }
    
    return [currentNode object];
}

- (void)moveObject:(id)o byOffset:(int)offset {
    // first find the old index
    int index;
    XRGListNode *currentNode = startNode;
    for (index = 0; index < numNodes; index++) {
        if ([currentNode object] == o) {  // we found the node index
            break;
        }
        currentNode = [currentNode next];
    }
    // now check the last object
    if ([currentNode object] != o) {  // the node is not in our list
        return;
    }
    
    // at this point index contains the index that we found the node at and currentNode contains the 
    // node at that index
    
    int newIndex = index + offset;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= numNodes) newIndex = numNodes - 1;
    
    [self addObject:[[self removeNode: currentNode] object] atIndex:newIndex];
}

- (void)moveObject:(id)o toIndex:(int)newIndex {
    // first find the old index
    int oldIndex;
    XRGListNode *currentNode = startNode;
    for (oldIndex = 0; oldIndex < numNodes; oldIndex++) {
        if ([currentNode object] == o) {  // we found the node index
            break;
        }
        currentNode = [currentNode next];
    }
    // now check the last object
    if ([currentNode object] != o) {  // the node is not in our list
        return;
    }
    
    // at this point oldIndex contains the index that we found the node at and currentNode contains the 
    // node at that index
    
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= numNodes) newIndex = numNodes - 1;
    
    [self addObject:[[self removeNode: currentNode] object] atIndex:newIndex];
}

- (id)removeObject:(id)o {
    XRGListNode *currentNode = startNode;
    while ([currentNode next] != nil) {
        if ([currentNode object] == o) {  // we found the node to remove
            return [self removeNode:currentNode];
        }
        currentNode = [currentNode next];
    }
    // now check the last object
    if ([currentNode object] == o) {  // we found the node to remove
        return [self removeNode:currentNode];
    }
    
    return nil;
}

- (XRGListNode *)removeNode:(XRGListNode *)node {
    if (startNode == endNode) {		// there's only one node in the list
        if (node == startNode) {	// if it's the one we want to delete, delete it
            [startNode autorelease];
            [endNode autorelease];
            startNode = endNode = nil;
        }
        else {				// otherwise we didn't find the node to delete
            return nil;
        }
    }
    else {				// there's more than one node in the list
        if (node == startNode) {    
            [[node next] setPrev:nil];
            [startNode autorelease];
            startNode = [[node next] retain];
        }
        else if (node == endNode) {
            [[node prev] setNext:nil];
            [endNode autorelease];
            endNode = [[node prev] retain];
        }
        else {
            [[node prev] setNext:[node next]];
            [[node next] setPrev:[node prev]];
        }
    }
    
    [node setPrev:nil];
    [node setNext:nil];
    [node autorelease];
    
    numNodes--;
    return node;
}

- (int)count {
    return numNodes;
}

- (void)dealloc {
    XRGListNode *currentNode = startNode;
    if (currentNode == nil) { 
		[super dealloc];
        return;
    }
    while ([currentNode next] != nil) {
        currentNode = [currentNode next];
        [[currentNode prev] autorelease];
    }
    [currentNode autorelease];
    [startNode autorelease];
    [endNode autorelease];
	
	[super dealloc];
}

@end

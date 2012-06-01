/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2012 Gaucho Software, LLC.
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
//  XRGFramelessWindow.m
//

#import "XRGFramelessWindow.h"
#include "definitions.h"

@implementation XRGFramelessWindow

- (void)setWindowSize:(NSSize)newSize {
    [self setWindowRect: NSMakeRect([self frame].origin.x,
                                    [self frame].origin.y,
                                    newSize.width,
                                    newSize.height)
    ];
}

- (NSRect)setWindowRect:(NSRect)newRect {
    return [self setWindowRect:newRect animate:NO];
}

- (NSRect)setWindowRect:(NSRect)newRect animate:(bool)yesNo {
    // Check if it's too small
    NSSize newSize = newRect.size;
    if (newSize.width < minSize.width) {
        newSize.width      = minSize.width;
        newRect.size.width = minSize.width;        
    }
    if (newSize.height < minSize.height) {
        newSize.height      = minSize.height;
        newRect.size.height = minSize.height;
    }
    
    // Check if it's too big
    // First get the screen that it's on.
    NSRect screenFrame = [self getFullScreenFrame:newRect];
    if (screenFrame.size.width < newRect.size.width)
        newRect.size.width = screenFrame.size.width;
    if (screenFrame.size.height < newRect.size.height)
        newRect.size.height = screenFrame.size.height;
    
    // Check the location
    newRect = [self checkWindowLocation:newRect];
       
    [self setFrame:newRect display:YES animate:yesNo]; 
	[self invalidateCursorRectsForView:[self contentView]];
    [self windowDidResize:nil];
    [self redrawWindow];
    return newRect;
}

- (NSRect)checkWindowLocation:(NSRect)newRect {
    // make sure the window stays on-screen
    NSRect screenFrame = [self getFullScreenFrame:newRect];
    
    // top
    if ((newRect.origin.y + newRect.size.height) > (screenFrame.origin.y + screenFrame.size.height)) {
        if (isResizingTL || isResizingTC || isResizingTR) 
            newRect.size.height = screenFrame.origin.y + screenFrame.size.height - newRect.origin.y;
        else
            newRect.origin.y = (screenFrame.origin.y + screenFrame.size.height) - newRect.size.height;
    }
    // left
    if (newRect.origin.x < screenFrame.origin.x) {
        if (isResizingTL || isResizingML || isResizingBL) {
            newRect.size.width -= screenFrame.origin.x - newRect.origin.x;
            newRect.origin.x = screenFrame.origin.x;
        }
        else {
            newRect.origin.x = screenFrame.origin.x;
        }
    }
    // bottom
    if (newRect.origin.y < screenFrame.origin.y) {
        if (isResizingBL || isResizingBC || isResizingBR) {
            newRect.size.height -= screenFrame.origin.y - newRect.origin.y;
            newRect.origin.y = screenFrame.origin.y;
        }
        else {
            newRect.origin.y = screenFrame.origin.y;
        }
    }
    // right
    if ((newRect.origin.x + newRect.size.width) > (screenFrame.origin.x + screenFrame.size.width)) {
        if (isResizingBR || isResizingMR || isResizingTR)
            newRect.size.width = screenFrame.origin.x + screenFrame.size.width - newRect.origin.x;
        else
            newRect.origin.x = screenFrame.origin.x + (screenFrame.size.width - newRect.size.width);
    }
    
    // sticky window code
    if (stickyWindow) {
        // top
        if (screenFrame.origin.y + screenFrame.size.height - newRect.origin.y - newRect.size.height <= 5) 
            newRect.origin.y = screenFrame.origin.y + (screenFrame.size.height - newRect.size.height);
        // left
        if (newRect.origin.x - screenFrame.origin.x <= 5) 
            newRect.origin.x = screenFrame.origin.x;
        // bottom
        if (newRect.origin.y - screenFrame.origin.y <= 5)
            newRect.origin.y = screenFrame.origin.y;
        // right
        if (screenFrame.origin.x + screenFrame.size.width - newRect.origin.x - newRect.size.width <= 5) 
            newRect.origin.x = screenFrame.origin.x + (screenFrame.size.width - newRect.size.width);
    }
    
    return newRect;
}

- (NSRect)getFullScreenFrame:(NSRect)windowFrame {
    NSArray *screens = [NSScreen screens];
    int i = 0;
    NSPoint centerOfWindowFrame = NSMakePoint(windowFrame.origin.x + (windowFrame.size.width / 2), 
                                              windowFrame.origin.y + (windowFrame.size.height / 2));
    
    for (i = 0; i < [screens count]; i++) {
        NSRect frame = [[screens objectAtIndex:i] visibleFrame];
        if (centerOfWindowFrame.x >= frame.origin.x && 
            centerOfWindowFrame.x <= frame.origin.x + frame.size.width &&
            centerOfWindowFrame.y >= frame.origin.y &&
            centerOfWindowFrame.y <= frame.origin.y + frame.size.height) 
        {
            // the center of the newRect is on the i'th screen, break out of the loop
            break;
        }
    }
    NSRect screenFrame, fullFrame;
    if (i >= [screens count]) {  
        // The center isn't in any of the screens, assume the window's current screen
        screenFrame = [[self screen] visibleFrame];
        fullFrame = [[self screen] frame];
    }
    else {
        screenFrame = [[screens objectAtIndex:i] visibleFrame];
        fullFrame = [[screens objectAtIndex:i] frame];
    }
    screenFrame.size.width = fullFrame.size.width;
    screenFrame.size.height += screenFrame.origin.y - fullFrame.origin.y;
    screenFrame.origin.x = fullFrame.origin.x;
    screenFrame.origin.y = fullFrame.origin.y;
    
    return screenFrame;
}

- (void)redrawWindow {
    [[self contentView] setNeedsDisplay:YES];
}

- (int)borderWidth {
    return borderWidth;
}

- (void)setBorderWidth:(int)width {
    borderWidth = width;
}

- (void)setMinSize:(NSSize)size {
    minSize = size;
}

//// Event Handlers ////

//We start tracking the a drag operation here when the user first clicks the mouse,
//to establish the initial location.
- (void)mouseDown:(NSEvent *)theEvent {
    NSRect windowFrame = [self frame];
        
    isInWindowDrag = YES;

    //grab the mouse location in global coordinates
    initialMouseClickLocation = [self convertBaseToScreen:[theEvent locationInWindow]];
    initialWindowLocation = windowFrame.origin;
    initialWindowSize     = windowFrame.size;
    initialLocation = [self convertBaseToScreen:[theEvent locationInWindow]];
    initialLocation.x -= windowFrame.origin.x;
    initialLocation.y -= windowFrame.origin.y;
        
    int bound1 = borderWidth;
    int bound2 = 25;
    
    if (initialLocation.x < bound1) {
        if (initialLocation.y < bound2) {
            isResizingBL = YES;
        }
        else if (initialLocation.y >= bound2 && initialLocation.y <= windowFrame.size.height - bound2) {
            isResizingML = YES;
        }
        else if (initialLocation.y > windowFrame.size.height - bound2) {
            isResizingTL = YES;
        }
    }
    else if (initialLocation.x >= bound1 && 
             initialLocation.x <  bound2) 
    {
        if (initialLocation.y < bound1) {
            isResizingBL = YES;
        }
        if (initialLocation.y > windowFrame.size.height - bound1) {
            isResizingTL = YES;
        }
    }
    else if (initialLocation.x >= bound2 && 
             initialLocation.x <= windowFrame.size.width - bound2) 
    {
        if (initialLocation.y < bound1) {
            isResizingBC = YES;
        }
        if (initialLocation.y > windowFrame.size.height - bound1) {
            isResizingTC = YES;
        }
    }
    else if (initialLocation.x >  windowFrame.size.width - bound2 && 
             initialLocation.x <= windowFrame.size.width - bound1) 
    {
        if (initialLocation.y < bound1) {
            isResizingBR = YES;
        }
        if (initialLocation.y > windowFrame.size.height - bound1) {
            isResizingTR = YES;
        }
    }
    else if (initialLocation.x > windowFrame.size.width - bound1) {
        if (initialLocation.y < bound2) {
            isResizingBR = YES;
        }
        else if (initialLocation.y >= bound2 && initialLocation.y <= windowFrame.size.height - bound2) {
            isResizingMR = YES;
        }
        else if (initialLocation.y > windowFrame.size.height - bound2) {
            isResizingTR = YES;
        }
    }
}

- (void)mouseUp:(NSEvent *)theEvent {
    isResizingTL = isResizingTC = isResizingTR = NO;
    isResizingML = isResizingMR = NO;
    isResizingBL = isResizingBC = isResizingBR = NO;
    
    // Save the window size and location.
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setFloat: [self frame].size.width  forKey:XRG_windowWidth];
    [defs setFloat: [self frame].size.height forKey:XRG_windowHeight];
    [defs setFloat: [self frame].origin.x    forKey:XRG_windowOriginX];
    [defs setFloat: [self frame].origin.y    forKey:XRG_windowOriginY];
    [defs synchronize];

    isInWindowDrag = NO;
}

// Once the user starts dragging the mouse, we move the window with it.
- (void)mouseDragged:(NSEvent *)theEvent {
    if ((isResizingTL || isResizingTC || isResizingTR ||
         isResizingML || isResizingMR ||
         isResizingBL || isResizingBC || isResizingBR) && minimized)
        return;

    NSPoint currentLocation;
    NSPoint newOrigin;
    NSRect windowFrame = [self frame];

    //grab the current global mouse location; we could just as easily get the mouse location
    currentLocation = [self convertBaseToScreen: [self mouseLocationOutsideOfEventStream]];
    newOrigin.x = currentLocation.x - initialLocation.x;
    newOrigin.y = currentLocation.y - initialLocation.y;

    NSRect newFrameRect = [self frame];
    if (isResizingTL) {
        // set the new window size   
        newFrameRect.size.width = initialWindowSize.width + initialMouseClickLocation.x - currentLocation.x;
        newFrameRect.size.height = initialWindowSize.height + currentLocation.y - initialMouseClickLocation.y; 
        
        // set the new window origin
        if ([self frame].size.width != minSize.width) {
            newFrameRect.origin.x = initialWindowLocation.x - initialMouseClickLocation.x + currentLocation.x;
            newFrameRect.origin.y = initialWindowLocation.y;
        }
        else {
            newFrameRect.origin.x = initialWindowLocation.x + initialWindowSize.width - minSize.width;
            newFrameRect.origin.y = initialWindowLocation.y;
        }
                
        [self setWindowRect:newFrameRect];
    }
    else if (isResizingTC) {
        // resize the window
        newFrameRect.size.width = initialWindowSize.width;
        newFrameRect.size.height = initialWindowSize.height + currentLocation.y - initialMouseClickLocation.y; 
                            
        [self setWindowRect:newFrameRect];
    }
    else if (isResizingTR) {
        // resize the window
        newFrameRect.size.width = initialWindowSize.width + currentLocation.x - initialMouseClickLocation.x;
        newFrameRect.size.height = initialWindowSize.height + currentLocation.y - initialMouseClickLocation.y;

        [self setWindowRect:newFrameRect];
    }
    else if (isResizingML) {
        // resize the window
        newFrameRect.size.width = initialWindowSize.width + initialMouseClickLocation.x - currentLocation.x;
        newFrameRect.size.height = initialWindowSize.height;
        
        // move the window
        if ([self frame].size.width != minSize.width) {
            newFrameRect.origin.x = initialWindowLocation.x - initialMouseClickLocation.x + currentLocation.x;
            newFrameRect.origin.y = initialWindowLocation.y;
        }
        else {
            newFrameRect.origin.x = initialWindowLocation.x + initialWindowSize.width - minSize.width;
            newFrameRect.origin.y = initialWindowLocation.y;
        }

        [self setWindowRect:newFrameRect];
    }
    else if (isResizingMR) {
        // resize the window
        newFrameRect.size.width = initialWindowSize.width + currentLocation.x - initialMouseClickLocation.x;
        newFrameRect.size.height = initialWindowSize.height;

        [self setWindowRect:newFrameRect];
    }
    else if (isResizingBL) {
        // resize the window
        newFrameRect.size.width = initialWindowSize.width + initialMouseClickLocation.x - currentLocation.x;
        newFrameRect.size.height = initialWindowSize.height + initialMouseClickLocation.y - currentLocation.y;
        
        // move the window
        if ([self frame].size.width == minSize.width && [self frame].size.height == minSize.height) {
            newFrameRect.origin.x = initialWindowLocation.x + initialWindowSize.width - minSize.width;
            newFrameRect.origin.y = initialWindowLocation.y + initialWindowSize.height - minSize.height;
        }
        else if ([self frame].size.width == minSize.width) {
            newFrameRect.origin.x = initialWindowLocation.x + initialWindowSize.width - minSize.width;
            newFrameRect.origin.y = initialWindowLocation.y - initialMouseClickLocation.y + currentLocation.y;
        }
        else if ([self frame].size.height == minSize.height) {
            newFrameRect.origin.x = initialWindowLocation.x - initialMouseClickLocation.x + currentLocation.x;
            newFrameRect.origin.y = initialWindowLocation.y + initialWindowSize.height - minSize.height;
        }
        else {
            newFrameRect.origin.x = initialWindowLocation.x - initialMouseClickLocation.x + currentLocation.x;
            newFrameRect.origin.y = initialWindowLocation.y - initialMouseClickLocation.y + currentLocation.y;
        }

        [self setWindowRect:newFrameRect];
    }
    else if (isResizingBC) {
        // resize the window
        newFrameRect.size.width = initialWindowSize.width;
        newFrameRect.size.height = initialWindowSize.height + initialMouseClickLocation.y - currentLocation.y;
        
        // move the window
        if ([self frame].size.height != minSize.height) {
            newFrameRect.origin.x = initialWindowLocation.x;
            newFrameRect.origin.y = initialWindowLocation.y - initialMouseClickLocation.y + currentLocation.y;
        }
        else {
            newFrameRect.origin.x = initialWindowLocation.x;
            newFrameRect.origin.y = initialWindowLocation.y + initialWindowSize.height - minSize.height;
        }

        [self setWindowRect:newFrameRect];
    }
    else if (isResizingBR) {
        // resize the window
        newFrameRect.size.width = initialWindowSize.width + currentLocation.x - initialMouseClickLocation.x;
        newFrameRect.size.height = initialWindowSize.height + initialMouseClickLocation.y - currentLocation.y;

        // move the window
        if ([self frame].size.height != minSize.height) {
            newFrameRect.origin.x = initialWindowLocation.x;
            newFrameRect.origin.y = initialWindowLocation.y - initialMouseClickLocation.y + currentLocation.y;
        }
        else {
            newFrameRect.origin.x = initialWindowLocation.x;
            newFrameRect.origin.y = initialWindowLocation.y + initialWindowSize.height - minSize.height;
        }

        [self setWindowRect:newFrameRect];
    }
    else {
        NSRect newWindowFrame = NSMakeRect(newOrigin.x,
                                           newOrigin.y,
                                           windowFrame.size.width,
                                           windowFrame.size.height);
                                           
        newWindowFrame = [self checkWindowLocation:newWindowFrame];
        
        [self setFrameOrigin:newWindowFrame.origin];
        
    }
}

- (bool)minimized {
    return minimized;
}

- (void)setMinimized:(bool)onOff {
    minimized = onOff;
}

- (bool)isInWindowDrag {
    return isInWindowDrag;
}

@end

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
//  XRGBackgroundView.m
//

#import "XRGBackgroundView.h"
#import "XRGGraphWindow.h"
#import "XRGGenericView.h"
#import "XRGAppDelegate.h"
#import "XRGPrefController.h"
#import <sys/sysctl.h>

@implementation XRGBackgroundView

- (void)awakeFromNib {  
    parentWindow = (XRGGraphWindow *)[self window]; 
    
    appSettings = [parentWindow appSettings];
    moduleManager = [parentWindow moduleManager];
    
	self.hostname = @"XRG";
	[self getHostname];
	
    // Find out whether or not the App's UI is being displayed.
    NSString *plistPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Contents/Info.plist"];
    NSString *error;        
    NSPropertyListFormat format;

    NSData *infoPlist = [NSData dataWithContentsOfFile:plistPath];
    
    if ([infoPlist length] != 0) {
        NSMutableDictionary *d = [NSPropertyListSerialization propertyListFromData:infoPlist
                                                                  mutabilityOption:NSPropertyListImmutable
                                                                            format:&format
                                                                  errorDescription:&error];
        
        if (d) {
            if (!d[@"NSUIElement"] || [d[@"NSUIElement"] isEqualToString:@"NO"]) {
                uiIsHidden = NO;
            }
            else {
                uiIsHidden = YES;
            }
        }
    }
    
    isVertical = YES;
    inInner = inOuter = inHeader = NO;
    self.clickedMinimized = NO;
    lastWidth = [self frame].size.width;
    
    [self registerForDraggedTypes:@[NSFilenamesPboardType]];
    
    [parentWindow setBackgroundView: self];
}

- (void)setFrame:(NSRect)frame {
	[super setFrame:frame];
	[parentWindow.moduleManager windowChangedToSize:self.frame.size];
}

- (void)offsetDrawingOrigin:(NSSize)offset {
    [self translateOriginToPoint: NSMakePoint(offset.width, offset.height)];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize {
}

- (void)drawRect:(NSRect)rect{    
    // rotate the coordinate system if necessary
    if (![moduleManager graphOrientationVertical] && isVertical) {
        // first update our size:
        NSRect f = [parentWindow frame];
        f.origin = [self frame].origin;
        [self setFrame:f];
        // switch from vertical to horizontal
        [self setBoundsRotation: 90];
        [self translateOriginToPoint: NSMakePoint(0, 0 - [self frame].size.width)];
        isVertical = NO;
        lastWidth = [self frame].size.width;
    }
    if ([moduleManager graphOrientationVertical] && !isVertical) {
        // first update our size:
        NSRect f = [parentWindow frame];
        f.origin = [self frame].origin;
        [self setFrame:f];
        // switch from horizontal to vertical
        [self translateOriginToPoint: NSMakePoint(0, lastWidth)];
        [self setBoundsRotation: 0];
        [self setAutoresizesSubviews:YES];
        isVertical = YES;
    }
    
    if (!isVertical) {
        if (lastWidth != [self frame].size.width) {
            [self translateOriginToPoint:NSMakePoint(0, 0 - ([self frame].size.width - lastWidth))];
            lastWidth = [self frame].size.width;
        }
    }
	
    NSGraphicsContext *gc = [NSGraphicsContext currentContext]; 

    int borderWidth = [parentWindow borderWidth];
    
    NSRect tmpRect = [self bounds];
    tmpRect.origin.x += borderWidth;
    tmpRect.origin.y = tmpRect.size.height - borderWidth - [appSettings textRectHeight];
    tmpRect.size.width -= borderWidth * 2;
    tmpRect.size.height = [appSettings textRectHeight];

	[[appSettings borderColor] set];
	NSRectFill([self bounds]);

    [[appSettings backgroundColor] set];
    NSRectFill(tmpRect);    
        
    NSRect titleRect;
    if (isVertical) {    
        titleRect = NSMakeRect(borderWidth, 
                               [self bounds].size.height - borderWidth - [appSettings textRectHeight], 
                               [self bounds].size.width - 2 * borderWidth,
                               [appSettings textRectHeight]);
    }
    else {
        titleRect = NSMakeRect(borderWidth, 
                               [self bounds].size.height - borderWidth - [appSettings textRectHeight], 
                               [self bounds].size.width - 2 * borderWidth,
                               [appSettings textRectHeight]);
    }
    
    [gc setShouldAntialias:[appSettings antialiasText]];

    NSString *title = [appSettings windowTitle];
    if (!title || [title isEqualToString:@""]) {
		[self.hostname drawInRect:titleRect withAttributes:[appSettings alignCenterAttributes]];
    }
    else {
        [title drawInRect:titleRect withAttributes:[appSettings alignCenterAttributes]];
    }
    
    [gc setShouldAntialias:YES];
}

- (void)getHostname {
	// Run this in a background thread because it might take a little bit of time.
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSProcessInfo *proc = [NSProcessInfo processInfo];
		NSString *s = [proc hostName];
		NSRange r = [s rangeOfString:@"."];
		
		NSString *newHostname = @"XRG";
		if (r.location == NSNotFound) {
			if ([s length] > 0)	newHostname = s;
		}
		else {
			if (r.location != 0) newHostname = [s substringToIndex:r.location];
		}
		self.hostname = newHostname;

		dispatch_async(dispatch_get_main_queue(), ^{
			[self setNeedsDisplay:YES];
		});
	});

	@autoreleasepool {
	}
}

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent {       
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {       
    return YES;
}

- (BOOL)acceptsMouseMovedEvents {       
    return YES;
}

- (void)mouseDownAction:(NSEvent *)theEvent { 
    if ([appSettings windowLevel] == kCGDesktopWindowLevel) [NSApp preventWindowOrdering];
 	NSInteger originalWindowLevel = [parentWindow level];
	viewPointClicked = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	
	// Are we supposed to resize a module?
//	shouldResizeModule = -1;
//	int i;
//	for (i = 0; i < [resizeRects count]; i++) {
//		NSRect resizeRect = [[resizeRects objectAtIndex:i] rectValue];
//		if (NSPointInRect(viewPointClicked, resizeRect)) {
//			shouldResizeModule = i;
//			
//			while ((theEvent = [[self window] nextEventMatchingMask:NSLeftMouseUpMask | NSLeftMouseDraggedMask])) {
//				if ([theEvent type] == NSLeftMouseUp) break;
//
//				NSPoint currentMousePosition = [self convertPoint:[theEvent locationInWindow] fromView:nil];
//				
//				float delta = [moduleManager graphOrientationVertical] ? currentMousePosition.y - viewPointClicked.y : currentMousePosition.x - viewPointClicked.x;
//				float actualMoveAmount = [moduleManager resizeModuleNumber:shouldResizeModule byDelta:delta];
//				
//				viewPointClicked = currentMousePosition;
//				[[self window] invalidateCursorRectsForView:self];
//			}			
//			return;
//		}
//	}
	
    // if it's a double click in the title bar, minimize the window
    if ([theEvent clickCount] == 2) { 
		NSRect frame    = [self bounds];
		int borderWidth = [parentWindow borderWidth];
		NSRect headerRect = NSMakeRect(frame.origin.x + borderWidth, frame.origin.y + frame.size.height - borderWidth - [appSettings textRectHeight], frame.size.width, [appSettings textRectHeight]);
        if (NSPointInRect(viewPointClicked, headerRect)) {
            if ([parentWindow minimized]) {
                self.clickedMinimized = NO;
                [self expandWindow];
            }
            else {
                if (self.clickedMinimized == NO) {
                    self.clickedMinimized = YES;
                    [self minimizeWindow];
                }
                else {
                    self.clickedMinimized = NO;
                    
                    // If the window was brought to the front when expanding, we need to put it back.
                    [parentWindow setLevel:originalWindowLevel];
                }
            }
        }
    }
}

- (void)mouseDragged:(NSEvent *)theEvent {
//	NSPoint currentMousePosition = [[self window] convertBaseToScreen:[[self window] mouseLocationOutsideOfEventStream]];
//	NSLog(@"should resize: %d", shouldResizeModule);
//	if (shouldResizeModule != -1) {
//		float delta = [moduleManager graphOrientationVertical] ? currentMousePosition.y - viewPointClicked.y : currentMousePosition.x - viewPointClicked.x;
//		[moduleManager resizeModuleNumber:shouldResizeModule byDelta:delta];
//	}
//	else {
		[parentWindow mouseDragged:theEvent];
//	}
}

- (void)mouseUp:(NSEvent *)theEvent {
    [parentWindow mouseUp:theEvent];
}

- (void)minimizeWindow {
    if ([parentWindow minimized]) return;
    
    int i;
    NSRect windowFrame;
    
    // Figure out what the new rect should be and save the old rect.
    if ([moduleManager graphOrientationVertical]) {
        windowFrame = [parentWindow frame];
        unminimizedRect = windowFrame;
        
        if ([appSettings minimizeUpDown] == 0) { // minimize up
            windowFrame.origin.y = windowFrame.origin.y + windowFrame.size.height - ((2 * [parentWindow borderWidth]) + [appSettings textRectHeight]);
            windowFrame.size.height = (2 * [parentWindow borderWidth]) + [appSettings textRectHeight];
        }
        else { // minimize down
            windowFrame.size.height = (2 * [parentWindow borderWidth]) + [appSettings textRectHeight];
        }
        
        [parentWindow setMinimized:YES];
        [parentWindow setMinSize:[moduleManager getMinSize]];
    }
    else {
        windowFrame = [parentWindow frame];
        unminimizedRect = windowFrame;
        
        if ([appSettings minimizeUpDown] == 0) { // minimize left
            windowFrame.size.width = (2 * [parentWindow borderWidth]) + [appSettings textRectHeight];
        }
        else { // minimize right
            windowFrame.origin.x = windowFrame.origin.x + windowFrame.size.width - ((2 * [parentWindow borderWidth]) + [appSettings textRectHeight]);
            windowFrame.size.width = (2 * [parentWindow borderWidth]) + [appSettings textRectHeight];
        }
        
        [parentWindow setMinimized:YES];
        [parentWindow setMinSize:[moduleManager getMinSize]];
    }

    // Hide the modules.
    NSArray *a = [moduleManager displayList];
    for (i = 0; i < [a count]; i++) {
        XRGGenericView *ref = [a[i] reference];
        if (ref != nil) {
            [ref setHidden:YES];
        }
    }
    
    // Resize the window.
	[parentWindow setFrame:windowFrame display:YES animate:YES];
    
    // Put the window level back where it was.
    if ([appSettings foregroundWhenExpanding]) {
        if ([appSettings windowLevel] == 0)
        {
            [parentWindow setLevel:NSNormalWindowLevel];
        }
        else if ([appSettings windowLevel] == 1)
        {
            [parentWindow setLevel:NSFloatingWindowLevel];
        }
        else {
            [parentWindow setLevel:kCGDesktopWindowLevel];
        }
    }
	
	// Save in the preferences.
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:XRG_windowIsMinimized];
}

- (void)expandWindow {
    if (![parentWindow minimized]) return;

    int i;
    NSRect windowFrame;
    
    // Figure out what our new rect should be.
    if ([moduleManager graphOrientationVertical]) {
        windowFrame = [parentWindow frame];
		if ([appSettings minimizeUpDown] == 0) { // maximize down
			windowFrame.origin.y -= unminimizedRect.size.height - windowFrame.size.height;
		}
		else { // maximize up
			// windowFrame.origin.y is fine as-is
		}
        windowFrame.size.height = unminimizedRect.size.height;
        [parentWindow setMinimized:NO];
        [parentWindow setMinSize:[moduleManager getMinSize]];
    }
    else {
        windowFrame = [parentWindow frame];
		if ([appSettings minimizeUpDown] == 0) { // maximize right
			// windowFrame.origin.x is fine as-is
		}
		else { // maximize left
			windowFrame.origin.x -= unminimizedRect.size.width - windowFrame.size.width;
		}
        windowFrame.size.width = unminimizedRect.size.width;
        [parentWindow setMinimized:NO];
        [parentWindow setMinSize:[moduleManager getMinSize]];
    }
        
    if ([appSettings foregroundWhenExpanding] && [appSettings autoExpandGraph]) 
        [parentWindow setLevel:NSFloatingWindowLevel];

    // Finally, resize the window.
	[parentWindow setFrame:windowFrame display:YES animate:YES];
	
	// Reset the cursor rects.
	[self resetCursorRects];
	
	// Show the modules again.
    NSArray *a = [moduleManager displayList];
    for (i = 0; i < [a count]; i++) {
        XRGGenericView *ref = [a[i] reference];
        if (ref != nil) {
            [ref setHidden:NO];
        }
    }
    	
	// Save in the preferences.
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:XRG_windowIsMinimized];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[NSMenu alloc] initWithTitle:@"Background View"];
    NSMenuItem *tMI;

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"About XRG" action:@selector(openAboutBox:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Preferences..." action:@selector(openPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"XRG Help" action:@selector(openHelp:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    [myMenu addItem:[NSMenuItem separatorItem]];

    if (uiIsHidden) {
        tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Show XRG Dock Icon (After Restart)" action:@selector(showUI:) keyEquivalent:@""];
        [myMenu addItem:tMI];
    }
    else {
        tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Hide XRG Dock Icon (After Restart)" action:@selector(hideUI:) keyEquivalent:@""];
        [myMenu addItem:tMI];
    }

    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Quit XRG" action:@selector(quit:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    return myMenu;
}

- (void)openAboutBox:(NSEvent *)theEvent {
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:self];
}

- (void)openHelp:(NSEvent *)theEvent {
    [[NSApplication sharedApplication] showHelp:self];
}

- (void)openPreferences:(NSEvent *)theEvent {
    [[parentWindow controller] showPrefsWithPanel:@"General"];
}

- (void)hideUI:(NSEvent *)theEvent {
    NSString *plistPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Contents/Info.plist"];
    NSString *error;        
    NSPropertyListFormat format;

    NSData *infoPlist = [NSData dataWithContentsOfFile:plistPath];
    
    if ([infoPlist length] == 0) {
        NSRunInformationalAlertPanel(@"Error", @"Failed to modify the application settings.", @"OK", nil, nil);
        return;
    }

    NSMutableDictionary *d = [NSPropertyListSerialization propertyListFromData:infoPlist
                                                              mutabilityOption:NSPropertyListImmutable
                                                                        format:&format
                                                              errorDescription:&error];
                                                       
    if (!d) {
        NSRunInformationalAlertPanel(@"Error", @"Failed to modify the application settings.", @"OK", nil, nil);
        NSLog(@"%@", error);
        return;
    }
    else {
        d[@"NSUIElement"] = @"YES";
        
        NSData *newPlist = [NSPropertyListSerialization dataFromPropertyList:d
                                                                      format:NSPropertyListXMLFormat_v1_0
                                                            errorDescription:&error];
                                                        
        if (newPlist) {
            if (![newPlist writeToFile:plistPath atomically:YES]) {
                NSRunInformationalAlertPanel(@"Error", @"Failed to modify the application settings.", @"OK", nil, nil);
            }
        }
        else {
			NSLog(@"%@", error);
            return;
        }
    }
    
    // Finally, touch our .app directory to update the cache.
    [NSTask launchedTaskWithLaunchPath:@"/usr/bin/touch" arguments:@[[[NSBundle mainBundle] bundlePath]]];    
    
    NSRunInformationalAlertPanel(@"Hiding the XRG Dock Icon", @"Please re-launch XRG for changes to take effect.", @"OK", nil, nil);
    uiIsHidden = YES;
}

- (void)showUI:(NSEvent *)theEvent {
    NSString *plistPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Contents/Info.plist"];
    NSString *error;        
    NSPropertyListFormat format;

    NSData *infoPlist = [NSData dataWithContentsOfFile:plistPath];
    
    if ([infoPlist length] == 0) {
        NSRunInformationalAlertPanel(@"Error", @"Failed to modify the application settings.", @"OK", nil, nil);
        return;
    }

    NSMutableDictionary *d = [NSPropertyListSerialization propertyListFromData:infoPlist
                                                              mutabilityOption:NSPropertyListImmutable
                                                                        format:&format
                                                              errorDescription:&error];
                                                       
    if (!d) {
        NSRunInformationalAlertPanel(@"Error", @"Failed to modify the application settings.", @"OK", nil, nil);
        NSLog(@"%@", error);
        return;
    }
    else {
        d[@"NSUIElement"] = @"NO";
        
        NSData *newPlist = [NSPropertyListSerialization dataFromPropertyList:d
                                                                      format:NSPropertyListXMLFormat_v1_0
                                                            errorDescription:&error];
                                                        
        if (newPlist) {
            if (![newPlist writeToFile:plistPath atomically:YES]) {
                NSRunInformationalAlertPanel(@"Error", @"Failed to modify the application settings.", @"OK", nil, nil);
            }
        }
        else {
			NSLog(@"%@", error);
            return;
        }
    }
    
    // Finally, touch our .app directory to update the cache.
    [NSTask launchedTaskWithLaunchPath:@"/usr/bin/touch" arguments:@[[[NSBundle mainBundle] bundlePath]]];    

    NSRunInformationalAlertPanel(@"Showing the XRG Dock Icon", @"Please re-launch XRG for changes to take effect.", @"OK", nil, nil);
    uiIsHidden = NO;
}

- (void)quit:(NSEvent *)theEvent {
    [[NSApplication sharedApplication] terminate:self];
} 

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pasteBoard;
    NSDragOperation sourceDragMask;

    sourceDragMask = [sender draggingSourceOperationMask];
    pasteBoard = [sender draggingPasteboard];

    if ( [[pasteBoard types] containsObject:NSFilenamesPboardType] ) {
        if (sourceDragMask & NSDragOperationCopy) {
            NSArray *files = [pasteBoard propertyListForType:NSFilenamesPboardType];
            if ([files count] == 1 && [files[0] hasSuffix:@".xtf"]) {
                return NSDragOperationCopy;
            }
            else {
                return NSDragOperationNone;
            }
        }
    }
    return NSDragOperationNone;
}    

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pasteBoard = [sender draggingPasteboard];
    
    if ([[pasteBoard types] containsObject:NSFilenamesPboardType]) {
        NSArray *files = [pasteBoard propertyListForType:NSFilenamesPboardType];
        
        // Check the same conditions as in draggingEntered:
        if ([files count] == 1 && [files[0] hasSuffix:@".xtf"]) {
            NSString *path;
            NSData *themeData;
            NSString *error;        
            NSPropertyListFormat format;
            NSDictionary *themeDictionary;
            
            /* if successful, open file under designated name */
            path = files[0];

            themeData = [NSData dataWithContentsOfFile:path];
            
            if ([themeData length] == 0) {
                NSRunInformationalAlertPanel(@"Error", @"The theme file dragged is not a valid theme file.", @"OK", nil, nil);
            }

            themeDictionary = [NSPropertyListSerialization propertyListFromData:themeData
                                                               mutabilityOption:NSPropertyListImmutable
                                                                         format:&format
                                                               errorDescription:&error];
                                                               
            if (!themeDictionary) {
                NSRunInformationalAlertPanel(@"Error", @"The theme file dragged is not a valid theme file.", @"OK", nil, nil);
				NSLog(@"%@", error);
            }
            else {
				[appSettings readXTFDictionary:themeDictionary];                
                [self setNeedsDisplay:YES];
            }
        }
    }
    	
	[[[NSApp delegate] prefController] setUpColorPanel];

    return YES;
}

- (void) resetCursorRects {
	NSRect bounds = [self bounds];
	int border = [parentWindow borderWidth];
	BOOL vertical = [moduleManager graphOrientationVertical];
	
	[self addCursorRect:NSMakeRect(bounds.origin.x, bounds.origin.y, border, bounds.size.height) 
				 cursor:vertical ? [NSCursor resizeLeftRightCursor] : [NSCursor resizeUpDownCursor]];
	[self addCursorRect:NSMakeRect(bounds.origin.x + bounds.size.width - border, bounds.origin.y, border, bounds.size.height)
				 cursor:vertical ? [NSCursor resizeLeftRightCursor] : [NSCursor resizeUpDownCursor]];
	
	[self addCursorRect:NSMakeRect(bounds.origin.x, bounds.origin.y, bounds.size.width, border)
				 cursor:vertical ? [NSCursor resizeUpDownCursor] : [NSCursor resizeLeftRightCursor]];
	[self addCursorRect:NSMakeRect(bounds.origin.x, bounds.origin.y + bounds.size.height - border, bounds.size.width, border)
				 cursor:vertical ? [NSCursor resizeUpDownCursor] : [NSCursor resizeLeftRightCursor]];
	
	if (trackingRect) [self removeTrackingRect:trackingRect];
	trackingRect = [self addTrackingRect:bounds owner:self userData:nil assumeInside:NO];
}

- (void)mouseEntered:(NSEvent *)theEvent {
	//    NSLog(@"mouseEntered start\n");
	if (self.clickedMinimized && [appSettings autoExpandGraph]) {
		[self expandWindow];
	}
}

- (void)mouseExited:(NSEvent *)theEvent {
	//    NSLog(@"mouseEntered start\n");
	if (self.clickedMinimized && [appSettings autoExpandGraph]) {
		[self minimizeWindow];
	}
}

@end

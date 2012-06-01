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
//  XRGAppDelegate.m
//

#import "XRGAppDelegate.h"
#import "XRGGraphWindow.h"

@implementation XRGAppDelegate

- (XRGGraphWindow *)xrgGraphWindow {
    return xrgGraphWindow;
}

- (XRGPrefController *)prefController {
	return prefController;
}

- (IBAction)showPrefs:(id)sender {
    if(!prefController) {
        [NSBundle loadNibNamed:@"Preferences.nib" owner:self];
    }
	// Refresh the temperature settings to pick up any new sensors.
    [prefController setUpTemperaturePanel];
    [[prefController window] makeKeyAndOrderFront:sender];
}

- (void)showPrefsWithPanel:(NSString *)panelName {
    if (!prefController) {
        [NSBundle loadNibNamed:@"Preferences.nib" owner:self];
    }
	// Refresh the temperature settings to pick up any new sensors.
    [prefController setUpTemperaturePanel];
    [[prefController window] makeKeyAndOrderFront:self];
    
    if ([panelName isEqualTo:@"CPU"])
        [prefController CPU:self];
    else if ([panelName isEqualTo:@"RAM"])
        [prefController RAM:self];
    else if ([panelName isEqualTo:@"Temperature"])
        [prefController Temperature:self];
    else if ([panelName isEqualTo:@"Network"])
        [prefController Network:self];
    else if ([panelName isEqualTo:@"Disk"])
        [prefController Disk:self];
    else if ([panelName isEqualTo:@"Weather"]) 
        [prefController Weather:self];
    else if ([panelName isEqualTo:@"Stocks"])
        [prefController Stocks:self];
    else if ([panelName isEqualTo:@"General"]) 
        [prefController General:self];
    else if ([panelName isEqualTo:@"Appearance"])
        [prefController Colors:self];
}

- (void)changeFont:(id)sender {
    NSFont *oldFont = [[xrgGraphWindow appSettings] graphFont];
    NSFont *newFont = [sender convertFont:oldFont];
    if (oldFont == newFont) return;
    [[xrgGraphWindow appSettings] setGraphFont:newFont];
    [[xrgGraphWindow moduleManager] graphFontChanged];
    
    return;
}

// Cleanup when the application exits caused by a restart or logout
- (void)NSWorkSpaceWillPowerOffNotification:(NSNotification *)aNotification {
    [xrgGraphWindow cleanupBeforeExiting];
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification {
	[[xrgGraphWindow moduleManager] windowChangedToSize:[xrgGraphWindow frame].size];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:XRG_windowIsMinimized]) {
		// minimize the window.
		[[xrgGraphWindow backgroundView] minimizeWindow];
	}
}

// Cleanup when the application is quit by the user.
- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [xrgGraphWindow cleanupBeforeExiting];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
	NSData *themeData = [NSData dataWithContentsOfFile:filename];
	
	if ([themeData length] == 0) {
		NSRunInformationalAlertPanel(@"Error", @"The theme file dragged is not a valid theme file.", @"OK", nil, nil);
	}
	
	NSString *error;        
	NSPropertyListFormat format;
	NSDictionary *themeDictionary = [NSPropertyListSerialization propertyListFromData:themeData
																	 mutabilityOption:NSPropertyListImmutable
																			   format:&format
																	 errorDescription:&error];
	
	if (!themeDictionary) {
		NSRunInformationalAlertPanel(@"Error", @"The theme file dragged is not a valid theme file.", @"OK", nil, nil);
		NSLog(@"%@", error);
		[error release];
	}
	else {
		[[xrgGraphWindow appSettings] readXTFDictionary:themeDictionary];                
		[xrgGraphWindow display];
	}

	[[self prefController] setUpColorPanel];

	return YES;
}

@end

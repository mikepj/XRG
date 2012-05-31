/*
 *  XRGPlugin.h
 *  XRG
 *
 *  Created by Mike Piatek-Jimenez on 1/31/06.
 *  Copyright 2006-2009 Gaucho Software, LLC. All rights reserved.
 *
 */

@protocol XRGPlugin

- (NSView *) graphView;
- (NSView *) prefsView;
- (NSString *) prefsIcon;

- (NSString *) pluginName;
- (NSString *) pluginShortName;

- (NSDictionary *) fetchData;	// Returns a dictionary of keys as labels and values being the data values.
- (void) tick5;
- (void) tick300;
- (void) tick1800;

@end

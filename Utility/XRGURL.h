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
//  XRGURL.h
//

#import <Foundation/Foundation.h>

enum {
	XRGURLCacheIgnore,		// Ignore the cache and force a reload.
	XRGURLCacheUse,			// Use the cache, but if not available load from online.
	XRGURLCacheOnly			// Try the cache, and do not attempt to load from online.
};
typedef int XRGURLCacheMode;

@interface XRGURL : NSObject
@property NSURLConnection *urlConnection;
@property (setter=setURL:) NSURL *url;
@property (nonatomic,setter=setURLString:) NSString *urlString;
@property (getter=getData) NSMutableData *urlData;

@property BOOL isLoading;
@property (getter=isDataReady) BOOL dataReady;
@property (getter=didErrorOccur) BOOL errorOccurred;

@property XRGURLCacheMode cacheMode;

- (id) initWithURLString:(NSString *)urlS;

#pragma mark Getter/Setters
- (NSString *) urlString;
- (void) setURLString:(NSString *)newString;
+ (NSString *) userAgent;
+ (void) setUserAgent:(NSString *)newAgent;
- (void) setCacheMode:(XRGURLCacheMode)mode;
- (NSMutableData *) getData;
- (void) setData:(NSData *)newData;
- (void) appendData:(NSData *)appendData;

- (void) setURLConnection:(NSURLConnection *)newConnection;
- (void) setUserAgentForRequest:(NSMutableURLRequest *)request;

#pragma mark Action Methods
- (void) loadURLInForeground;
- (void) loadURLInBackground;
- (BOOL) prepareForURLLoad;
- (void) cancelLoading;

#pragma mark Status Methods
- (BOOL) haveGoodURL;

#pragma mark Notifications

@end

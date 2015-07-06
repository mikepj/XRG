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
//  XRGURL.m
//

#import "XRGURL.h"

NSString		*userAgent = nil;

@implementation XRGURL
- (instancetype) init {
	self = [super init];
	
	if (self) {
		urlConnection = nil;
		url = nil;
		urlString = nil;
		urlData = nil;
		isLoading = NO;
		dataReady = NO;
		errorOccurred = NO;
		cacheMode = XRGURLCacheIgnore;
	}
    
    return self;
}

- (instancetype) initWithURLString:(NSString *)urlS {
	self = [super init];
	
	if (self) {
		urlConnection = nil;
		url = nil;
		urlString = nil;
		urlData = nil;
		isLoading = NO;
		dataReady = NO;
		errorOccurred = NO;
		cacheMode = XRGURLCacheIgnore;
		
		[self setURLString:urlS];
	}
	
	return self;
}

- (void) dealloc {
	[self setURL:nil];
	[self setData:nil];
	[self setURLString:nil];
	[self setURLConnection:nil];
}

#pragma mark Getter/Setters
- (NSString *) urlString {
	return urlString;
}

- (void) setURLString:(NSString *)newString {
	if (newString != urlString) {
		urlString = newString;
		
		// Need to reset our URL object now.
		if ([urlString length] > 0) {
			[self setURL:[NSURL URLWithString:urlString]];
		}
		else {
			[self setURL:nil];
		}
	}
}

+ (NSString *) userAgent {
	return userAgent;
}

+ (void) setUserAgent:(NSString *)newAgent {
	userAgent = newAgent;
}

- (void) setCacheMode:(XRGURLCacheMode)mode {
	cacheMode = mode;
}

- (NSMutableData *) getData {
    return urlData;
}

- (void) setData:(NSData *)newData {
	NSMutableData *newMutableData = newData ? [NSMutableData dataWithData:newData] : nil;
	
	urlData = newMutableData;
}

- (void) appendData:(NSData *)appendData {
	if (urlData != nil) {
		[urlData appendData:appendData];
	}
	else {
		[self setData:[NSMutableData dataWithLength:0]];
		[urlData appendData:appendData];
	}
}

- (void) setURL:(NSURL *)newURL {
	url = newURL;
}

- (void) setURLConnection:(NSURLConnection *)newConnection {
	if (urlConnection != newConnection) {
		if (urlConnection) {
			[urlConnection cancel];
		}
		urlConnection = newConnection;
	}
}

- (void) setUserAgentForRequest:(NSMutableURLRequest *)request {
	if ([XRGURL userAgent] != nil) {
		[request setValue:[XRGURL userAgent] forHTTPHeaderField:@"User-Agent"];
	}
}

#pragma mark Action Methods
- (void) loadURLInForeground {
	if (![self prepareForURLLoad]) {
		errorOccurred = YES;
		return;
	}
	
#ifdef XRG_DEBUG
	NSLog(@"[XRGURL loadURLInForeground] Loading URL: %@", urlString);
#endif
	
	if (cacheMode == XRGURLCacheIgnore) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];
		[self setUserAgentForRequest:request];
		[self setData:[NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil]];
	}
	else if (cacheMode == XRGURLCacheUse) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60];
		[self setUserAgentForRequest:request];
		[self setData:[NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil]];
	}
	else if (cacheMode == XRGURLCacheOnly) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataDontLoad timeoutInterval:60];
		[self setUserAgentForRequest:request];
		[self setData:[NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil]];
	}
	
    if (urlData == nil) errorOccurred = YES;
	
#ifdef XRG_DEBUG
	NSLog(@"[XRGURL loadURLInForeground] Finished loading URL: %@", urlString);
#endif
    
    dataReady = YES;
}

- (void) loadURLInBackground {
	if (![self prepareForURLLoad]) {
		errorOccurred = YES;
		return;
	}
	
#ifdef XRG_DEBUG
	NSLog(@"[XRGURL] Started Background Loading %@", urlString);
#endif
	
	isLoading = YES;
	
	if (cacheMode == XRGURLCacheIgnore) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];
		[self setUserAgentForRequest:request];
		
		NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
		[self setURLConnection:connection];
	}
	else if (cacheMode == XRGURLCacheUse) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60];
		[self setUserAgentForRequest:request];
		
		NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
		[self setURLConnection:connection];
	}
	else if (cacheMode == XRGURLCacheOnly) {
		// Do a cache-only request.
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataDontLoad timeoutInterval:60];
		[self setUserAgentForRequest:request];
		
		NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
		[self setURLConnection:connection];
	}
}

// Returns whether or not the URL is ready to load.
- (BOOL) prepareForURLLoad {
	// Check to make sure we have a valid NSURL object.
	if (urlString == nil) {
#ifdef XRG_DEBUG
		NSLog(@"[XRGURL prepareForURLLoad] Error:  Attempted to load URL with empty URL String.");
#endif
		return NO;
	}
	
	if (url == nil) {
		[self setURL:[NSURL URLWithString:urlString]];
		
		if (url == nil) {
#ifdef XRG_DEBUG
			NSLog(@"[XRGURL prepareForURLLoad] Error:  Failed to initialize NSURL with urlString: %@.", urlString);
#endif
			return NO;
		}
	}
	
	// Clear out the old data.
	dataReady = NO;
	errorOccurred = NO;
	[self setData:nil];
	
	return YES;
}

- (void) cancelLoading {
	if (urlConnection != nil) [urlConnection cancel];
    
	[self setData:nil];
    
	errorOccurred = NO;
    dataReady = NO;
	isLoading = NO;
}

#pragma mark Status Methods
- (bool) isLoading {
	return isLoading;
}

- (bool) isDataReady {
    return dataReady;
}

- (bool) didErrorOccur {
    return errorOccurred;
}

- (void) setErrorOccurred {
	errorOccurred = YES;
}

- (bool) haveGoodURL {
    return (url != nil);
}

#pragma mark Notifications
- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	if (urlConnection == connection) {
		[self appendData:data];
	}
	else {
#ifdef XRG_DEBUG
		NSLog(@"[XRGURL]  Hmm, we got data but the connections didn't match");
#endif
	}
}

-(void) connectionDidFinishLoading:(NSURLConnection *)connection {
	if (urlConnection == connection) {
		dataReady = YES;
		isLoading = NO;
		
#ifdef XRG_DEBUG
		NSLog(@"[XRGURL] Finished Loading %@", urlString);
#endif
	}
	else {
#ifdef XRG_DEBUG
		NSLog(@"[XRGURL]  Hmm, we finished loading but the connections didn't match");
#endif
	}
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
#ifdef XRG_DEBUG
	NSLog(@"[XRGURL] Failed Loading %@: %@", urlString, [error localizedDescription]);
#endif
	
	isLoading = NO;
	errorOccurred = YES;
}

// Request got redirected.
- (NSURLRequest *) connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
#ifdef XRG_DEBUG
	NSLog(@"[XRGURL] Connection is redirecting.");
#endif
	
	return request;
}

@end

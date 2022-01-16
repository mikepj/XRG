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
//  XRGURL.m
//

#import "XRGURL.h"

NSString		*userAgent = nil;

@implementation XRGURL
- (instancetype) init {
	if (self = [super init]) {
		_urlConnection = nil;
		_url = nil;
		_urlString = nil;
		_urlData = nil;
		_isLoading = NO;
		_dataReady = NO;
		_errorOccurred = NO;
		_cacheMode = XRGURLCacheIgnore;
	}
    
    return self;
}

- (instancetype) initWithURLString:(NSString *)urlS {
	if (self = [self init]) {
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
- (void) setURLString:(NSString *)newString {
	if (newString != _urlString) {
		_urlString = newString;
		
		// Need to reset our URL object now.
		if ([_urlString length] > 0) {
			[self setURL:[NSURL URLWithString:_urlString]];
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

- (void) setData:(NSData *)newData {
	NSMutableData *newMutableData = newData ? [NSMutableData dataWithData:newData] : nil;
	
	_urlData = newMutableData;
}

- (void) appendData:(NSData *)appendData {
	if (_urlData != nil) {
		[_urlData appendData:appendData];
	}
	else {
		[self setData:[NSMutableData dataWithLength:0]];
		[_urlData appendData:appendData];
	}
}

- (void) setURLConnection:(NSURLConnection *)newConnection {
	if (_urlConnection != newConnection) {
		if (_urlConnection) {
			[_urlConnection cancel];
		}
		_urlConnection = newConnection;
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
		self.errorOccurred = YES;
		return;
	}
	
#ifdef XRG_DEBUG
	NSLog(@"[XRGURL loadURLInForeground] Loading URL: %@", urlString);
#endif
	
	if (self.cacheMode == XRGURLCacheIgnore) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];
		[self setUserAgentForRequest:request];
		[self setData:[NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil]];
	}
	else if (self.cacheMode == XRGURLCacheUse) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60];
		[self setUserAgentForRequest:request];
		[self setData:[NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil]];
	}
	else if (self.cacheMode == XRGURLCacheOnly) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url cachePolicy:NSURLRequestReturnCacheDataDontLoad timeoutInterval:60];
		[self setUserAgentForRequest:request];
		[self setData:[NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil]];
	}
	
    if (_urlData == nil) self.errorOccurred = YES;
	
#ifdef XRG_DEBUG
	NSLog(@"[XRGURL loadURLInForeground] Finished loading URL: %@", urlString);
#endif
    
    self.dataReady = YES;
}

- (void) loadURLInBackground {
	if (![self prepareForURLLoad]) {
		self.errorOccurred = YES;
		return;
	}
	
#ifdef XRG_DEBUG
	NSLog(@"[XRGURL] Started Background Loading %@", urlString);
#endif
	
	self.isLoading = YES;
	
	if (self.cacheMode == XRGURLCacheIgnore) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];
		[self setUserAgentForRequest:request];
		
		NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
		[self setURLConnection:connection];
	}
	else if (self.cacheMode == XRGURLCacheUse) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60];
		[self setUserAgentForRequest:request];
		
		NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
		[self setURLConnection:connection];
	}
	else if (self.cacheMode == XRGURLCacheOnly) {
		// Do a cache-only request.
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url cachePolicy:NSURLRequestReturnCacheDataDontLoad timeoutInterval:60];
		[self setUserAgentForRequest:request];
		
		NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
		[self setURLConnection:connection];
	}
}

// Returns whether or not the URL is ready to load.
- (BOOL) prepareForURLLoad {
	// Check to make sure we have a valid NSURL object.
	if (self.urlString == nil) {
#ifdef XRG_DEBUG
		NSLog(@"[XRGURL prepareForURLLoad] Error:  Attempted to load URL with empty URL String.");
#endif
		return NO;
	}
	
	if (self.url == nil) {
		[self setURL:[NSURL URLWithString:self.urlString]];
		
		if (self.url == nil) {
#ifdef XRG_DEBUG
			NSLog(@"[XRGURL prepareForURLLoad] Error:  Failed to initialize NSURL with urlString: %@.", urlString);
#endif
			return NO;
		}
	}
	
	// Clear out the old data.
	self.dataReady = NO;
	self.errorOccurred = NO;
	[self setData:nil];
	
	return YES;
}

- (void) cancelLoading {
	if (self.urlConnection != nil) [self.urlConnection cancel];
    
	[self setData:nil];
    
	self.errorOccurred = NO;
    self.dataReady = NO;
	self.isLoading = NO;
}

#pragma mark Status Methods
- (BOOL) haveGoodURL {
    return (self.url != nil);
}

#pragma mark Notifications
- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	if (self.urlConnection == connection) {
		[self appendData:data];
	}
	else {
#ifdef XRG_DEBUG
		NSLog(@"[XRGURL]  Hmm, we got data but the connections didn't match");
#endif
	}
}

-(void) connectionDidFinishLoading:(NSURLConnection *)connection {
	if (self.urlConnection == connection) {
		self.dataReady = YES;
		self.isLoading = NO;
		
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
	
	self.isLoading = NO;
	self.errorOccurred = YES;
}

// Request got redirected.
- (NSURLRequest *) connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
#ifdef XRG_DEBUG
	NSLog(@"[XRGURL] Connection is redirecting.");
#endif
	
	return request;
}

@end

//
//  EGOImageLoadConnection.m
//  EGOImageLoading
//
//  Created by Shaun Harrison on 12/1/09.
//  Copyright (c) 2009-2010 enormego
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "EGOImageLoadConnection.h"

@interface EGOImageLoadConnection ()
@property (nonatomic, retain, readwrite) NSMutableData *responseData;
@property (nonatomic, copy, readwrite, getter=imageURL) NSURL *imageURL;
@property (nonatomic, retain, readwrite) NSMutableDictionary *handlers;
@property (nonatomic, retain) NSURLConnection *connection;
@end

@implementation EGOImageLoadConnection
@synthesize imageURL, response, delegate, timeoutInterval, handlers, responseData, connection;

- (id)initWithImageURL:(NSURL*)aURL delegate:(id)aDelegate {
	if((self = [super init])) {
        self.imageURL = aURL;
		self.delegate = aDelegate;
        self.responseData = [NSMutableData data];
		self.timeoutInterval = 30;
        self.handlers = [NSMutableDictionary dictionary];
	}
	
	return self;
}

- (void)start {
	NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:self.imageURL
																cachePolicy:NSURLRequestReturnCacheDataElseLoad
															timeoutInterval:self.timeoutInterval];
	[request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    
    NSURLConnection *newConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
	self.connection = newConnection;
    [newConnection release];
    [request release];
}

- (void)cancel {
	[self.connection cancel];	
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data {
	if (aConnection != self.connection) return;
	[self.responseData appendData:data];
}

- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)aResponse {
	if (aConnection != self.connection) return;
	self.response = aResponse;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection {
	if (aConnection != self.connection) return;

	if([self.delegate respondsToSelector:@selector(imageLoadConnectionDidFinishLoading:)])
		[self.delegate imageLoadConnectionDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error {
	if (aConnection != self.connection) return;

	if([self.delegate respondsToSelector:@selector(imageLoadConnection:didFailWithError:)])
		[self.delegate imageLoadConnection:self didFailWithError:error];
}

- (void)dealloc {
    self.response = nil;
    self.delegate = nil;
    self.handlers = nil;
    self.imageURL = nil;
    self.responseData = nil;
    self.connection = nil;
    
    [super dealloc];
}

@end

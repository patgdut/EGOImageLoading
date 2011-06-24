//
//  EGOImageLoader.m
//  EGOImageLoading
//
//  Created by Shaun Harrison on 9/15/09.
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

#import "EGOImageLoader.h"
#import "EGOImageLoadConnection.h"
#import "EGOCache.h"

static EGOImageLoader* __imageLoader;

inline static NSString* keyForURL(NSURL* url, NSString* style) {
	if(style) {
		return [NSString stringWithFormat:@"EGOImageLoader-%u-%u", [[url description] hash], [style hash]];
	} else {
		return [NSString stringWithFormat:@"EGOImageLoader-%u", [[url description] hash]];
	}
}

#define kNoStyle @"EGOImageLoader-nostyle"
#define kCompletionsKey @"completions"
#define kStylerKey @"styler"
#define kStylerQueue _operationQueue
#define kCompletionsQueue dispatch_get_main_queue()

@interface EGOImageLoader ()
- (void)handleCompletionsForConnection:(EGOImageLoadConnection*)connection image:(UIImage*)image error:(NSError*)error;
@end

@implementation EGOImageLoader

@synthesize currentConnections;

+ (EGOImageLoader*)sharedImageLoader {
	@synchronized(self) {
		if(!__imageLoader) {
			__imageLoader = [[[self class] alloc] init];
		}
	}
	
	return __imageLoader;
}

- (id)init {
	if((self = [super init])) {
		connectionsLock = [NSLock new];
		self.currentConnections = [NSMutableDictionary new];
		_operationQueue = dispatch_queue_create("com.enormego.EGOImageLoader",NULL);
		dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0);
		dispatch_set_target_queue(priority, _operationQueue);
	}	
	return self;
}

- (EGOImageLoadConnection *)loadingConnectionForURL:(NSURL*)aURL {
    return [self.currentConnections objectForKey:aURL];
}

- (void)cleanUpConnection:(EGOImageLoadConnection*)connection {
	if(!connection.imageURL) return;
	
	connection.delegate = nil;
	
	[connectionsLock lock];
	[self.currentConnections removeObjectForKey:connection.imageURL];
	[connectionsLock unlock];	
}

- (void)clearCacheForURL:(NSURL*)aURL {
	[self clearCacheForURL:aURL style:nil];
}

- (void)clearCacheForURL:(NSURL*)aURL style:(NSString*)style {
	[[EGOCache currentCache] removeCacheForKey:keyForURL(aURL, style)];
}

- (BOOL)isLoadingImageURL:(NSURL*)aURL {
	return [self loadingConnectionForURL:aURL] ? YES : NO;
}

- (void)cancelLoadForURL:(NSURL*)aURL {
	EGOImageLoadConnection* connection = [self loadingConnectionForURL:aURL];
	[NSObject cancelPreviousPerformRequestsWithTarget:connection selector:@selector(start) object:nil];
	[connection cancel];
	[self cleanUpConnection:connection];
}

- (EGOImageLoadConnection*)loadImageForURL:(NSURL*)aURL {
	EGOImageLoadConnection* connection;
	
	if ((connection = [self loadingConnectionForURL:aURL])) {
		return connection;
	} else {
		connection = [[EGOImageLoadConnection alloc] initWithImageURL:aURL delegate:self];
	
		[connectionsLock lock];
		[self.currentConnections setObject:connection forKey:aURL];
		[connectionsLock unlock];
		[connection performSelector:@selector(start) withObject:nil afterDelay:0.01];
        
        EGO_RELEASE(connection);
		
		return connection;
	}
}

- (void)loadImageForURL:(NSURL*)aURL completion:(void (^)(UIImage* image, NSURL* imageURL, NSError* error))completion {
	[self loadImageForURL:aURL style:nil styler:nil completion:completion];
}

- (void)loadImageForURL:(NSURL*)aURL style:(NSString*)style styler:(UIImage* (^)(UIImage* image))styler completion:(void (^)(UIImage* image, NSURL* imageURL, NSError* error))completion {
	UIImage* anImage = [[EGOCache currentCache] imageForKey:keyForURL(aURL,style)];

	if(anImage) {
		completion(anImage, aURL, nil);
	} else if(!anImage && styler && style && (anImage = [[EGOCache currentCache] imageForKey:keyForURL(aURL,nil)])) {
		dispatch_async(kStylerQueue, ^{
			UIImage* image = styler(anImage);
			[[EGOCache currentCache] setImage:image forKey:keyForURL(aURL, style) withTimeoutInterval:604800];
			dispatch_async(kCompletionsQueue, ^{
				completion(image, aURL, nil);
			});
		});
	} else {
		EGOImageLoadConnection* connection = [self loadImageForURL:aURL];
		void (^completionCopy)(UIImage* image, NSURL* imageURL, NSError* error) = [completion copy];
		
		NSString* handlerKey = style ? style : kNoStyle;
		NSMutableDictionary* handler = [connection.handlers objectForKey:handlerKey];
		
		if(!handler) {
			handler = [[NSMutableDictionary alloc] initWithCapacity:2];
			[connection.handlers setObject:handler forKey:handlerKey];
            EGO_RELEASE(handler);

			[handler setObject:[NSMutableArray arrayWithCapacity:1] forKey:kCompletionsKey];
			if (styler) {
				UIImage *(^stylerCopy)(UIImage* image) = [styler copy];
				[handler setObject:stylerCopy forKey:kStylerKey];
                EGO_RELEASE(stylerCopy);
			}
		}
		
		[[handler objectForKey:kCompletionsKey] addObject:completionCopy];
		EGO_RELEASE(completionCopy);
	}
}

- (BOOL)hasLoadedImageURL:(NSURL*)aURL {
	return [[EGOCache currentCache] hasCacheForKey:keyForURL(aURL,nil)];
}

#pragma mark -
#pragma mark URL Connection delegate methods

- (void)imageLoadConnectionDidFinishLoading:(EGOImageLoadConnection *)connection {
	UIImage* anImage = [UIImage imageWithData:connection.responseData];
	
	if(!anImage) {
		NSError* error = [NSError errorWithDomain:[connection.imageURL host] code:406 userInfo:nil];
		[self handleCompletionsForConnection:connection image:nil error:error];
	} else {
		[[EGOCache currentCache] setData:connection.responseData forKey:keyForURL(connection.imageURL,nil) withTimeoutInterval:604800];
		[self.currentConnections removeObjectForKey:connection.imageURL];
        [self handleCompletionsForConnection:connection image:anImage error:nil];
	}
	[self cleanUpConnection:connection];
}

- (void)imageLoadConnection:(EGOImageLoadConnection *)connection didFailWithError:(NSError *)error {
	[self.currentConnections removeObjectForKey:connection.imageURL];
	[self handleCompletionsForConnection:connection image:nil error:error];
	[self cleanUpConnection:connection];
}

- (void)handleCompletionsForConnection:(EGOImageLoadConnection*)connection image:(UIImage*)image error:(NSError*)error {
	if([connection.handlers count] == 0) return;

	NSURL* imageURL = connection.imageURL;
	
	void (^callCompletions)(UIImage* anImage, NSArray* completions) = ^(UIImage* anImage, NSArray* completions) {
		dispatch_async(kCompletionsQueue, ^{
			for(void (^completion)(UIImage* image, NSURL* imageURL, NSError* error) in completions) {
				completion(anImage, connection.imageURL, error);
			}
		});
	};
	
	for(NSString* styleKey in connection.handlers) {
		NSDictionary* handler = [connection.handlers objectForKey:styleKey];
		UIImage* (^styler)(UIImage* image) = [handler objectForKey:kStylerKey];
		if(!error && image && styler) {
			dispatch_async(kStylerQueue, ^{
				UIImage* anImage = styler(image);
				[[EGOCache currentCache] setImage:anImage forKey:keyForURL(imageURL, styleKey) withTimeoutInterval:604800];
				callCompletions(anImage, [handler objectForKey:kCompletionsKey]);
			});
		} else {
			callCompletions(image, [handler objectForKey:kCompletionsKey]);
		}
	}
}

- (void)dealloc {
    dispatch_release(_operationQueue), _operationQueue = nil;
    PS_DEALLOC_NIL(self.currentConnections);
    PS_RELEASE_NIL(connectionsLock);
    PS_DEALLOC();
}

@end
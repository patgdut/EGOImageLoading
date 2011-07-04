//
//  EGOImageView.m
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

#import "EGOImageView.h"
#import "EGOImageLoader.h"
#import "EGOCache.h"

@implementation EGOImageView
@synthesize imageURL, placeholderImage, delegate;

- (id)initWithPlaceholderImage:(UIImage*)anImage {
	return [self initWithPlaceholderImage:anImage delegate:nil];	
}

- (id)initWithPlaceholderImage:(UIImage*)anImage delegate:(id<EGOImageViewDelegate>)aDelegate {
	if((self = [super initWithImage:anImage])) {
		self.placeholderImage = anImage;
		self.delegate = aDelegate;
	}
	
	return self;
}

- (void)setImageURL:(NSURL *)aURL {
	if (imageURL) {
        [self cancelImageLoad];
        self.imageURL = nil;
	}
	
	if(!aURL) {
		self.image = self.placeholderImage;
        self.imageURL = nil;
		return;
	} else {
        self.imageURL = aURL;
	}
    
    [[EGOImageLoader sharedImageLoader] loadImageForURL:aURL completion:^(UIImage *theImage, NSURL *theImageURL, NSError *theError) {
        if (![self.imageURL isEqual:theImageURL]) return;
        
        if (theError && [self.delegate respondsToSelector:@selector(imageViewFailedToLoadImage:error:)]) {
            [self.delegate imageViewFailedToLoadImage:self error:theError];
            return;
        }
        
        self.image = theImage;
        [self setNeedsDisplay];
        
        if ([self.delegate respondsToSelector:@selector(imageViewLoadedImage:)]) {
            [self.delegate imageViewLoadedImage:self];
        }	 
    }];
	
	self.image = self.placeholderImage;
}

- (void)cancelImageLoad {
	[[EGOImageLoader sharedImageLoader] cancelLoadForURL:self.imageURL];
}

- (void)dealloc {
    PS_DEALLOC_NIL(self.imageURL);
    PS_DEALLOC_NIL(self.placeholderImage);
    PS_DEALLOC();
}

@end

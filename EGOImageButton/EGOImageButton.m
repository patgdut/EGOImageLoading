//
//  EGOImageButton.m
//  EGOImageLoading
//
//  Created by Shaun Harrison on 9/30/09.
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

#import "EGOImageButton.h"
#import "EGOCache.h"

@implementation EGOImageButton
@synthesize imageURL, placeholderImage, delegate;

- (id)initWithPlaceholderImage:(UIImage*)anImage {
	return [self initWithPlaceholderImage:anImage delegate:nil];	
}

- (id)initWithPlaceholderImage:(UIImage*)anImage delegate:(id<EGOImageButtonDelegate>)aDelegate {
	if((self = [super initWithFrame:CGRectZero])) {
		self.placeholderImage = anImage;
		self.delegate = aDelegate;
		[self setImage:self.placeholderImage forState:UIControlStateNormal];
	}
	
	return self;
}

- (void)setImageURL:(NSURL *)aURL {
	if (imageURL) {
        [self cancelImageLoad];
        self.imageURL = nil;
	}
	
	if(!aURL) {
		[self setImage:self.placeholderImage forState:UIControlStateNormal];
		self.imageURL = nil;
		return;
	} else {
        self.imageURL = aURL;
	}
    
    [[EGOImageLoader sharedImageLoader] loadImageForURL:aURL completion:^(UIImage *theImage, NSURL *theImageURL, NSError *theError) {
        if (![self.imageURL isEqual:theImageURL]) return;
        
        if (theError && [self.delegate respondsToSelector:@selector(imageButtonFailedToLoadImage:error:)]) {
            [self.delegate imageButtonFailedToLoadImage:self error:theError];
            return;
        }
        
        [self setImage:theImage forState:UIControlStateNormal];
        [self setNeedsDisplay];
        
        if ([self.delegate respondsToSelector:@selector(imageButtonLoadedImage:)]) {
            [self.delegate imageButtonLoadedImage:self];
        }	 
    }];
	
	[self setImage:self.placeholderImage forState:UIControlStateNormal];
}

#pragma mark -
#pragma mark Image loading

- (void)cancelImageLoad {
	[[EGOImageLoader sharedImageLoader] cancelLoadForURL:self.imageURL];
}

#pragma mark -

- (void)dealloc {    
    EGO_DEALLOC_NIL(self.imageURL);
    EGO_DEALLOC_NIL(self.placeholderImage);
    EGO_DEALLOC();
}

@end

//
//  DTLazyImageView.m
//  PagingTextScroller
//
//  Created by Oliver Drobnik on 5/20/11.
//  Copyright 2011 . All rights reserved.
//

#import "DTLazyImageView.h"
#import "ImageLoader.h"

@interface DTLazyImageView ()

- (void)completeDownloadWithImage:(UIImage *)image;
- (void)startLoadImage;

@end

@implementation DTLazyImageView
{
	NSURL *_url;
	
	__unsafe_unretained id<DTLazyImageViewDelegate> _delegate;
    
    NSTimer *timerStartLoadImage;
}
@synthesize delegate=_delegate;

- (void)dealloc
{
    //
}

#define DEFAULT_TIME_INTERVAL 0.1

- (void)didMoveToSuperview {
	[super didMoveToSuperview];
	self.userInteractionEnabled = YES;
    
    UITapGestureRecognizer *singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    [self addGestureRecognizer:singleFingerTap];
    
    /*if (timerStartLoadImage) {
	 timerStartLoadImage = [NSTimer scheduledTimerWithTimeInterval:DEFAULT_TIME_INTERVAL target:self selector:@selector(startLoadImage) userInfo:nil repeats:NO];
	 return;
	 } else if ([timerStartLoadImage isValid]) {
	 [timerStartLoadImage invalidate];
	 }
	 
	 timerStartLoadImage = [NSTimer scheduledTimerWithTimeInterval:DEFAULT_TIME_INTERVAL target:self selector:@selector(startLoadImage) userInfo:nil repeats:NO];*/
    [self startLoadImage];
}

- (void)startLoadImage {
    if (!self.image && _url && self.superview) {
        
        UIImage *image = [ImageLoader thumbnailForURL:[_url absoluteString] size:CGSizeMake(300.0f, 0.0f) result:^(UIImage *image) {
            if (image) {
                [self completeDownloadWithImage:image];
            }
        }];
        
        if (image) {
			self.image = image;
			
			// for unknown reasons direct notify does not work below iOS 5
			[self performSelector:@selector(completeDownloadWithImage:) withObject:image afterDelay:0.0];
			return;
		}
	}
}

- (void)cancelLoading
{
    //
}

#pragma mark NSURL Loading


- (void)completeDownloadWithImage:(UIImage *)image {	
	self.image = image;
	
    self.bounds = CGRectMake(0.0, 0.0, image.size.width, image.size.height);
	
	if ([self.delegate respondsToSelector:@selector(lazyImageView:didChangeImageSize:)]) {
		[self.delegate lazyImageView:self didChangeImageSize:CGSizeMake(image.size.width, image.size.height)];
	}	
}


- (void)removeFromSuperview
{
	[super removeFromSuperview];
    
    self.userInteractionEnabled = NO;
    self.image = nil;
    
    if (timerStartLoadImage) {
        [timerStartLoadImage invalidate];
    }
}

//The event handling method
- (void)handleSingleTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if ([self.delegate respondsToSelector:@selector(lazyImageView:didTouchEvent:)]) {
            [self.delegate lazyImageView:self didTouchEvent:sender];
        }
    }
}

#pragma mark Properties

@synthesize url = _url;
@synthesize shouldShowProgressiveDownload;

@end

//
//  DTLazyImageView.h
//  PagingTextScroller
//
//  Created by Oliver Drobnik on 5/20/11.
//  Copyright 2011 . All rights reserved.
//


#import <ImageIO/ImageIO.h>
#import "ImageLoader.h"

@class DTLazyImageView;

@protocol DTLazyImageViewDelegate <NSObject>
@optional
- (void)lazyImageView:(DTLazyImageView *)lazyImageView didChangeImageSize:(CGSize)size;
- (void)lazyImageView:(DTLazyImageView *)lazyImageView didTouchEvent:(UITapGestureRecognizer*)sender;
@end

@interface DTLazyImageView : UIImageView
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) BOOL shouldShowProgressiveDownload;

@property (nonatomic, assign) id<DTLazyImageViewDelegate> delegate;	// subtle simulator bug - use assign not __unsafe_unretained

- (void)cancelLoading;

@end

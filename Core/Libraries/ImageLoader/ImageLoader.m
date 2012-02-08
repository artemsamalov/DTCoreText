//
//  ImageLoader.m
//  GRTop
//
//  Created by Constantine Mureev on 12/14/11.
//  Copyright (c) 2011 Team Force LLC. All rights reserved.
//

#import "ImageLoader.h"
#import "ObjectStorage.h"
#import "NetworkManager.h"
#import "UIImage+NSCoding.h"
#import "UIImage+Resize.h"
#import "UIImage+Alpha.h"
#import "Macros.h"

typedef void (^CallbackAction)(UIImage* newImage);

@interface ImageOperation : NSOperation {}

@property (retain) UIImage* image;
@property (assign) CGSize   size;
@property (copy) CallbackAction action;

@end

@implementation ImageOperation

@synthesize image, size, action;

- (void)dealloc {
    self.image = nil;
    self.action = nil;
    [super dealloc];
}

- (void)main {
    @try {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        BOOL isDone = NO;
        UIImage* newImage = nil;
        if (![self isCancelled] && !isDone) {
            
            if (self.image.size.width*[UIScreen mainScreen].scale >= self.size.width && self.image.size.height*[UIScreen mainScreen].scale >= self.size.height) {
                newImage = [self.image imageWithAlpha];
                if (![self isCancelled]) {
                    self.size = CGSizeMake(self.size.width*[UIScreen mainScreen].scale, self.size.height*[UIScreen mainScreen].scale);
                    
                    if (self.size.width == self.size.height) {
                        newImage = [newImage resizedImage:self.size interpolationQuality:kCGInterpolationMedium];
                    } else {
                        newImage = [newImage resizedImageWithContentMode:UIViewContentModeScaleAspectFill bounds:self.size interpolationQuality:kCGInterpolationMedium];
                    }
                    newImage = [UIImage imageWithData:UIImagePNGRepresentation(newImage)];
                    newImage = [UIImage imageWithCGImage:newImage.CGImage scale:[UIScreen mainScreen].scale orientation:newImage.imageOrientation];
                }
                isDone = YES;
            }
            
            if (self.action) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    self.action(newImage);
                });
            }
        }
        
        [pool release];
    }
    @catch(...) {
        // Do not rethrow exceptions.
    }
}

@end


@interface ImageLoader()

+ (void)resizeImage:(UIImage*)image toSize:(CGSize)size result:(void (^)(UIImage* image))result;
+ (BOOL)isRetinaScreen;

@end

@implementation ImageLoader

#define MAX_CONCURENT_OPERATION 5

NSOperationQueue* sharedResizeQueue() {
    static dispatch_once_t onceToken;
    static NSOperationQueue* sharedResizeQueue;
    dispatch_once(&onceToken, ^{
        sharedResizeQueue = [NSOperationQueue new];
        [sharedResizeQueue setMaxConcurrentOperationCount:MAX_CONCURENT_OPERATION];
    });
    return sharedResizeQueue;
}

//static ImageLoader *sharedInstance = nil;

+ (BOOL)isRetinaScreen {
    if ([UIScreen instancesRespondToSelector:@selector(scale)]) 
    {
        CGFloat scale = [[UIScreen mainScreen] scale];
        
        if (scale > 1.0) 
        {
            return YES;
        }
    }
    return NO;
}

+ (void)resizeImage:(UIImage*)image toSize:(CGSize)size result:(void (^)(UIImage* image))result {
    ImageOperation* operation = [[ImageOperation new] autorelease];
    operation.image = image;
    operation.size = size;
    operation.action = result;
    [sharedResizeQueue() addOperation:operation];
}

+ (UIImage*)thumbnailForURL:(NSString*)url size:(CGSize)size result:(void (^)(UIImage* image))result {
    float scaleWidth = size.width * [UIScreen mainScreen].scale;
    float scaleHeight = size.height * [UIScreen mainScreen].scale;
    NSString* key = [NSString stringWithFormat:@"%@_%.0f*%.0f", url, scaleWidth, scaleHeight];
    
    if (IS_POPULATED_STRING(url)) {
        BOOL isCached = [ObjectStorage isCached:key];
        
        if (isCached) {
            return [ObjectStorage objectForKey:key];
        } else {
            UIImage* image = [self loadImageForURL:url result:^(UIImage *image) {
                [self resizeImage:image toSize:size result:^(UIImage *image) {
                    if (image) {
                        [ObjectStorage storeObject:image key:key];
                    }
                    result(image);
                }];
            }];
            
            // start resize
            if (image != nil) {
                [self resizeImage:image toSize:size result:^(UIImage *image) {
                    if (image) {
                        [ObjectStorage storeObject:image key:key];
                    }
                    result(image);
                }];
            }
        }
    }
    
    return nil;
}

+ (UIImage*)loadImageForURL:(NSString*)url result:(void (^)(UIImage* image))result {
    if (IS_POPULATED_STRING(url)) {
        //Notification for photo browser
        [[NSNotificationCenter defaultCenter] postNotificationName:ImageLoaderDownloadStartNotification object:nil];
        
        BOOL isCached = [ObjectStorage isCached:url];
        
        if (isCached) {
            return [ObjectStorage objectForKey:url];
        } else {
            [NetworkManager sendAsyncRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]] withSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{                
                    // For support retina devices. get it from here - http://stackoverflow.com/questions/3289286/retina-display-and-uiimage-initwithdata
                    
                    UIImage * img = [UIImage imageWithData:operation.responseData];
                    img = [UIImage imageWithCGImage:img.CGImage scale:[UIScreen mainScreen].scale orientation:img.imageOrientation];
                    img = [UIImage imageWithData:UIImagePNGRepresentation(img)];
                    
                    [ObjectStorage storeObject:img key:url];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        result(img);
                    });
                });
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                result(nil);
            }];
        }
    }
    
    return nil;
}

@end

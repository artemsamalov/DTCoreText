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

@implementation ImageLoader

//static ImageLoader *sharedInstance = nil;

+ (UIImage*)loadImageForURL:(NSString*)url result:(void (^)(UIImage* image))result {
    if (url && [url length] > 0) {
        BOOL isCached = [ObjectStorage isCached:url];
        
        if (isCached) {
            return [ObjectStorage objectForKey:url];
        } else {
            [NetworkManager sendAsyncRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]] withSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{                
                    // For support retina devices. get it from here - http://stackoverflow.com/questions/3289286/retina-display-and-uiimage-initwithdata
                    
                    UIImage * img = [UIImage imageWithData:operation.responseData];
                    img = [UIImage imageWithCGImage:img.CGImage scale:[UIScreen mainScreen].scale orientation:img.imageOrientation];
                    //img = [UIImage imageWithData:UIImagePNGRepresentation(img)];
                    
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

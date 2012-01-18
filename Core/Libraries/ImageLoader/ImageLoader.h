//
//  ImageLoader.h
//  GRTop
//
//  Created by Constantine Mureev on 12/14/11.
//  Copyright (c) 2011 Team Force LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ImageLoader : NSObject

//
// return image if it's cached or nil if it's start loading from web
// image in result block can be null if loader failes to download content from url
//
+ (UIImage*)loadImageForURL:(NSString*)url result:(void (^)(UIImage* image))result;

@end

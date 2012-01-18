//
//  NetworkManager.h
//  GRTop
//
//  Created by Constantine Mureev on 12/9/11.
//  Copyright (c) 2011 Team Force LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFHTTPRequestOperation.h"

@interface NetworkManager : NSObject

+ (void)sendAsyncRequest:(NSURLRequest*)request withSuccess:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;

+ (void)addOperation:(AFURLConnectionOperation*)operation;

@end

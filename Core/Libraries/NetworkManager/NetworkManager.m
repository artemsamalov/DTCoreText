//
//  NetworkManager.m
//  GRTop
//
//  Created by Constantine Mureev on 12/9/11.
//  Copyright (c) 2011 Team Force LLC. All rights reserved.
//

#import "NetworkManager.h"
#import "AFNetworkActivityIndicatorManager.h"

@implementation NetworkManager

static NSOperationQueue* queue = nil;
static NSMutableDictionary *defaultHeaders = nil;

static void setDefaultHeaders() {
    [defaultHeaders setValue:@"gzip" forKey:@"Accept-Encoding"];
	
	// Accept-Language HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4
	NSString *preferredLanguageCodes = [[NSLocale preferredLanguages] componentsJoinedByString:@", "];
    [defaultHeaders setValue:[NSString stringWithFormat:@"%@, en-us;q=0.8", preferredLanguageCodes] forKey:@"Accept-Language"];
    
    // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
    [defaultHeaders setValue:[NSString stringWithFormat:@"%@/%@ (%@, %@ %@, %@, Scale/%f)", [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleIdentifierKey], [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey], @"unknown", [[UIDevice currentDevice] systemName], [[UIDevice currentDevice] systemVersion], [[UIDevice currentDevice] model], ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0)] forKey:@"User-Agent"];
}

static NSOperationQueue* network_queue() {
    static dispatch_once_t once;
    dispatch_once(&once, ^ {
        [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
        queue = [NSOperationQueue new];
        defaultHeaders = [NSMutableDictionary new];
        setDefaultHeaders();
    });
    return queue;
}

+ (void)sendAsyncRequest:(NSURLRequest*)request withSuccess:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                 failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure {    
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        NSMutableURLRequest* mutableRequest = (NSMutableURLRequest*)request;
        [mutableRequest setAllHTTPHeaderFields:defaultHeaders];
        
        AFHTTPRequestOperation* operation = [[[AFHTTPRequestOperation alloc] initWithRequest:mutableRequest] autorelease];
        [operation setCompletionBlockWithSuccess:success failure:failure];
        [NetworkManager addOperation:operation];
    } else {
        NSMutableURLRequest* mutableRequest = [NSMutableURLRequest requestWithURL:[request URL] cachePolicy:request.cachePolicy timeoutInterval:request.timeoutInterval];
        [mutableRequest setAllHTTPHeaderFields:defaultHeaders];
        AFHTTPRequestOperation* operation = [[[AFHTTPRequestOperation alloc] initWithRequest:mutableRequest] autorelease];
        [operation setCompletionBlockWithSuccess:success failure:failure];
        [NetworkManager addOperation:operation];
    }
}

+ (void)addOperation:(AFURLConnectionOperation*)operation {
    [network_queue() addOperation:operation];
}

@end

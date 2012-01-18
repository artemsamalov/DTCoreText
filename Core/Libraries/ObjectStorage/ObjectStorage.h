//
//  ObjectStorage.h
//
//  Created by Constantine Mureev on 12/19/11.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

@interface ObjectStorage : NSObject

+ (BOOL)isCached:(NSString*)key;
+ (void)storeObject:(id <NSCoding>)obj key:(NSString*)key;
+ (void)objectForKey:(NSString*)key block:(void (^)(id obj))block;
+ (id)objectForKey:(NSString*)key;

@end

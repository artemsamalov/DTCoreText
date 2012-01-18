//
//  UIImage+NSCoding.m
//
//  Created by Constantine Mureev on 3/9/11.
//

#import "UIImage+NSCoding.h"


@implementation UIImage (NSCoding)

- (id)initWithCoder:(NSCoder *)decoder {
    NSData *pngData = [decoder decodeObjectForKey:@"PNGRepresentation"];
    [self autorelease];
    self = [[UIImage alloc] initWithData:pngData];
    return self;
}
- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:UIImagePNGRepresentation(self) forKey:@"PNGRepresentation"];
}

@end

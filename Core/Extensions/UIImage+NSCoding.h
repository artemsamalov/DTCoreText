//
//  UIImage+NSCoding.h
//
//  Created by Constantine Mureev on 3/9/11.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIImage (NSCoding)

- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder *)encoder;

@end

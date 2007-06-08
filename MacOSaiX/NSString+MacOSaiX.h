//
//  NSString+MacOSaiX.h
//  MacOSaiX
//
//  Created by Frank Midgley on 3/6/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString(MacOSaiX)

- (NSString *)stringByEscapingXMLEntites;
- (NSString *)stringByUnescapingXMLEntites;
+ (NSString *)stringWithAspectRatio:(float)aspectRatio;
+ (NSString *)stringWithFloat:(float)floatValue;


@end

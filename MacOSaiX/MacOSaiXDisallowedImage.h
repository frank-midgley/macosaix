//
//  MacOSaiXDisallowedImage.h
//  MacOSaiX
//
//  Created by Frank Midgley on 7/9/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXSourceImage;


@interface MacOSaiXDisallowedImage : NSObject
{
	Class					imageSourceClass;
	id<NSObject,NSCoding,NSCopying>	universalIdentifier;
}

+ (MacOSaiXDisallowedImage *)imageWithSourceImage:(MacOSaiXSourceImage *)sourceImage;
+ (MacOSaiXDisallowedImage *)imageWithSourceClass:(Class)class universalIdentifier:(id<NSObject,NSCoding,NSCopying>)identifier;

- (id)initWithSourceImage:(MacOSaiXSourceImage *)sourceImage;
- (id)initWithSourceClass:(Class)class universalIdentifier:(id<NSObject,NSCoding,NSCopying>)identifier;

- (Class)imageSourceClass;
- (id<NSObject,NSCoding,NSCopying>)universalIdentifier;

@end

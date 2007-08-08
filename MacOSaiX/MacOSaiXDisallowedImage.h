//
//  MacOSaiXUniversalImage.h
//  MacOSaiX
//
//  Created by Frank Midgley on 7/9/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXSourceImage.h"

@protocol MacOSaiXImageSource;


@interface MacOSaiXUniversalImage : MacOSaiXSourceImage
{
	Class							imageSourceClass;
	id<MacOSaiXImageSource>			imageSource;
	
	id<NSObject,NSCoding,NSCopying>	universalIdentifier;
}

+ (MacOSaiXUniversalImage *)imageWithSourceClass:(Class)class universalIdentifier:(id<NSObject,NSCoding,NSCopying>)identifier;

- (id)initWithSourceClass:(Class)class universalIdentifier:(id<NSObject,NSCoding,NSCopying>)identifier;

@end

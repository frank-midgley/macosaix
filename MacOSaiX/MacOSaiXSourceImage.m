//
//  MacOSaiXSourceImage.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXSourceImage.h"

#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageSource.h"


@implementation MacOSaiXSourceImage : NSObject


- (NSSize)nativeSize
{
	MacOSaiXImageCache	*imageCache = [MacOSaiXImageCache sharedImageCache];
	NSSize				imageSize = [imageCache nativeSizeOfImageWithIdentifier:[self imageIdentifier] 
																	 fromSource:[self imageSource]];
	
	if (NSEqualSizes(imageSize, NSZeroSize))
	{
			// The image isn't in the cache.  Force it to load and then get its size.
		imageSize = [[imageCache imageRepAtSize:NSZeroSize 
								  forIdentifier:[self imageIdentifier] 
									 fromSource:[self imageSource]] size];
	}
	
	return imageSize;
}


- (Class)imageSourceClass
{
	return nil;
}


- (id<MacOSaiXImageSource>)imageSource
{
	return nil;
}


- (NSString *)imageIdentifier
{
	return nil;
}


- (id<NSObject,NSCoding,NSCopying>)universalIdentifier
{
	return nil;
}


- (NSString *)description
{
	return [[self imageSource] descriptionForIdentifier:[self imageIdentifier]];
}


- (NSURL *)contextURL
{
	return [[self imageSource] contextURLForIdentifier:[self imageIdentifier]];
}


- (NSImage *)image
{
	return [[self imageSource] imageForIdentifier:[self imageIdentifier]];
}


- (NSImage *)thumbnailImage
{
	return [[self imageSource] thumbnailForIdentifier:[self imageIdentifier]];
}


- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size
{
	return [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:size 
												   forIdentifier:[self imageIdentifier] 
													  fromSource:[self imageSource]];
}


- (unsigned)hash
{
	// TBD: is this ever being called?
	return 0;
}


- (BOOL)isEqual:(id)otherObject
{
	return ([self imageSourceClass] == [otherObject imageSourceClass] &&
			[[self universalIdentifier] isEqual:[otherObject universalIdentifier]]);
}


- (id)copyWithZone:(NSZone *)zone
{
	return nil;
}


@end

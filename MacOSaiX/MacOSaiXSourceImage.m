//
//  MacOSaiXSourceImage.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXSourceImage.h"

#import "MacOSaiXDisallowedImage.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageSourceEnumerator.h"


@implementation MacOSaiXSourceImage : NSObject


+ (id)sourceImageWithIdentifier:(NSString *)identifier fromEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator
{
	MacOSaiXSourceImage	*sourceImage = [[[self class] alloc] initWithIdentifier:identifier fromEnumerator:enumerator];
	
	return [sourceImage autorelease];
}


- (id)initWithIdentifier:(NSString *)identifier fromEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator
{
	if (self = [super init])
	{
		imageIdentifier = [identifier copy];
		imageSourceEnumerator = [enumerator retain];
	}
	
	return self;
}


- (NSSize)nativeSize
{
	MacOSaiXImageCache	*imageCache = [MacOSaiXImageCache sharedImageCache];
	NSSize				imageSize = [imageCache nativeSizeOfImageWithIdentifier:[self imageIdentifier] 
																	 fromSource:[[self enumerator] workingImageSource]];
	
	if (NSEqualSizes(imageSize, NSZeroSize))
	{
			// The image isn't in the cache.  Force it to load and then get its size.
		imageSize = [[imageCache imageRepAtSize:NSZeroSize 
								  forIdentifier:[self imageIdentifier] 
									 fromSource:[[self enumerator] workingImageSource]] size];
	}
	
	return imageSize;
}


- (NSString *)imageIdentifier
{
	return imageIdentifier;
}


- (id<NSObject,NSCoding,NSCopying>)universalIdentifier
{
	return [[[self enumerator] workingImageSource] universalIdentifierForIdentifier:[self imageIdentifier]];
}


- (NSURL *)contextURL
{
	return [[[self enumerator] workingImageSource] contextURLForIdentifier:[self imageIdentifier]];
}


- (MacOSaiXImageSourceEnumerator *)enumerator
{
	return imageSourceEnumerator;
}


- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size
{
	return [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:size 
												   forIdentifier:[self imageIdentifier] 
													  fromSource:[[self enumerator] workingImageSource]];
}


- (unsigned)hash
{
	return [NSStringFromClass([[[self enumerator] imageSource] class]) hash] + [[self universalIdentifier] hash];
}


- (BOOL)isEqual:(id)otherObject
{
	BOOL	isEqual = (self == otherObject);
	
	if (!isEqual)
	{
		if ([otherObject isKindOfClass:[self class]])
			isEqual = ([[(MacOSaiXSourceImage *)otherObject imageIdentifier] isEqualToString:[self imageIdentifier]] && 
					   [(MacOSaiXSourceImage *)otherObject enumerator] == [self enumerator]);
		else if ([otherObject isKindOfClass:[MacOSaiXDisallowedImage class]])
			isEqual = ([[[self enumerator] imageSource] class] == [otherObject imageSourceClass] &&
					   [[self universalIdentifier] isEqual:[otherObject universalIdentifier]]);
	}
	
	return isEqual;
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[MacOSaiXSourceImage alloc] initWithIdentifier:[self imageIdentifier] 
											fromEnumerator:[self enumerator]];
}


- (void)dealloc
{
	[imageIdentifier release];
	[imageSourceEnumerator release];
	
	[super dealloc];
}


@end

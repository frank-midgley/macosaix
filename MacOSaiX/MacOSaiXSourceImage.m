//
//  MacOSaiXSourceImage.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXSourceImage.h"

#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageSourceEnumerator.h"


@implementation MacOSaiXSourceImage : NSObject


+ (id)sourceImageWithImage:(NSImage *)inImage withIdentifier:(NSString *)identifier fromEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator
{
	MacOSaiXSourceImage	*sourceImage = [[[self class] alloc] initWithImage:inImage 
															withIdentifier:identifier 
															fromEnumerator:enumerator];
	
	return [sourceImage autorelease];;
}


- (id)initWithImage:(NSImage *)inImage withIdentifier:(NSString *)identifier fromEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator
{
	if (self = [super init])
	{
		if (image)
		{
			image = [inImage retain];
			
			[[MacOSaiXImageCache sharedImageCache] cacheImage:image withIdentifier:identifier fromSource:[enumerator workingImageSource]];
		}
		
		imageIdentifier = [identifier copy];
		imageSourceEnumerator = [enumerator retain];
	}
	
	return self;
}


- (NSImage *)image
{
	return image;
}


- (NSSize)nativeSize
{
	NSSize					imageSize = NSZeroSize;
	
	if ([self image])
		imageSize = [[self image] size];
	else
	{
			// Get the size from the cache.
		imageSize = [[MacOSaiXImageCache sharedImageCache] nativeSizeOfImageWithIdentifier:[self imageIdentifier] 
																				fromSource:[[self enumerator] workingImageSource]];
		
		if (NSEqualSizes(imageSize, NSZeroSize))
		{
				// The image isn't in the cache.  Force it to load and then get its size.
			imageSize = [[[MacOSaiXImageCache sharedImageCache] imageRepAtSize:NSZeroSize 
																 forIdentifier:[self imageIdentifier] 
																	fromSource:[[self enumerator] workingImageSource]] size];
		}
	}
	
	return imageSize;
}


- (NSString *)imageIdentifier
{
	return imageIdentifier;
}


- (id<NSCopying>)universalIdentifier
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


- (BOOL)isEqualTo:(id)otherObject
{
	return ([otherObject isKindOfClass:[self class]] && 
			[[(MacOSaiXSourceImage *)otherObject imageIdentifier] isEqualToString:[self imageIdentifier]] && 
			[(MacOSaiXSourceImage *)otherObject enumerator] == [self enumerator]);
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[MacOSaiXSourceImage alloc] initWithImage:[self image] 
									   withIdentifier:[self imageIdentifier] 
									   fromEnumerator:[self enumerator]];
}


- (void)dealloc
{
	[image release];
	[imageIdentifier release];
	[imageSourceEnumerator release];
	
	[super dealloc];
}


@end

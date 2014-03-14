//
//  MacOSaiXSourceImage.m
//  MacOSaiX
//
//  Created by Frank Midgley on 2/11/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "MacOSaiXSourceImage.h"

#import "MacOSaiXImageCache.h"


@implementation MacOSaiXSourceImage


+ (id)sourceImageWithImage:(NSImage *)inImage	
				identifier:(NSString *)inIdentifier 
					source:(id<MacOSaiXImageSource>)inSource
{
	return [[[self alloc] initWithImage:inImage 
							 identifier:inIdentifier 
								 source:inSource] autorelease];
}


- (id)initWithImage:(NSImage *)inImage 
		 identifier:(NSString *)inImageIdentifier 
			 source:(id<MacOSaiXImageSource>)inImageSource
{
	if (self = [super init])
	{
		[self setImage:inImage];
		imageIdentifier = [inImageIdentifier retain];
		imageSource = [inImageSource retain];
		
		if (!inImageIdentifier)
			NSLog(@"There you are...");
		
		key = [[NSString alloc] initWithFormat:@"%p\t%@", imageSource, imageIdentifier];
	}
	
	return self;
}


- (void)setImage:(NSImage *)inImage
{
	if (image != inImage)
	{
		[image autorelease];
		image = [inImage retain];
		
		if (image)
			imageSize = [image size];
	}
}


- (NSImage *)image
{
	return [[image retain] autorelease];
}


- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size
{
	return [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:size forSourceImage:self];
}


- (NSSize)size
{
	if (NSEqualSizes(imageSize, NSZeroSize))
	{
		[[MacOSaiXImageCache sharedImageCache] lock];
		
		imageSize = [[MacOSaiXImageCache sharedImageCache] nativeSizeOfSourceImage:self];
		
		if (NSEqualSizes(imageSize, NSZeroSize))
		{
				// The image is not in the cache so force it to load.
			[self imageRepAtSize:NSZeroSize];
			imageSize = [[MacOSaiXImageCache sharedImageCache] nativeSizeOfSourceImage:self];
		}
		
		[[MacOSaiXImageCache sharedImageCache] unlock];
	}
	
	return imageSize;
}


- (id<MacOSaiXImageSource>)source
{
	return imageSource;
}


- (NSString *)identifier
{
	return imageIdentifier;
}


- (BOOL)isEqual:(id)otherObject
{
	return ((self == otherObject) || 
			([otherObject isKindOfClass:[self class]] && imageSource == [(MacOSaiXSourceImage *)otherObject source] && [imageIdentifier isEqualToString:[otherObject identifier]]));
}


- (unsigned)hash
{
	return [imageSource hash] + [imageIdentifier hash];
}


- (NSComparisonResult)compare:(MacOSaiXSourceImage *)otherImage
{
	if (imageSource > [otherImage source])
		return NSOrderedDescending;
	else if (imageSource < [otherImage source])
		return NSOrderedAscending;
	else
		return [imageIdentifier compare:[otherImage identifier]];
}


- (NSString *)key
{
	return key;
}


- (NSString *)description
{
	return [imageSource descriptionForIdentifier:imageIdentifier];
}


- (NSString *)debugDescription
{
	return [NSString stringWithFormat:@"%p: %@", imageSource, imageIdentifier];
}


- (NSURL *)URL
{
	return [imageSource urlForIdentifier:imageIdentifier];
}


- (NSURL *)contextURL
{
	return [imageSource contextURLForIdentifier:imageIdentifier];
}


- (void)dealloc
{
	[image release];
	[imageIdentifier release];
	[imageSource release];
	
	[key release];
	
	[super dealloc];
}

@end

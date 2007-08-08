//
//  MacOSaiXEnumeratedImage.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEnumeratedImage.h"

#import "MacOSaiXImageSource.h"
#import "MacOSaiXImageSourceEnumerator.h"


@implementation MacOSaiXEnumeratedImage : MacOSaiXSourceImage


+ (id)imageWithIdentifier:(NSString *)identifier fromEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator
{
	MacOSaiXEnumeratedImage	*image = [[[self class] alloc] initWithIdentifier:identifier fromEnumerator:enumerator];
	
	return [image autorelease];
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


- (MacOSaiXImageSourceEnumerator *)enumerator
{
	return imageSourceEnumerator;
}


- (Class)imageSourceClass
{
	return [[[self enumerator] workingImageSource] class];
}


- (id<MacOSaiXImageSource>)imageSource
{
	return [[self enumerator] workingImageSource];
}


- (NSString *)imageIdentifier
{
	return imageIdentifier;
}


- (id<NSObject,NSCoding,NSCopying>)universalIdentifier
{
	return [[[self enumerator] workingImageSource] universalIdentifierForIdentifier:[self imageIdentifier]];
}


- (NSString *)description
{
	return [[[self enumerator] workingImageSource] descriptionForIdentifier:[self imageIdentifier]];
}


- (unsigned)hash
{
	// TBD: is this ever called?
	return [NSStringFromClass([[[self enumerator] imageSource] class]) hash] + [[self universalIdentifier] hash];
}


- (BOOL)isEqual:(id)otherObject
{
	BOOL	isEqual = (self == otherObject);
	
	if (!isEqual)
	{
		if ([otherObject isKindOfClass:[self class]])
			isEqual = ([(MacOSaiXEnumeratedImage *)otherObject enumerator] == [self enumerator] && 
					   [[(MacOSaiXEnumeratedImage *)otherObject imageIdentifier] isEqualToString:[self imageIdentifier]]);
		else
			isEqual = [super isEqual:otherObject];
	}
	
	return isEqual;
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[MacOSaiXEnumeratedImage alloc] initWithIdentifier:[self imageIdentifier] 
												fromEnumerator:[self enumerator]];
}


- (void)dealloc
{
	[imageIdentifier release];
	[imageSourceEnumerator release];
	
	[super dealloc];
}


@end

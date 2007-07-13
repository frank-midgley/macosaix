//
//  MacOSaiXDisallowedImage.m
//  MacOSaiX
//
//  Created by Frank Midgley on 7/9/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXDisallowedImage.h"

#import "MacOSaiXImageSourceEnumerator.h"
#import "MacOSaiXSourceImage.h"


@implementation MacOSaiXDisallowedImage


+ (MacOSaiXDisallowedImage *)imageWithSourceImage:(MacOSaiXSourceImage *)sourceImage
{
	return [[[self alloc] initWithSourceImage:sourceImage] autorelease];
}


+ (MacOSaiXDisallowedImage *)imageWithSourceClass:(Class)class universalIdentifier:(id<NSObject,NSCoding,NSCopying>)identifier
{
	return [[[self alloc] initWithSourceClass:class universalIdentifier:identifier] autorelease];
}


- (id)initWithSourceImage:(MacOSaiXSourceImage *)sourceImage;
{
	if (self = [super init])
	{
		imageSourceClass = [(id)[[sourceImage enumerator] imageSource] class];
		universalIdentifier = [[sourceImage universalIdentifier] retain];
	}
	
	return self;
}


- (id)initWithSourceClass:(Class)class universalIdentifier:(id<NSObject,NSCoding,NSCopying>)identifier
{
	if (self = [super init])
	{
		imageSourceClass = class;
		universalIdentifier = [identifier copyWithZone:[self zone]];
	}
	
	return self;
}


- (Class)imageSourceClass;
{
	return imageSourceClass;
}


- (id<NSObject,NSCoding,NSCopying>)universalIdentifier
{
	return universalIdentifier;
}


- (unsigned)hash
{
	return [NSStringFromClass(imageSourceClass) hash] + [universalIdentifier hash];
}


- (BOOL)isEqual:(id)otherObject
{
	BOOL	isEqual = (self == otherObject);
	
	if (!isEqual)
	{
		if ([otherObject isKindOfClass:[self class]])
			isEqual = ([self imageSourceClass] == [otherObject imageSourceClass] &&
					   [[self universalIdentifier] isEqual:[otherObject universalIdentifier]]);
		else if ([otherObject isKindOfClass:[MacOSaiXSourceImage class]])
			isEqual = ([self imageSourceClass] == [(id)[[otherObject enumerator] imageSource] class] &&
					   [[self universalIdentifier] isEqual:[otherObject universalIdentifier]]);
	}
	
	return isEqual;
}


- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: %@", [self imageSourceClass], [self universalIdentifier]];
}


- (void)dealloc
{
	[universalIdentifier release];
	
	[super dealloc];
}


@end

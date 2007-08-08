//
//  MacOSaiXUniversalImage.m
//  MacOSaiX
//
//  Created by Frank Midgley on 7/9/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXDisallowedImage.h"

#import "MacOSaiXImageSource.h"
#import "MacOSaiXSourceImage.h"


@implementation MacOSaiXUniversalImage


+ (MacOSaiXUniversalImage *)imageWithSourceClass:(Class)class universalIdentifier:(id<NSObject,NSCoding,NSCopying>)identifier
{
	return [[[self alloc] initWithSourceClass:class universalIdentifier:identifier] autorelease];
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


- (id<MacOSaiXImageSource>)imageSource
{
	if (!imageSource)
		imageSource = [[imageSourceClass imageSourceForUniversalIdentifier:[self universalIdentifier]] retain];
	
	return imageSource;
}


- (NSString *)imageIdentifier
{
	return [[self imageSource] identifierForUniversalIdentifier:[self universalIdentifier]];
}


- (id<NSObject,NSCoding,NSCopying>)universalIdentifier
{
	return universalIdentifier;
}


- (unsigned)hash
{
		// TBD: is this ever called?
	return [NSStringFromClass(imageSourceClass) hash] + [universalIdentifier hash];
}


- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: %@", [self imageSourceClass], [self universalIdentifier]];
}


- (void)dealloc
{
	[imageSource release];
	
	[super dealloc];
}


@end

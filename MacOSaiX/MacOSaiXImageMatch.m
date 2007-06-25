//
//  MacOSaiXImageMatch.m
//  MacOSaiX
//
//  Created by Frank Midgley on 9/5/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageMatch.h"

#import "MacOSaiXSourceImage.h"


@implementation MacOSaiXImageMatch


+ (id)imageMatchWithValue:(float)inValue 
		   forSourceImage:(MacOSaiXSourceImage *)inImage
				  forTile:(MacOSaiXTile *)inTile
{
	return [[[self alloc] initWithMatchValue:inValue 
							  forSourceImage:inImage 
									 forTile:inTile] autorelease];
}


- (id)initWithMatchValue:(float)inMatchValue 
		  forSourceImage:(MacOSaiXSourceImage *)inImage
				 forTile:(MacOSaiXTile *)inTile
{
	if (self = [super init])
	{
		matchValue = inMatchValue;
		sourceImage = [inImage retain];
		tile = inTile;
	}
	
	return self;
}


- (float)matchValue
{
	return matchValue;
}


- (MacOSaiXSourceImage *)sourceImage
{
	return sourceImage;
}


- (MacOSaiXTile *)tile
{
	return tile;
}


- (void)setTile:(MacOSaiXTile *)inTile
{
	tile = inTile;	// don't retain
}


- (NSComparisonResult)compare:(MacOSaiXImageMatch *)otherMatch
{
	float	otherMatchValue = [otherMatch matchValue];
	
	if (matchValue > otherMatchValue)
		return NSOrderedDescending;
	else if (matchValue < otherMatchValue)
		return NSOrderedAscending;
	else
		return NSOrderedSame;	// TBD: return [sourceImage compare:[otherMatch sourceImage]]?
}


- (void)dealloc
{
	[sourceImage release];
	
	[super dealloc];
}


@end

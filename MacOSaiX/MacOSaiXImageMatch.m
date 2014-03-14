//
//  MacOSaiXImageMatch.m
//  MacOSaiX
//
//  Created by Frank Midgley on 9/5/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageMatch.h"

#import "MacOSaiXSourceImage.h"
#import "Tiles.h"


@implementation MacOSaiXImageMatch


+ (id)imageMatchWithValue:(float)inMatchValue 
			  sourceImage:(MacOSaiXSourceImage *)inSourceImage
					 tile:(MacOSaiXTile *)inTile
{
	return [[[self alloc] initWithMatchValue:inMatchValue 
								 sourceImage:inSourceImage 
										tile:inTile] autorelease];
}


- (id)initWithMatchValue:(float)inMatchValue 
			 sourceImage:(MacOSaiXSourceImage *)inSourceImage
					tile:(MacOSaiXTile *)inTile
{
	if (self = [super init])
	{
		matchValue = inMatchValue;
		sourceImage = [inSourceImage retain];
		tile = inTile;
//		lock = [[NSLock alloc] init];
	}
	
	return self;
}


- (void)setMatchValue:(float)value
{
	matchValue = value;
}


- (float)matchValue
{
	return matchValue;
}


- (MacOSaiXSourceImage *)sourceImage
{
	return sourceImage;
}


- (void)setTile:(MacOSaiXTile *)inTile
{
	tile = inTile;	// don't retain
}


- (MacOSaiXTile *)tile
{
	return tile;
}


- (NSString *)description
{
	return [NSString stringWithFormat:@"%f\t%@\t%@:%@", matchValue, tile, [sourceImage source], [sourceImage identifier]];
}


- (NSComparisonResult)compareByMatchThenSourceImage:(MacOSaiXImageMatch *)otherMatch
{
	float	otherMatchValue = [otherMatch matchValue];
	
	if (matchValue > otherMatchValue)
		return NSOrderedDescending;
	else if (matchValue < otherMatchValue)
		return NSOrderedAscending;
	else
		return [sourceImage compare:[otherMatch sourceImage]];
}


- (NSComparisonResult)compareByMatchThenTile:(MacOSaiXImageMatch *)otherMatch
{
	float	otherMatchValue = [otherMatch matchValue];
	
	if (matchValue > otherMatchValue)
		return NSOrderedDescending;
	else if (matchValue < otherMatchValue)
		return NSOrderedAscending;
	else if (tile < [otherMatch tile])
		return NSOrderedDescending;
	else if (tile > [otherMatch tile])
		return NSOrderedAscending;
	else
		return NSOrderedSame;
}


- (BOOL)isEqual:(id)otherObject
{
	return ((self == otherObject) || 
			([otherObject isKindOfClass:[self class]] && tile == [(MacOSaiXImageMatch *)otherObject tile] && [sourceImage isEqual:[otherObject sourceImage]]));
}


//- (id)retain
//{
//	id returnValue = nil;
//	
//	[lock lock];
//		returnValue = [super retain];
//	[lock unlock];
//	
//	return returnValue;
//}
//
//
//- (void)release
//{
//	[lock lock];
//		[super release];
//	[lock unlock];
//}


- (void)dealloc
{
	[sourceImage release];
	//[lock autorelease];
	
	[super dealloc];
}


@end

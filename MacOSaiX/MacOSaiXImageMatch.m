//
//  MacOSaiXImageMatch.m
//  MacOSaiX
//
//  Created by Frank Midgley on 9/5/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageMatch.h"


@implementation MacOSaiXImageMatch


+ (id)imageMatchWithValue:(float)inValue 
	   forImageIdentifier:(NSString *)inIdentifier 
		  fromImageSource:(id<MacOSaiXImageSource>)inSource
				  forTile:(MacOSaiXTile *)inTile
{
	return [[[self alloc] initWithMatchValue:inValue 
						  forImageIdentifier:inIdentifier 
							 fromImageSource:inSource 
									 forTile:inTile] autorelease];
}


- (id)initWithMatchValue:(float)inMatchValue 
	  forImageIdentifier:(NSString *)inImageIdentifier 
		 fromImageSource:(id<MacOSaiXImageSource>)inImageSource
				 forTile:(MacOSaiXTile *)inTile
{
	if (self = [super init])
	{
		matchValue = inMatchValue;
		imageIdentifier = [inImageIdentifier retain];
		imageSource = [inImageSource retain];
		tile = inTile;
	}
	
	return self;
}


- (float)matchValue
{
	return matchValue;
}


- (id<MacOSaiXImageSource>)imageSource
{
	return imageSource;
}


- (NSString *)imageIdentifier
{
	return imageIdentifier;
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
		return NSOrderedSame;
}


- (void)dealloc
{
	[imageIdentifier release];
	[imageSource release];
	
	[super dealloc];
}


@end

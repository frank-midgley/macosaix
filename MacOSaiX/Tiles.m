#import <string.h>
#import "Tiles.h"


@implementation ImageMatch


- (id)initWithMatchValue:(float)inMatchValue 
	  forImageIdentifier:(id<NSCopying>)inImageIdentifier 
		 fromImageSource:(ImageSource *)inImageSource
{
	if (self = [super init])
	{
		matchValue = inMatchValue;
		imageIdentifier = [inImageIdentifier retain];
		imageSource = [inImageSource retain];
	}
	
	return self;
}


- (float)matchValue
{
	return matchValue;
}


- (ImageSource *)imageSource
{
	return imageSource;
}


- (id<NSCopying>)imageIdentifier
{
	return imageIdentifier;
}


- (void)dealloc
{
	[imageIdentifier release];
	[imageSource release];
	
	[super dealloc];
}


@end


#pragma mark -


@implementation Tile


- (id)initWithOutline:(NSBezierPath *)inOutline fromDocument:(NSDocument *)inDocument
{
    self = [super init];
    
    imageMatchesLock = [[NSLock alloc] init];
    bestMatchLock = [[NSLock alloc] init];
	
	imageMatches = [[NSMutableArray array] retain];
	
    outline = [inOutline copy];
    document = inDocument;	// the document retains us so we don't retain it
    
    return self;
}


- (void)addNeighbor:(Tile *)neighboringTile
{
	if (!neighborSet)
		neighborSet = [[NSMutableSet setWithCapacity:10] retain];
	
	[neighborSet addObject:neighboringTile];
}


- (void)removeNeighbor:(Tile *)nonNeighboringTile
{
	[neighborSet removeObject:nonNeighboringTile];
}


- (NSArray *)neighbors
{
	return [neighborSet allObjects];
}


- (void)setOutline:(NSBezierPath *)inOutline
{
    [outline autorelease];
    outline = [inOutline retain];
}


- (NSBezierPath *)outline
{
    return outline;
}


- (void)setBitmapRep:(NSBitmapImageRep *)inBitmapRep withMask:(NSBitmapImageRep *)inMaskRep
{
    [bitmapRep autorelease];
    bitmapRep = [inBitmapRep retain];
    [maskRep autorelease];
    maskRep = [inMaskRep retain];
}


- (NSBitmapImageRep *)bitmapRep
{
    return bitmapRep;
}


	// Match this tile's bitmap against matchRep and return whether the new match is better
	// than this tile's previous worst.
- (BOOL)matchAgainstImageRep:(NSBitmapImageRep *)matchRep
			  withIdentifier:(id<NSCopying>)imageIdentifier
		     fromImageSource:(ImageSource *)imageSource
{
    int				bytesPerPixel1, bytesPerRow1, bytesPerPixel2, bytesPerRow2, maskBytesPerPixel, maskBytesPerRow;
    int				pixelCount = 0, pixelsLeft;
    int				x, y, x_off, y_off, x_size, y_size;
    int				index = 0;  //, left, right;
    unsigned char	*bitmap1, *bitmap2, *maskBitmap;
    float			prevWorst, matchValue = 0.0;
    
    if (matchRep == nil) return NO;
    
		// the size of bitmapRep will be a maximum of TILE_BITMAP_SIZE pixels
		// the size of the smaller dimension of imageRep will be TILE_BITMAP_SIZE pixels
		// pixels in imageRep outside of bitmapRep centered in imageRep will be ignored
    
    bitmap1 = [bitmapRep bitmapData];	NSAssert(bitmap1 != nil, @"bitmap1 is nil");
    maskBitmap = [maskRep bitmapData];
    bitmap2 = [matchRep bitmapData];	NSAssert(bitmap2 != nil, @"bitmap2 is nil");
    bytesPerPixel1 = [bitmapRep hasAlpha] ? 4 : 3;
    bytesPerRow1 = [bitmapRep bytesPerRow];
    maskBytesPerPixel = [maskRep hasAlpha] ? 4 : 3;
    maskBytesPerRow = [maskRep bytesPerRow];
    bytesPerPixel2 = [matchRep hasAlpha] ? 4 : 3;
    bytesPerRow2 = [matchRep bytesPerRow];
    
    prevWorst = ([imageMatches count] == 0 || [imageMatches count] < ([neighborSet count] + 1)) ? 
					WORST_CASE_PIXEL_MATCH : [[imageMatches lastObject] matchValue];

		// one of the offsets should be 0
    x_off = ([matchRep size].width - [bitmapRep size].width) / 2.0;
    y_off = ([matchRep size].height - [bitmapRep size].height) / 2.0;

		// sum the difference of all the pixels in the two bitmaps using the Riemersma metric
		// (courtesy of Dr. Dobbs 11/2001 pg. 58)
    x_size = [bitmapRep size].width; y_size = [bitmapRep size].height;
    pixelsLeft = x_size * y_size;
    for (x = 0; x < x_size; x++)
    {
		for (y = 0; y < y_size; y++)
		{
            unsigned char	*bitmap1_off = bitmap1 + x * bytesPerPixel1 + y * bytesPerRow1,
                            *bitmap2_off = bitmap2 + (x + x_off) * bytesPerPixel2 + (y + y_off) * bytesPerRow2,
                            *mask_off = maskBitmap + x * maskBytesPerPixel + y * maskBytesPerRow;
                
                // If there's no alpha channel or the alpha channel bit is not 0 then consider this pixel
//			if (bytesPerPixel1 == 3 || *bitmap1_off > 0)
			{
                int		redDiff = *bitmap1_off - *bitmap2_off, 
                        greenDiff = *(bitmap1_off + 1) - *(bitmap2_off + 1), 
                        blueDiff = *(bitmap1_off + 2) - *(bitmap2_off + 2);
                
#if 0
				float	redAverage = (*bitmap1_off + *bitmap2_off) / 2.0;
				matchValue += ((2.0 + redAverage / 256.0) * redDiff * redDiff + 
                               4 * greenDiff * greenDiff + 
                               (2 + (255.0 - redAverage) / 256.0) * blueDiff * blueDiff)
                               * ((*mask_off) / 256.0); // weighted by alpha value from mask
#else
                matchValue += (redDiff * redDiff + greenDiff * greenDiff + blueDiff * blueDiff) * ((*mask_off) / 256.0);
#endif
				pixelCount++;
			}
		}
		pixelsLeft -= y_size;
		
		// The lower the matchValue the better, so if it's already greater than the previous worst
		// then it's no use going any further.
//		if (matchValue / (float)(pixelCount + pixelsLeft) > prevWorst) return NO;
    }

		// now average it per pixel
    if (pixelCount == 0)
		NSLog(@"Transparent image matched?");
    matchValue /= pixelCount;
//    NSLog(@"Match value = %f", matchValue);
    if (matchValue > prevWorst)
		return NO;
    
		// Determine where in the list it belongs (the best match should always be at index 0)
    for (index = 0; index < [imageMatches count]; index++)
        if (matchValue < [[imageMatches objectAtIndex:index] matchValue])
            break;

/*
    left = 0; right = matchCount; index = 0;
    while (right > left)
    {
		index = (int)((left + right) / 2);
		if (matchValue > imageMatches[index].matchValue)
			left = index + 1;
		else
			right = index;
    }
*/	
//	NSLog(@"      Adding matching image (%f) to tile %p at index %d", matchValue, self, index);

//    if (index < ([neighborSet count] + 1))
//    {
        [imageMatchesLock lock];
                // Add the new match to the list of matches at the correct position
			ImageMatch  *newMatch = [[[ImageMatch alloc] initWithMatchValue:matchValue
														 forImageIdentifier:imageIdentifier 
															fromImageSource:imageSource] autorelease];
			[imageMatches insertObject:newMatch atIndex:index];
			
                // If we already have the max number of matches we need then let go of our worst match
            if ([imageMatches count] > [neighborSet count] + 1)
            {
				[imageMatches removeLastObject];
				
                    // If the match just removed was our current best then recalculate	// or just signal the need to recalculate?
//                if ([imageMatches indexOfObjectIdenticalTo:bestImageMatch] == NSNotFound)
//                    [self calculateBestMatch];
            }
        [imageMatchesLock unlock];
        
            // mark the document as needing saving
        [document updateChangeCount:NSChangeDone];
//    }
    
    return YES;
}


- (ImageMatch *)displayedImageMatch
{
	if (userChosenImageMatch)
		return [[userChosenImageMatch retain] autorelease];
	else if (bestImageMatch)
		return [[bestImageMatch retain] autorelease];
	else if ([imageMatches count] > 0)
		return [imageMatches objectAtIndex:0];
	else
		return nil;
}


    // Pick the match with the highest value that isn't already used by one of our neighbors.
    // If all matches are already in use then pick the match with the highest value.
- (BOOL)calculateBestMatch
{
	BOOL	bestMatchChanged = NO;
	
        // If the user has picked a specific image to use then no calculation is necessary
	if ([imageMatches count]> 0 && !userChosenImageMatch)
	{
        [imageMatchesLock lock];
		#if 0
			bestMatchTileImage = nil;
			
			int	i;
			for (i = 0; i < [imageMatches count] && !bestMatchTileImage; i++)
			{
				NSEnumerator	*neighborEnumerator = [neighborSet objectEnumerator];
				Tile			*neighbor;
				BOOL			betterThanNeighbors = YES;
				
				while (betterThanNeighbors && (neighbor = [neighborEnumerator nextObject]))
					if (imageMatches[i].matchValue > [neighbor matchValueForTileImage:imageMatches[i].cachedImage])
						betterThanNeighbors = NO;
				
				if (betterThanNeighbors)
				{
					bestMatchTileImage = imageMatches[i].cachedImage;
					bestMatchChanged = YES;
				}
			}
			
			if (!bestMatchTileImage)
			{
				bestMatchTileImage = imageMatches[0].cachedImage;
				bestMatchChanged = YES;
			}
		#else
				// Get the set of images used by our neighbors
			NSMutableSet	*imagesInUseByNeighbors = [NSMutableSet set];
			NSEnumerator	*neighborEnumerator = [neighborSet objectEnumerator];
			Tile			*neighboringTile = nil;
			while (neighboringTile = [neighborEnumerator nextObject])
			{
				ImageMatch  *neighborMatch = [neighboringTile displayedImageMatch];
				
				if (neighborMatch)
					[imagesInUseByNeighbors addObject:[NSArray arrayWithObjects:
															[neighborMatch imageIdentifier],
															[neighborMatch imageSource],
															nil]];
			}
				
				// Loop through our matches and pick the first one not in use by any of our neighbors
			NSEnumerator	*matchEnumerator = [imageMatches objectEnumerator];
			ImageMatch		*imageMatch = nil,
							*originalBestMatch = bestImageMatch;
			[bestImageMatch release];
			bestImageMatch = nil;
			while (!bestImageMatch && (imageMatch = [matchEnumerator nextObject]))
				if (![imagesInUseByNeighbors containsObject:[NSArray arrayWithObjects:
																[imageMatch imageIdentifier],
																[imageMatch imageSource],
																nil]])
					bestImageMatch = [imageMatch retain];
//				else
//					NSLog(@"phew");
			
			bestMatchChanged = (originalBestMatch != bestImageMatch);
		#endif
        [imageMatchesLock unlock];
	}
	
	return bestMatchChanged;
}


- (void)setUserChosenImageIdentifer:(id<NSCopying>)imageIdentifier fromImageSource:(ImageSource *)imageSource
{
/*
        // Don't do anything if the chosen image was already chosen
    if (userChosenImageMatch != nil && userChosenImageMatch->tileImageIndex == index) return;
    
    if (index == -1)
    {
		if (userChosenImageMatch != nil)
		{
			[document tileImageIndexNotInUse:userChosenImageMatch->tileImageIndex];
			free(userChosenImageMatch);
			userChosenImageMatch = nil;
		}
    }
    else
    {
		if (userChosenImageMatch == nil)
			userChosenImageMatch = (ImageMatch *)malloc(sizeof(ImageMatch));
		else
			[document tileImageIndexNotInUse:userChosenImageMatch->tileImageIndex];
		userChosenImageMatch->matchValue = 0;
		userChosenImageMatch->tileImageIndex = index;
		[document tileImageIndexInUse:userChosenImageMatch->tileImageIndex];
    }
*/
}


- (ImageMatch *)userChosenImageMatch;
{
	return [[userChosenImageMatch retain] autorelease];
}


- (NSArray *)matches
{
    return imageMatches;
}


- (int)matchCount
{
    return [imageMatches count];
}


- (void)lockMatches
{
    [imageMatchesLock lock];
}


- (void)unlockMatches
{
    [imageMatchesLock unlock];
}


- (float)matchValueForImageIdentifer:(id<NSCopying>)imageIdentifier fromImageSource:(ImageSource *)imageSource
{
	float	matchValue = WORST_CASE_PIXEL_MATCH;
	
    [imageMatchesLock lock];
		NSEnumerator	*matchEnumerator = [imageMatches objectEnumerator];
		ImageMatch		*imageMatch = nil;
		
		while (imageMatch = [matchEnumerator nextObject])
			if ([[imageMatch imageIdentifier] isEqualTo:imageIdentifier] && [[imageMatch imageSource] isEqualTo:imageSource])
			{
				matchValue = [imageMatch matchValue];
				break;
			}
    [imageMatchesLock unlock];
	
	return matchValue;
}


- (void)dealloc
{
    [userChosenImageMatch release];
    [imageMatchesLock release];
    [bestMatchLock release];
    [outline release];
    [bitmapRep release];
    [imageMatches release];
	
    [super dealloc];
}


@end

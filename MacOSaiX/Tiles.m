#import <string.h>
#import "Tiles.h"
//#import "TileMatch.h"

@implementation Tile

- (id)init
{
    self = [super init];
    
    _tileMatchesLock = [[NSLock alloc] init];
    _bestMatchLock = [[NSLock alloc] init];
	NSAssert(_tileMatchesLock != nil, @"Could not alloc/init tile matches lock");
    _outline = nil;
    _bitmapRep = nil;
    _matches = nil;
    _matchCount = 0;
    _userChosenImageMatch = nil;
    
    return self;
}


- (void)addNeighbor:(Tile *)neighboringTile
{
	if (!_neighborSet) _neighborSet = [[NSMutableSet setWithCapacity:10] retain];
	[_neighborSet addObject:neighboringTile];
}


- (void)removeNeighbor:(Tile *)nonNeighboringTile
{
	[_neighborSet removeObject:nonNeighboringTile];
}


- (NSArray *)neighbors
{
	return (_neighborSet ? [_neighborSet allObjects] : nil);
}


- (void)setOutline:(NSBezierPath *)outline
{
    [_outline autorelease];
    _outline = [outline retain];
}


- (NSBezierPath *)outline
{
    return _outline;
}


- (void)setBitmapRep:(NSBitmapImageRep *)bitmapRep
{
    [_bitmapRep autorelease];
    _bitmapRep = [bitmapRep retain];
}


- (NSBitmapImageRep *)bitmapRep
{
    return _bitmapRep;
}


- (void)setDocument:(NSDocument *)document
{
    _document = document;
}


	// Match this tile's bitmap against matchRep and return whether the new match is better
	// than this tile's previous worst.
- (BOOL)matchAgainstImageRep:(NSBitmapImageRep *)matchRep fromTileImage:(TileImage *)tileImage
				  forDocument:(NSDocument *)document
{
    int				bytesPerPixel1, bytesPerRow1, bytesPerPixel2, bytesPerRow2;
    int				pixelCount = 0, pixelsLeft;
    int				x, y, x_off, y_off, x_size, y_size;
    int				index = 0, left, right;
    unsigned char	*bitmap1, *bitmap2;
    float			prevWorst, matchValue = 0.0;
    
    if (matchRep == nil) return NO;
    
    [_tileMatchesLock lock];
		if (_matches == nil)
			_matches = (TileMatch *)malloc(sizeof(TileMatch) * ([_neighborSet count] + 1));
    [_tileMatchesLock unlock];

		// the size of _bitmapRep will be a maximum of TILE_BITMAP_SIZE pixels
		// the size of the smaller dimension of imageRep will be TILE_BITMAP_SIZE pixels
		// pixels in imageRep outside of _bitmapRep centered in imageRep will be ignored
    
    bitmap1 = [_bitmapRep bitmapData];	NSAssert(bitmap1 != nil, @"bitmap1 is nil");
    bitmap2 = [matchRep bitmapData];	NSAssert(bitmap2 != nil, @"bitmap2 is nil");
    bytesPerPixel1 = [_bitmapRep hasAlpha] ? 4 : 3;
    bytesPerRow1 = [_bitmapRep bytesPerRow];
    bytesPerPixel2 = [matchRep hasAlpha] ? 4 : 3;
    bytesPerRow2 = [matchRep bytesPerRow];
    
    prevWorst = (_matchCount < ([_neighborSet count] + 1)) ? WORST_CASE_PIXEL_MATCH : _matches[_matchCount - 1].matchValue;

		// one of the offsets should be 0
    x_off = ([matchRep size].width - [_bitmapRep size].width) / 2.0;
    y_off = ([matchRep size].height - [_bitmapRep size].height) / 2.0;

		// sum the difference of all the pixels in the two bitmaps using the Riemersma metric
		// (courtesy of Dr. Dobbs 11/2001 pg. 58)
    x_size = [_bitmapRep size].width; y_size = [_bitmapRep size].height;
    pixelsLeft = x_size * y_size;
    for (x = 0; x < x_size; x++)
    {
		for (y = 0; y < y_size; y++)
		{
            unsigned char	*bitmap1_off = bitmap1 + x * bytesPerPixel1 + y * bytesPerRow1,
                            *bitmap2_off = bitmap2 + (x + x_off) * bytesPerPixel2 + (y + y_off) * bytesPerRow2;
                
                // If there's no alpha channel or the alpha channel bit is not 0 then consider this pixel
			if (bytesPerPixel1 == 3 || *bitmap1_off > 0)
			{
                int		redDiff = *bitmap1_off - *bitmap2_off, 
                        greenDiff = *(bitmap1_off + 1) - *(bitmap2_off + 1), 
                        blueDiff = *(bitmap1_off + 2) - *(bitmap2_off + 2);
				float	redAverage = (*bitmap1_off + *bitmap2_off) / 2.0;
                
				matchValue += (2.0 + redAverage / 256.0) * redDiff * redDiff + 
                              4 * greenDiff * greenDiff + 
                              (2 + (255.0 - redAverage) / 256.0) * blueDiff * blueDiff;
//                matchValue += redDiff * redDiff + greenDiff * greenDiff + blueDiff * blueDiff;
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
    if (matchValue > prevWorst) return NO;
    
		// Determine where in the list it belongs (the best match should always be at index 0)
    for (index = 0; index < _matchCount - 1; index++)
        if (matchValue < _matches[index].matchValue)
            break;
/*
    left = 0; right = _matchCount; index = 0;
    while (right > left)
    {
		index = (int)((left + right) / 2);
		if (matchValue > _matches[index].matchValue)
			left = index + 1;
		else
			right = index;
    }
*/	
//	NSLog(@"      Adding matching image (%f) to tile %p at index %d", matchValue, self, index);

    [_tileMatchesLock lock];
            // If we already have the max number of matches we need then let go of our worst match
		if (_matchCount == [_neighborSet count] + 1)
        {
                // If our worst match was our current best then signal the need to recalculate
            if (_bestMatchTileImage == _matches[_matchCount - 1].tileImage)
                [self calculateBestMatch];
                //_bestMatchTileImage = nil;
			[_matches[_matchCount - 1].tileImage imageIsNotInUse];
        }
        
			// Add the new match to the list of matches at the correct position
		bcopy(&_matches[index], &_matches[index + 1], sizeof(TileMatch) * ([_neighborSet count] - index));
		_matches[index].matchValue = matchValue;
		_matches[index].tileImage = tileImage;
		
		[tileImage imageIsInUse];
		
		if (_matchCount <= [_neighborSet count]) _matchCount++;
    [_tileMatchesLock unlock];
    
		// mark the document as needing saving
    [document updateChangeCount:NSChangeDone];
    
    return YES;
}


- (TileImage *)displayedTileImage
{
	if (_userChosenImageMatch)
		return _userChosenImageMatch->tileImage;
	
    if (_matchCount == 0)
        return nil;
    
//    if (!_bestMatchTileImage)
//        [self calculateBestMatch];
        
    return _bestMatchTileImage;
}


    // Pick the match with the highest value that isn't already used by one of our neighbors.
    // If all matches are already in use then pick the match with the highest value.
- (void)calculateBestMatch
{
        // If the user has picked a specific image to use then no calculation is necessary
	if (_matchCount == 0 || _userChosenImageMatch)
		return;
	
    [_bestMatchLock lock];
#if 1
        _bestMatchTileImage = nil;
        
        int	i;
        for (i = 0; i < _matchCount && !_bestMatchTileImage; i++)
        {
            NSEnumerator	*neighborEnumerator = [_neighborSet objectEnumerator];
            Tile			*neighbor;
            BOOL			betterThanNeighbors = YES;
            
            while (betterThanNeighbors && (neighbor = [neighborEnumerator nextObject]))
                if (_matches[i].matchValue > [neighbor matchValueForTileImage:_matches[i].tileImage])
                    betterThanNeighbors = NO;
            
            if (betterThanNeighbors)
                _bestMatchTileImage = _matches[i].tileImage;
        }
        
        if (!_bestMatchTileImage)
            _bestMatchTileImage = _matches[0].tileImage;
#else
            // Start by going for our best match.
        _bestMatchTileImage = _matches[0].tileImage;

            // Get the set of tile images used by our neighbors
        NSMutableSet	*tileImagesInUseByNeighbors = [NSMutableSet set];
        NSEnumerator	*neighborEnumerator = [_neighborSet objectEnumerator];
        Tile			*neighbor;
        while (neighbor = [neighborEnumerator nextObject])
        {
            TileImage	*neighborsTileImage = [neighbor displayedTileImage];
            
            if (neighborsTileImage) [tileImagesInUseByNeighbors addObject:neighborsTileImage];
        }
            
            // Loop through our matches and pick the first one not in use by any of our neighbors
        int	i;
        for (i = 1; i < _matchCount; i++)
            if (![tileImagesInUseByNeighbors containsObject:_matches[i].tileImage])
            {
                _bestMatchTileImage = _matches[i].tileImage;
                break;
            }
#endif
    [_bestMatchLock unlock];
}


- (void)setUserChosenImageIndex:(TileImage *)userChosenTileImage
{
/*
        // Don't do anything if the chosen image was already chosen
    if (_userChosenImageMatch != nil && _userChosenImageMatch->tileImageIndex == index) return;
    
    if (index == -1)
    {
		if (_userChosenImageMatch != nil)
		{
			[_document tileImageIndexNotInUse:_userChosenImageMatch->tileImageIndex];
			free(_userChosenImageMatch);
			_userChosenImageMatch = nil;
		}
    }
    else
    {
		if (_userChosenImageMatch == nil)
			_userChosenImageMatch = (TileMatch *)malloc(sizeof(TileMatch));
		else
			[_document tileImageIndexNotInUse:_userChosenImageMatch->tileImageIndex];
		_userChosenImageMatch->matchValue = 0;
		_userChosenImageMatch->tileImageIndex = index;
		[_document tileImageIndexInUse:_userChosenImageMatch->tileImageIndex];
    }
*/
}


- (TileImage *)userChosenTileImage
{
    return (_userChosenImageMatch == nil) ? nil : _userChosenImageMatch->tileImage;
}


- (TileMatch *)matches
{
    return _matches;
}


- (int)matchCount
{
    return _matchCount;
}


- (void)lockMatches
{
    [_tileMatchesLock lock];
}


- (void)unlockMatches
{
    [_tileMatchesLock unlock];
}


- (float)matchValueForTileImage:(TileImage *)tileImage
{
	float	matchValue = WORST_CASE_PIXEL_MATCH;
	int		i;
	
    [_tileMatchesLock lock];
		for (i = 0; i < _matchCount; i++)
			if (_matches[i].tileImage == tileImage)
			{
				matchValue = _matches[i].matchValue;
				break;
			}
    [_tileMatchesLock unlock];
	return matchValue;
}


- (void)dealloc
{
    if (_userChosenImageMatch != nil) free(_userChosenImageMatch);
    [_tileMatchesLock release];
    [_bestMatchLock release];
    [_outline release];
    [_bitmapRep release];
    free(_matches);
    [super dealloc];
}


@end

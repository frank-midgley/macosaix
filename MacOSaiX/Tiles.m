#import <string.h>
#import "Tiles.h"
//#import "TileMatch.h"

@implementation Tile

- (id)init
{
    self = [super init];
    
    _tileMatchesLock = [[NSLock alloc] init];
	NSAssert(_tileMatchesLock != nil, @"Could not alloc/init tile matches lock");
    _outline = nil;
    _bitmapRep = nil;
    _matches = nil;
    _matchCount = 0;
    _bestUniqueMatchIndex = -1;
    _userChosenImageMatch = nil;
    
    return self;
}


- (id)initWithCoder:(NSCoder *)coder
{
    float	_userChosenMatchValue;
    
    self = [self init];
    
    [self setOutline:[coder decodeObject]];
    [self setBitmapRep:[coder decodeObject]];
    _maxMatches = [[coder decodeObject] intValue];
    _matches = malloc(_maxMatches * sizeof(TileMatch));
	NSAssert(_matches != nil, @"Could not allocate matches array");
    {
		NSData	*matchesData = [coder decodeObject];
		[matchesData getBytes:_matches];
    }
    _matchCount = [[coder decodeObject] intValue];
    
    _userChosenMatchValue = [[coder decodeObject] floatValue];
    if (_userChosenMatchValue >= 0)
    {
		_userChosenImageMatch = (TileMatch *)malloc(sizeof(TileMatch));
		_userChosenImageMatch->matchValue = _userChosenMatchValue;
		_userChosenImageMatch->tileImageIndex = [[coder decodeObject] longValue];
    }
    
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_outline];
    [coder encodeObject:_bitmapRep];
    [coder encodeObject:[NSNumber numberWithInt:_maxMatches]];
    [coder encodeObject:[NSData dataWithBytes:_matches length:sizeof(TileMatch) * _maxMatches]];
    [coder encodeObject:[NSNumber numberWithInt:_matchCount]];
    if (_userChosenImageMatch == nil)
		[coder encodeObject:[NSNumber numberWithInt:-1]];
    else
    {
		[coder encodeObject:[NSNumber numberWithFloat:_userChosenImageMatch->matchValue]];
		[coder encodeObject:[NSNumber numberWithLong:_userChosenImageMatch->tileImageIndex]];
    }
}


- (void)setMaxMatches:(int)maxMatches
{
    _maxMatches = maxMatches;
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


- (float)matchAgainst:(NSBitmapImageRep *)matchRep tileImage:(TileImage *)tileImage
	  tileImageIndex:(int)tileImageIndex forDocument:(NSDocument *)document
{
    int			bytesPerPixel1, bytesPerRow1, bytesPerPixel2, bytesPerRow2;
    int			pixelCount = 0, pixelsLeft;
    int			x, y, x_off, y_off, r1, r2, g1, g2, b1, b2, x_size, y_size;
    int			index = 0, left, right;
    unsigned char	*bitmap1, *bitmap2, *bitmap1_off, *bitmap2_off;
    float		prevWorst, matchValue = 0.0, redAverage;
    
    if (matchRep == nil) return WORST_CASE_PIXEL_MATCH;
    
		// the size of _bitmapRep will be a maximum of TILE_BITMAP_SIZE pixels
		// the size of the smaller dimension of imageRep will be TILE_BITMAP_SIZE pixels
		// pixels in imageRep outside of _bitmapRep centered in imageRep will be ignored
    
    bitmap1 = [_bitmapRep bitmapData];	NSAssert(bitmap1 != nil, @"bitmap1 is nil");
    bitmap2 = [matchRep bitmapData];	NSAssert(bitmap2 != nil, @"bitmap2 is nil");
    bytesPerPixel1 = [_bitmapRep hasAlpha] ? 4 : 3;
    bytesPerRow1 = [_bitmapRep bytesPerRow];
    bytesPerPixel2 = [matchRep hasAlpha] ? 4 : 3;
    bytesPerRow2 = [matchRep bytesPerRow];
    
    prevWorst = (_matchCount < _maxMatches) ? WORST_CASE_PIXEL_MATCH : _matches[_matchCount - 1].matchValue;

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
			bitmap1_off = bitmap1 + x * bytesPerPixel1 + y * bytesPerRow1;
			r1 = *bitmap1_off++; g1 = *bitmap1_off++; b1 = *bitmap1_off++;
			bitmap2_off = bitmap2 + (x + x_off) * bytesPerPixel2 + (y + y_off) * bytesPerRow2;
			r2 = *bitmap2_off++; g2 = *bitmap2_off++; b2 = *bitmap2_off++;
			if (bytesPerPixel1 == 3 || *bitmap1_off > 0)
			{
				pixelCount++;
				redAverage = (r1 + r2) / 2.0;
				matchValue += (2+redAverage/256.0)*(r1-r2)*(r1-r2) + 4*(g1-g2)*(g1-g2) + 
						(2+(255.0-redAverage)/256.0)*(b1-b2)*(b1-b2);
				if (bytesPerPixel1 == 4) bytesPerPixel1++;
				if (bytesPerPixel2 == 4) bytesPerPixel2++;
			}
		}
		pixelsLeft -= y_size;
		
		// the lower the matchValue the better, so if it's already greater than the previous worst
		// then it's no use going any further
		if (matchValue / (float)(pixelCount + pixelsLeft) > prevWorst) return WORST_CASE_PIXEL_MATCH;
    }

		// now average it per pixel
    if (pixelCount == 0)
		NSLog(@"");
    matchValue /= pixelCount;
    if (matchValue > prevWorst) return WORST_CASE_PIXEL_MATCH;
    
		// Determine where in the list it belongs (the best match should always be at index 0)
    left = 0; right = _matchCount; index = 0;
    while (right > left)
    {
		index = (int)((left + right) / 2);
		if (matchValue > _matches[index].matchValue)
			left = index + 1;
		else
			right = index;
    }

    [_tileMatchesLock lock];
		if (_matches == nil)
			_matches = (TileMatch *)malloc(sizeof(TileMatch) * _maxMatches);
	
		if (_matchCount == _maxMatches)
			[_document tileImageIndexNotInUse:_matches[_matchCount - 1].tileImageIndex];
			// Add it to the list of matches
		if (_bestUniqueMatchIndex >= index && _bestUniqueMatchIndex < _matchCount-1)
			_bestUniqueMatchIndex++;
		bcopy(&_matches[index], &_matches[index + 1], sizeof(TileMatch) * (_maxMatches - index - 1));
		_matches[index].matchValue = matchValue;
		_matches[index].tileImageIndex = tileImageIndex;
		
		[_document tileImageIndexInUse:tileImageIndex];
		
		if (_matchCount < _maxMatches) _matchCount++;
    [_tileMatchesLock unlock];
    
		// mark the document as needing saving
    [document updateChangeCount:NSChangeDone];
    
    return matchValue;
}


- (TileMatch *)bestMatch
{
    return (_matchCount == 0) ? nil : &_matches[0];
}


- (float)bestMatchValue
{
    return (_matchCount == 0) ? WORST_CASE_PIXEL_MATCH : _matches[0].matchValue;
}


- (TileMatch *)bestUniqueMatch
{
    return (_bestUniqueMatchIndex == -1) ? nil : &_matches[_bestUniqueMatchIndex];
}


- (float)bestUniqueMatchValue
{
    return (_bestUniqueMatchIndex == -1) ? WORST_CASE_PIXEL_MATCH : _matches[_bestUniqueMatchIndex].matchValue;
}


- (void)setBestUniqueMatchIndex:(int)matchIndex
{
    _bestUniqueMatchIndex = matchIndex;
}


- (void)setUserChosenImageIndex:(long)index
{
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
}


- (long)userChosenImageIndex
{
    return (_userChosenImageMatch == nil) ? -1 : _userChosenImageMatch->tileImageIndex;
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


- (NSComparisonResult)compareBestMatchValue:(Tile *)otherTile
{
    float	bestMatchValue = [self bestMatchValue], otherBestMatchValue = [otherTile bestMatchValue];
    
    if (_userChosenImageMatch != nil) return NSOrderedAscending;
    
    if (bestMatchValue < otherBestMatchValue)
		return NSOrderedAscending;
    else if (bestMatchValue > otherBestMatchValue)
		return NSOrderedDescending;
    return NSOrderedSame;
}


- (void)dealloc
{
    if (_userChosenImageMatch != nil) free(_userChosenImageMatch);
    [_tileMatchesLock release];
    [_outline release];
    [_bitmapRep release];
    free(_matches);
    [super dealloc];
}


@end

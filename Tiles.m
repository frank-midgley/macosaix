#import "Tiles.h"
#import "TileMatch.h"

@implementation Tile

- (id)init
{
    self = [super init];
    _outline = nil;
    _bitmapRep = nil;
    _matches = [[NSMutableArray arrayWithCapacity:0] retain];
    _displayMatch = nil;
    _displayMatchValue = WORST_CASE_PIXEL_MATCH;
    _bestMatchValue = WORST_CASE_PIXEL_MATCH;
    _userMatch = nil;
    return self;
}


- (id)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    
    [self setOutline:[coder decodeObject]];
    
    [self setBitmapRep:[coder decodeObject]];
    
    [_matches release];
    _matches = [[coder decodeObject] retain];
    
    _displayMatch = [[coder decodeObject] retain];
    if ([_displayMatch isKindOfClass:[NSNull class]])
    {
	[_displayMatch release];
	_displayMatch = nil;
    }
    else
	_displayMatchValue = [_displayMatch matchValue];
	
    if ([_matches count] > 0) _bestMatchValue = [[_matches objectAtIndex:0] matchValue];
    
    _userMatch = [[coder decodeObject] retain];
    if ([_userMatch isKindOfClass:[NSNull class]])
    {
	[_userMatch release];
	_userMatch = nil;
    }
    
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_outline];
    [coder encodeObject:_bitmapRep];
    [coder encodeObject:_matches];
    if (_displayMatch)
	[coder encodeObject:_displayMatch];
    else
	[coder encodeObject:[NSNull null]];
    if (_userMatch)
	[coder encodeObject:_userMatch];
    else
	[coder encodeObject:[NSNull null]];
}


- (void)setTileMatchesLock:(NSLock *)lock { _tileMatchesLock = lock; }
- (void)setMaxMatches:(int)maxMatches { _maxMatches = maxMatches; }


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


- (float)matchAgainst:(NSBitmapImageRep *)matchRep tileImage:(TileImage *)tileImage
	  forDocument:(NSDocument *)document
{
    int			bytesPerPixel1, bytesPerRow1, bytesPerPixel2, bytesPerRow2;
    int			pixelCount = 0, pixelsLeft;
    int			x, y, x_off, y_off, r1, r2, g1, g2, b1, b2, x_size, y_size;
    int			index = 0, left, right;
    unsigned char	*bitmap1, *bitmap2, *bitmap1_off, *bitmap2_off;
    float		prevWorst, matchValue = 0.0, redAverage;
    TileMatch		*newMatch = nil;
    
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
    
    prevWorst = ([_matches count] < _maxMatches) ? WORST_CASE_PIXEL_MATCH :
					 	   [[_matches lastObject] matchValue];

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
	    if (*bitmap1_off > 0)
	    {
		pixelCount++;
		redAverage = (r1 + r2) / 2.0;
		matchValue += (2+redAverage/256.0)*(r1-r2)*(r1-r2) + 4*(g1-g2)*(g1-g2) + 
			      (2+(255.0-redAverage)/256.0)*(b1-b2)*(b1-b2);
	    }
	}
	pixelsLeft -= y_size;
	
	// the lower the matchValue the better, so if it's already greater than the previous worst,
	// it's no use going any further
	if (matchValue / (float)(pixelCount + pixelsLeft) > prevWorst) return WORST_CASE_PIXEL_MATCH;
    }

    // now average it per pixel
    matchValue /= pixelCount;
    if (matchValue > prevWorst) return WORST_CASE_PIXEL_MATCH;
    
    newMatch = [[TileMatch alloc] initWithTileImage:tileImage matchValue:matchValue];
    if (newMatch == nil)
    {
	NSLog(@"Could not allocate new TileMatch");
	return WORST_CASE_PIXEL_MATCH;
    }
    else
	[newMatch autorelease];
    
    // Determine where in the list it belongs (the best match should always be at index 0)
    left = 0; right = [_matches count]; index = 0;
    while (right > left)
    {
	index = (int)((left + right) / 2);
	if (matchValue > [[_matches objectAtIndex:index] matchValue])
	    left = index + 1;
	else
	    right = index;
    }

    [_tileMatchesLock lock];
	// Add it to the list of matches
	[_matches insertObject:newMatch atIndex:index];
	    
	// Only keep the best _maxMatches matches
	if ([_matches count] == _maxMatches + 1)
	{
	    if (_displayMatch == [_matches lastObject]) [self setDisplayMatch:nil];
	    [_matches removeLastObject];
	}
    [_tileMatchesLock unlock];
    
    _bestMatchValue = [[_matches objectAtIndex:0] matchValue];
    
    // mark the document as needing saving
    [document updateChangeCount:NSChangeDone];
    
    return matchValue;
}


- (TileMatch *)bestMatch
{
    return ([_matches count] == 0) ? nil : [_matches objectAtIndex:0];
}


- (float)bestMatchValue
{
    return _bestMatchValue;
}


- (void)setDisplayMatch:(TileMatch *)displayMatch
{
    _displayMatch = displayMatch;
    _displayMatchValue = (_displayMatch == nil ? WORST_CASE_PIXEL_MATCH : [displayMatch matchValue]);
}


- (TileMatch *)displayMatch
{
    return _displayMatch;
}


- (void)setUserMatch:(TileMatch *)userMatch
{
    _userMatch = userMatch;
}


- (TileMatch *)userMatch
{
    return _userMatch;
}


- (float)displayMatchValue
{
    return _displayMatchValue;
}


- (NSMutableArray *)matches
{
    return _matches;
}


- (NSComparisonResult)compareBestMatchValue:(Tile *)otherTile
{
    float	otherBest = [otherTile bestMatchValue];
    
    if (_userMatch != nil) return NSOrderedAscending;
    
    if (_bestMatchValue < otherBest)
	return NSOrderedAscending;
    else if (_bestMatchValue > otherBest)
	return NSOrderedDescending;
    return NSOrderedSame;
}


- (void)dealloc
{
    if (_outline != nil) [_outline release];
    if (_bitmapRep != nil) [_bitmapRep release];
    if (_matches != nil) [_matches release];
    [super dealloc];
}


@end

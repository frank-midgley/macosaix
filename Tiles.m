#import "Tiles.h"
#import "TileMatch.h"

@implementation Tile

- (id)init
{
    [super init];
    _outline = nil;
    _bitmapRep = nil;
    _matches = [[NSMutableArray arrayWithCapacity:0] retain];
    _displayMatch = nil;
    return self;
}


- (id)initWithCoder:(NSCoder *)coder
{
    [self setOutline:[coder decodeObject]];
    [self setBitmapRep:[coder decodeObject]];
    _matches = [[coder decodeObject] retain];
    _displayMatch = nil;
    return self;
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
    NSBitmapImageRep	*oldBitmapRep;
    
    if (bitmapRep != _bitmapRep)
    {
	oldBitmapRep = _bitmapRep;
	_bitmapRep = [bitmapRep retain];
	[oldBitmapRep release];
    }
}


- (NSBitmapImageRep *)bitmapRep
{
    return _bitmapRep;
}


- (float)matchAgainst:(NSBitmapImageRep *)matchRep fromURL:(NSURL *)imageURL
	   displayRep:(NSBitmapImageRep *)displayRep maxMatches:(int)maxMatches
{
    int			bytesPerPixel1, bytesPerRow1, bytesPerPixel2, bytesPerRow2;
    int			pixelCount = 0, pixelsLeft;
    int			x, y, x_off, y_off, r1, r2, g1, g2, b1, b2, index = 0;
    unsigned char	*bitmap1, *bitmap2, *bitmap1_off, *bitmap2_off;
    float		prevWorst, matchValue = 0.0, redAverage;
    TileMatch		*newMatch;
    
    if (matchRep == nil || displayRep == nil) return WORST_CASE_PIXEL_MATCH;
    
    // the size of _bitmapRep will be a maximum of TILE_BITMAP_SIZE pixels
    // the size of the smaller dimension of imageRep will be TILE_BITMAP_SIZE pixels
    // pixels in imageRep outside of _bitmapRep centered in imageRep will be ignored
    
    bitmap1 = [_bitmapRep bitmapData];	NSAssert(bitmap1 != nil, @"bitmap1 is nil");
    bitmap2 = [matchRep bitmapData];	NSAssert(bitmap2 != nil, @"bitmap2 is nil");
    bytesPerPixel1 = [_bitmapRep hasAlpha] ? 4 : 3;
    bytesPerRow1 = [_bitmapRep bytesPerRow];
    bytesPerPixel2 = [matchRep hasAlpha] ? 4 : 3;
    bytesPerRow2 = [matchRep bytesPerRow];
    
    prevWorst = ([_matches count] < maxMatches) ? WORST_CASE_PIXEL_MATCH :
						  [[_matches lastObject] matchValue];

    // one of the offsets should be 0
    x_off = ([matchRep size].width - [_bitmapRep size].width) / 2.0;
    y_off = ([matchRep size].height - [_bitmapRep size].height) / 2.0;

    // sum the difference of all the pixels in the two bitmaps using the Riemersma metric
    // (courtesy of Dr. Dobbs 11/2001 pg. 58)
    pixelsLeft = [_bitmapRep size].width * [_bitmapRep size].height;
    for (x = 0; x < [_bitmapRep size].width; x++)
    {
	for (y = 0; y < [_bitmapRep size].height; y++)
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
	    pixelsLeft--;
	}
	// the lower the matchValue the better, so if it's already greater than the previous worst,
	// it's no use going any further
	if (matchValue / (float)(pixelCount + pixelsLeft) > prevWorst) return WORST_CASE_PIXEL_MATCH;
    }

    // now average it per pixel
    matchValue /= pixelCount;
    if (matchValue > prevWorst) return WORST_CASE_PIXEL_MATCH;
    
    newMatch = [[TileMatch alloc] init];
    if (newMatch == nil)
    {
	NSLog(@"Could not allocate new TileMatch");
	return WORST_CASE_PIXEL_MATCH;
    }
    [newMatch setImageURL:imageURL];
    [newMatch setBitmapRep:displayRep];
    [newMatch setMatchValue:matchValue];
	
    // Determine where in the list it belongs (the best match should always be at index 0)
    while (index < [_matches count] && [[_matches objectAtIndex:index] matchValue] < matchValue) index++;

    // Add it to the list of matches
    [_matches insertObject:newMatch atIndex:index];
	
    // Only keep the best maxMatches matches
    if ([_matches count] == maxMatches + 1)
    {
	[[_matches lastObject] release];
	[_matches removeLastObject];
    }
    
    _bestMatchValue = [[_matches objectAtIndex:0] matchValue];
    
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
    _displayMatchValue = [displayMatch matchValue];
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


- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_outline];
    [coder encodeObject:_bitmapRep];
    [coder encodeObject:_matches];
}


- (void)dealloc
{
    if (_outline != nil) [_outline release];
    if (_bitmapRep != nil) [_bitmapRep release];
    if (_matches != nil) [_matches release];
    [super dealloc];
}


@end

#import "Tiles.h"
#import "TileMatch.h"

#define MAX_MATCHES 2

@implementation Tile

- (id)init
{
    [super init];
    _outline = nil;
    _bitmapRep = nil;
    _matches = [[NSMutableArray arrayWithCapacity:0] retain];
    _displayUpdateQueue = nil;
    return self;
}


- (void)setDisplayUpdateQueue:(NSMutableArray *)displayUpdateQueue
{
    NSMutableArray	*oldDisplayUpdateQueue;
    
    if (displayUpdateQueue != _displayUpdateQueue)
    {
	oldDisplayUpdateQueue = _displayUpdateQueue;
	_displayUpdateQueue = [displayUpdateQueue retain];
	[oldDisplayUpdateQueue release];
    }
}


- (void)setOutline:(NSBezierPath *)outline
{
    NSBezierPath	*oldOutline;
    
    if (outline != _outline)
    {
	oldOutline = _outline;
	_outline = [outline retain];
	[oldOutline release];
    }
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


- (void)matchAgainst:(NSBitmapImageRep *)imageRep fromFile:(NSString *)filePath
{
    int			x, y, r1, r2, g1, g2, b1, b2, index = 0;
    unsigned char	*bitmap1, *bitmap2;
    float		prevWorst, matchValue = 0.0, redAverage;
    TileMatch*		newMatch;
    
    if (imageRep == nil) return;
    
    bitmap1 = [_bitmapRep bitmapData];	NSAssert(bitmap1 != nil, @"bitmap1 is nil");
    bitmap2 = [imageRep bitmapData];	NSAssert(bitmap2 != nil, @"bitmap2 is nil");
    
    prevWorst = ([_matches count] < MAX_MATCHES) ? 520200.0 : [[_matches lastObject] matchValue];
    prevWorst *= [_bitmapRep size].width * [_bitmapRep size].height;
    
    // sum the difference of all the pixels in the two bitmaps using the Riemersma metric (courtesy of Dr. Dobbs 11/2001 pg. 58)
    for (x = 0; x < [_bitmapRep size].width; x++)
	for (y = 0; y < [_bitmapRep size].height; y++)
	{
	    r1 = *bitmap1++; g1 = *bitmap1++; b1 = *bitmap1++;
	    r2 = *bitmap2++; g2 = *bitmap2++; b2 = *bitmap2++;
	    redAverage = (r1 + r2) / 2.0;
	    matchValue += (2+redAverage/256.0)*(r1-r2)*(r1-r2) + 4*(g1-g2)*(g1-g2) + (2+(255.0-redAverage)/256.0)*(b1-b2)*(b1-b2);
	    if ([_bitmapRep hasAlpha]) bitmap1++;
	    if ([imageRep hasAlpha]) bitmap2++;
	    
	    if (matchValue > prevWorst) return;	// the lower the matchValue the better, so if it's already
						//  greater than the previous worst, it's no use going any further
	}

    // now average it per pixel
    matchValue /= [_bitmapRep size].width * [_bitmapRep size].height;
    
    //NSLog(@"   Matches better (%f vs. %f)", matchValue, prevWorst);
    
    newMatch = [[TileMatch alloc] init];
    if (newMatch == nil)
    {
	NSLog(@"Could not allocate new TileMatch");
	return;
    }
    [newMatch setFilePath:filePath];
    [newMatch setBitmapRep:imageRep];
    [newMatch setMatchValue:matchValue];
	
    // Determine where in the list it belongs (the best match should always be at index 0)
    while (index < [_matches count] && [[_matches objectAtIndex:index] matchValue] < matchValue) index++;

    // Add it to the list of matches
    //NSLog(@"    Adding match at index %d", index);
    [_matches insertObject:newMatch atIndex:index];
	
    // Only keep the best MAX_MATCHES matches
    if ([_matches count] == MAX_MATCHES+1)
    {
	[[_matches lastObject] release];
	[_matches removeLastObject];
    }
    
    /*if ([_matches count] == 2)
    {
	newMatch = [_matches objectAtIndex:0];
	newMatch = [_matches objectAtIndex:1];
    }*/
    
    if (index == 0)	// we have a new best match, add this tile to the display queue (if it's not already in it)
    {
	[[_displayUpdateQueue objectAtIndex:0] lock];
	if ([_displayUpdateQueue indexOfObjectIdenticalTo:self] == NSNotFound) [_displayUpdateQueue addObject:self];
	[[_displayUpdateQueue objectAtIndex:0] unlock];
    }
}


- (TileMatch *)bestMatch
{
    return ([_matches count] == 0) ? nil : [_matches objectAtIndex:0];
}


- (void)dealloc
{
    if (_outline != nil) [_outline release];
    if (_bitmapRep != nil) [_bitmapRep release];
    if (_matches != nil) [_matches release];
    if (_displayUpdateQueue != nil) [_displayUpdateQueue release];
    [super dealloc];
}


@end

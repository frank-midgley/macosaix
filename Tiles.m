#import "Tiles.h"
#import "TileMatch.h"

@implementation Tile

- (void)setOutline:(NSBezierPath *)outline
{
    NSBezierPath	*oldOutline;
    
    if (outline != _outline)
    {
	oldOutline = _outline;
	_outline = [outline retain];
	[oldOutline release];
	oldOutline = nil;
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
	oldBitmapRep = nil;
    }
}


- (NSBitmapImageRep *)bitmapRep
{
    return _bitmapRep;
}


- (void)addMatchingFile:(NSString *)filePath withValue:(double)matchValue
{
    TileMatch*		newMatch;
    int			index = 0;
    
    // Don't bother if it's no better than the current 10 best
    if ([_matches count] == 10 && [[_matches lastObject] matchValue] > matchValue) return;
    
    newMatch = [[TileMatch alloc] init];
    if (newMatch == nil)
    {
	NSLog(@"Could not allocate new TileMatch");
	return;
    }
    [newMatch setFilePath:filePath];
    [newMatch setMatchValue:matchValue];
    
    // Determine where in the list it belongs (the best match should always be at index 0)
    while (index < [_matches count] && [[_matches objectAtIndex:index] matchValue] > matchValue) index++;

    [_matches insertObject:newMatch atIndex:index];
    
    // Only keep the best 10 matches
    if ([_matches count] == 11)
	[_matches removeLastObject];
}

@end

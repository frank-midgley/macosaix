#import "TileMatch.h"

@implementation TileMatch

- (id)init
{
    [super init];
    _tileImage = nil;
    _matchValue = WORST_CASE_PIXEL_MATCH;
    return self;
}


- (id)initWithTileImage:(TileImage *)tileImage matchValue:(float)matchValue
{
    [super init];
    _tileImage = [tileImage retain];
    _matchValue = matchValue;
    return self;
}


- (id)initWithCoder:(NSCoder *)coder
{
    [super init];
    _tileImage = [[coder decodeObject] retain];
    _matchValue = [[coder decodeObject] floatValue];
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_tileImage];
    [coder encodeObject:[NSNumber numberWithFloat:_matchValue]];
}


- (void)setTileImage:(TileImage *)tileImage
{
    [_tileImage autorelease];
    _tileImage = [tileImage retain];
}


- (TileImage *)tileImage
{
    return _tileImage;
}


- (void)setMatchValue:(float)matchValue
{
    _matchValue = matchValue;
}


- (float)matchValue
{
    return _matchValue;
}


- (void)dealloc
{
    [_tileImage release];
    [super dealloc];
}


@end

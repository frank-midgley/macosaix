//
//  Tiles.m
//  MacOSaiX
//
//  Created by fmidgley on Mon Apr 11 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import "Tiles.h"

@implementation Tile

- (NSSize)size
{
    return _size;
}

- (void)setSize:(NSSize)size
{
    _size = size;
}

- (NSData *)bitmapData
{
    return _bitmapData;
}

- (void)setBitmapData:(NSData *)data
{
    NSData *oldData;
    
    if (data != _bitmapData)
    {
	oldData = _bitmapData;
	_bitmapData = [data retain];
	[oldData release];
    }
}

@end


@implementation TileCollection

- (id)ZZZcopyWithZone:(NSZone *)zone
{
    id copy = [[[self class] allocWithZone: zone] init];
    
    return copy;
}

- (id) ZZZreplacementObjectForPortCoder: (NSPortCoder*)aCoder
{
    return self;
}

- (void) dealloc
{
    [_tiles release];
    [super dealloc];
}
    
- (void) ZZZencodeWithCoder: (NSCoder*)aCoder
{
    char	isNil = (_tiles == nil ? 1 : 0);

    [aCoder encodeValueOfObjCType: @encode(char) at: &isNil];
    if (isNil == 0)
    {
	unsigned  count = [_tiles count];

	[aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
	if (count > 0)
        {
	    id		a[count];
	    unsigned	i;

	    [_tiles getObjects: a];
	    for (i = 0; i < count; i++)
		[aCoder encodeBycopyObject: a[i]];
        }
    }
}

- (id) ZZZinitWithCoder: (NSCoder*)aCoder
{
    char  isNil;

    [aCoder decodeValueOfObjCType: @encode(char)
                             at: &isNil];
    if (isNil == 0)
    {
	unsigned    count;

	[aCoder decodeValueOfObjCType: @encode(unsigned) at: &count];
	if (count > 0)
	{
	    id            contents[count];
	    unsigned      i;

	    for (i = 0; i < count; i ++)
		contents[i] = [aCoder decodeObject];
	    _tiles = [[NSArray alloc] initWithObjects:contents count:count];
	}
	else
	    _tiles = [NSArray new];
    }
    else
	_tiles = nil;
	
    return self;
}

- (id)init
{
    _tiles = [NSMutableArray arrayWithCapacity:0];
    return self;
}

- (void)addTile:(Tile *)tile
{
    [_tiles addObject:tile];
}

- (int)count
{
    return [_tiles count];
}

- (Tile *)tileAtIndex:(int)index
{
    return [_tiles objectAtIndex:index];
}

@end



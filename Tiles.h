//
//  Tiles.h
//  MacOSaiX
//
//  Created by fmidgley on Mon Apr 11 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface Tile : NSObject <NSCopying>
{
    NSSize	_size;
    NSData	*_bitmapData;
}
- (NSSize)size;
- (void)setSize:(NSSize)size;
- (NSData *)bitmapData;
- (void)setBitmapData:(NSData *)data;
@end


@interface TileCollection : NSObject <NSCopying>
{
  NSMutableArray *_tiles;
}
- (id)init;
- (id)copyWithZone:(NSZone *)zone;
- (void)addTile:(Tile *)tile;
- (int)count;
- (Tile *)tileAtIndex:(int)index;
@end

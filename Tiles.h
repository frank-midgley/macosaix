//
//  Tiles.h
//  MacOSaiX
//
//  Created by fmidgley on Mon Apr 11 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "TileMatch.h"
#import "TileImage.h"

#define TILE_BITMAP_SIZE 16.0

@interface Tile : NSObject <NSCoding>
{
    NSBezierPath	*_outline;		// The shape of this tile
    NSBitmapImageRep	*_bitmapRep;		// The portion of the original image that is in this tile
    NSMutableArray	*_matches;		// Array of TileMatches
    NSLock		*_tileMatchesLock;	// thread safety
    TileMatch		*_displayMatch, *_userMatch;
    float		_bestMatchValue, _displayMatchValue;
    int			_maxMatches;
}

- (void)setTileMatchesLock:(NSLock *)lock;
- (void)setMaxMatches:(int)maxMatches;

- (void)setOutline:(NSBezierPath *)outline;
- (NSBezierPath *)outline;

- (void)setBitmapRep:(NSBitmapImageRep *)data;
- (NSBitmapImageRep *)bitmapRep;

- (float)matchAgainst:(NSBitmapImageRep *)matchRep tileImage:(TileImage *)tileImage
	forDocument:(NSDocument *)document;

- (TileMatch *)bestMatch;
- (float)bestMatchValue;

- (void)setDisplayMatch:(TileMatch *)displayMatch;
- (TileMatch *)displayMatch;
- (float)displayMatchValue;

- (void)setUserMatch:(TileMatch *)userMatch;
- (TileMatch *)userMatch;

- (NSMutableArray *)matches;
- (NSComparisonResult)compareBestMatchValue:(Tile *)otherTile;

@end

//  Created by fmidgley on Mon Apr 11 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "TileImage.h"

#define TILE_BITMAP_SIZE 32.0

typedef struct _TileMatch
{
    float		matchValue;
    TileImage	*tileImage;
} TileMatch;

#define WORST_CASE_PIXEL_MATCH 520200.0

@interface Tile : NSObject
{
    NSBezierPath		*_outline;		// The shape of this tile
	NSMutableSet		*_neighborSet;	// A set containing tiles that are considered neighbors of this tile
    NSBitmapImageRep	*_bitmapRep;		// The portion of the original image that is in this tile
    TileMatch			*_matches;		// Array of TileMatches
    int					_matchCount;
    NSLock				*_tileMatchesLock,	// thread safety
                        *_bestMatchLock;
    TileImage			*_bestMatchTileImage;	// The index in _matches of the best unique match
    TileMatch			*_userChosenImageMatch;	// will be nil if user has not choosen an image
    int					_maxMatches;
    NSDocument			*_document;		// The document this tile is a part of
}

- (void)addNeighbor:(Tile *)neighboringTile;
- (void)removeNeighbor:(Tile *)nonNeighboringTile;
- (NSArray *)neighbors;

- (void)setOutline:(NSBezierPath *)outline;
- (NSBezierPath *)outline;

- (void)setBitmapRep:(NSBitmapImageRep *)data;
- (NSBitmapImageRep *)bitmapRep;

- (void)setDocument:(NSDocument *)document;

- (BOOL)matchAgainstImageRep:(NSBitmapImageRep *)matchRep fromTileImage:(TileImage *)tileImage
				  forDocument:(NSDocument *)document;

- (TileImage *)displayedTileImage;
- (void)calculateBestMatch;

- (void)setUserChosenImageIndex:(TileImage *)userChosenTileImage;
- (TileImage *)userChosenTileImage;

- (TileMatch *)matches;
- (int)matchCount;
- (void)lockMatches;
- (void)unlockMatches;

- (float)matchValueForTileImage:(TileImage *)tileImage;

@end

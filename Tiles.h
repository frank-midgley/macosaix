//  Created by fmidgley on Mon Apr 11 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "TileImage.h"

#define TILE_BITMAP_SIZE 16.0

typedef struct _TileMatch
{
    float	matchValue;
    long	tileImageIndex;
} TileMatch;

#define WORST_CASE_PIXEL_MATCH 520200.0

@interface Tile : NSObject <NSCoding>
{
    NSBezierPath	*_outline;		// The shape of this tile
    NSBitmapImageRep	*_bitmapRep;		// The portion of the original image that is in this tile
    TileMatch		*_matches;		// Array of TileMatches
    int			_matchCount;
    NSLock		*_tileMatchesLock;	// thread safety
    int			_bestUniqueMatchIndex;	// The index in _matches of the best unique match
    TileMatch		*_userChosenImageMatch;	// will be nil if user has not choosen an image
    int			_maxMatches;
    NSDocument		*_document;		// The document this tile is a part of
}

- (void)setMaxMatches:(int)maxMatches;

- (void)setOutline:(NSBezierPath *)outline;
- (NSBezierPath *)outline;

- (void)setBitmapRep:(NSBitmapImageRep *)data;
- (NSBitmapImageRep *)bitmapRep;

- (void)setDocument:(NSDocument *)document;

- (float)matchAgainst:(NSBitmapImageRep *)matchRep tileImage:(TileImage *)tileImage
	  tileImageIndex:(int)tileImageIndex forDocument:(NSDocument *)document;

- (TileMatch *)bestMatch;
- (float)bestMatchValue;
- (TileMatch *)bestUniqueMatch;
- (float)bestUniqueMatchValue;
- (void)setBestUniqueMatchIndex:(int)matchIndex;

- (void)setUserChosenImageIndex:(long)index;
- (long)userChosenImageIndex;

- (TileMatch *)matches;
- (int)matchCount;
- (void)lockMatches;
- (void)unlockMatches;
- (NSComparisonResult)compareBestMatchValue:(Tile *)otherTile;

@end

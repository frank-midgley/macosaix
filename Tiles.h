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

#define TILE_BITMAP_SIZE 16.0
#define TILE_BITMAP_DISPLAY_SIZE 80.0
#define MAX_MATCHES 128

@interface Tile : NSObject
{
    NSBezierPath	*_outline;		// The shape of this tile
    NSBitmapImageRep	*_bitmapRep;		// The portion of the original image that is in this tile
    NSMutableArray	*_matches;		// Array of TileMatches
    TileMatch		*_displayMatch, *_userMatch;
    float		_bestMatchValue, _displayMatchValue;
}

- (id)init;
- (void)setOutline:(NSBezierPath *)outline;
- (NSBezierPath *)outline;
- (void)setBitmapRep:(NSBitmapImageRep *)data;
- (NSBitmapImageRep *)bitmapRep;
- (float)matchAgainst:(NSBitmapImageRep *)matchRep fromURL:(NSURL *)imageURL
	   displayRep:(NSBitmapImageRep *)displayRep maxMatches:(int)maxMatches;
- (TileMatch *)bestMatch;
- (float)bestMatchValue;
- (void)setDisplayMatch:(TileMatch *)displayMatch;
- (TileMatch *)displayMatch;
- (void)setUserMatch:(TileMatch *)userMatch;
- (TileMatch *)userMatch;
- (float)displayMatchValue;
- (NSMutableArray *)matches;
- (NSComparisonResult)compareBestMatchValue:(Tile *)otherTile;
- (void)dealloc;

@end

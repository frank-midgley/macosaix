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

#define TILE_BITMAP_SIZE 32
#define TILE_BITMAP_DISPLAY_SIZE 80

@interface Tile : NSObject
{
    NSBezierPath	*_outline;		// The shape of this tile
    NSBitmapImageRep	*_bitmapRep;		// The portion of the original image that is in this tile
    NSMutableArray	*_matches,		// Array of TileMatches
			*_displayUpdateQueue;	// Queue of tiles to be redrawn in the mosaic image by the display thread
}

- (id)init;
- (void)setDisplayUpdateQueue:(NSMutableArray *)_displayUpdateQueue;
- (void)setOutline:(NSBezierPath *)outline;
- (NSBezierPath *)outline;
- (void)setBitmapRep:(NSBitmapImageRep *)data;
- (NSBitmapImageRep *)bitmapRep;
- (void)matchAgainst:(NSBitmapImageRep *)imageRep fromFile:(NSString *)filePath;
- (TileMatch *)bestMatch;
- (void)dealloc;

@end

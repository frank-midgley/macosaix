//
//  PuzzleTileShapes.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapes.h"

typedef enum
{
	noTab, 
	inwardsTab, 
	outwardsTab
} PuzzleTabType;

@interface MacOSaiXPuzzleTileShapes : NSObject <MacOSaiXTileShapes>
{
	unsigned int	tilesAcross, 
					tilesDown;
}

- (void)setTilesAcross:(unsigned int)count;
- (unsigned int)tilesAcross;

- (void)setTilesDown:(unsigned int)count;
- (unsigned int)tilesDown;

- (NSBezierPath *)puzzlePathWithSize:(NSSize)tileSize
							  topTab:(PuzzleTabType)topTabType 
							 leftTab:(PuzzleTabType)leftTabType 
							rightTab:(PuzzleTabType)rightTabType 
						   bottomTab:(PuzzleTabType)bottomTabType;

@end

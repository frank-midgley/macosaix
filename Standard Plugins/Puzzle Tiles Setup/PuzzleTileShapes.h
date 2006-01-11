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
	noTab = 0, 
	inwardsTab = -1, 
	outwardsTab = 1
} PuzzleTabType;

typedef struct _PuzzlePiece
{
	PuzzleTabType	topTabType,
					leftTabType,
					rightTabType,
					bottomTabType;
	float			topLeftHorizontalCurve,
					topLeftVerticalCurve,
					topRightHorizontalCurve,
					topRightVerticalCurve,
					bottomLeftHorizontalCurve,
					bottomLeftVerticalCurve,
					bottomRightHorizontalCurve,
					bottomRightVerticalCurve;
	BOOL			alignImages;
} PuzzlePiece;


@interface MacOSaiXPuzzleTileShapes : NSObject <MacOSaiXTileShapes>
{
	unsigned int	tilesAcross, 
					tilesDown;
	float			tabbedSidesRatio, 
					curviness;
	BOOL			alignImages;
}

+ (NSBezierPath *)puzzlePathWithSize:(NSSize)tileSize
						  attributes:(PuzzlePiece)attributes;

- (void)setTilesAcross:(unsigned int)count;
- (unsigned int)tilesAcross;

- (void)setTilesDown:(unsigned int)count;
- (unsigned int)tilesDown;

- (void)setTabbedSidesRatio:(float)ratio;
- (float)tabbedSidesRatio;

- (void)setCurviness:(float)value;
- (float)curviness;

- (void)setImagesAligned:(BOOL)flag;
- (BOOL)imagesAligned;

@end

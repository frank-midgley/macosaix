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


@interface MacOSaiXPuzzleTileShape : NSObject <MacOSaiXTileShape>
{
	NSBezierPath	*outline;
}

+ (MacOSaiXPuzzleTileShape *)tileShapeWithBounds:(NSRect)tileBounds
									  topTabType:(PuzzleTabType)topTabType 
									 leftTabType:(PuzzleTabType)leftTabType 
									rightTabType:(PuzzleTabType)rightTabType 
								   bottomTabType:(PuzzleTabType)bottomTabType 
						  topLeftHorizontalCurve:(float)topLeftHorizontalCurve 
							topLeftVerticalCurve:(float)topLeftVerticalCurve 
						 topRightHorizontalCurve:(float)topRightHorizontalCurve 
						   topRightVerticalCurve:(float)topRightVerticalCurve 
					   bottomLeftHorizontalCurve:(float)bottomLeftHorizontalCurve 
						 bottomLeftVerticalCurve:(float)bottomLeftVerticalCurve 
					  bottomRightHorizontalCurve:(float)bottomRightHorizontalCurve 
						bottomRightVerticalCurve:(float)bottomRightVerticalCurve 
									  alignImage:(BOOL)alignImage;

- (id)        initWithBounds:(NSRect)tileBounds
				  topTabType:(PuzzleTabType)topTabType 
				 leftTabType:(PuzzleTabType)leftTabType 
				rightTabType:(PuzzleTabType)rightTabType 
			   bottomTabType:(PuzzleTabType)bottomTabType 
	  topLeftHorizontalCurve:(float)topLeftHorizontalCurve 
		topLeftVerticalCurve:(float)topLeftVerticalCurve 
	 topRightHorizontalCurve:(float)topRightHorizontalCurve 
	   topRightVerticalCurve:(float)topRightVerticalCurve 
   bottomLeftHorizontalCurve:(float)bottomLeftHorizontalCurve 
	 bottomLeftVerticalCurve:(float)bottomLeftVerticalCurve 
  bottomRightHorizontalCurve:(float)bottomRightHorizontalCurve 
	bottomRightVerticalCurve:(float)bottomRightVerticalCurve 
				  alignImage:(BOOL)alignImage;

@end


@interface MacOSaiXPuzzleTileShapes : NSObject <MacOSaiXTileShapes>
{
	NSArray			*tileShapes;
	unsigned int	tilesAcross, 
					tilesDown;
	float			tabbedSidesRatio, 
					curviness;
	BOOL			alignImages;
}

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

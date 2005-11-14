//
//  RectangularTileShapes.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "PuzzleTileShapes.h"
#import "PuzzleTileShapesEditor.h"


@implementation MacOSaiXPuzzleTileShapes


+ (void)initialize
{
		// Seed the random number generator
	srandom(time(NULL));
}


+ (NSString *)name
{
	return @"Puzzle Pieces";
}


+ (Class)editorClass
{
	return [MacOSaiXPuzzleTileShapesEditor class];
}


+ (Class)preferencesControllerClass
{
	return nil;
}


- (id)init
{
	if (self = [super init])
	{
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Puzzle Tile Shapes"];
		int				tilesAcrossPref = [[plugInDefaults objectForKey:@"Tiles Across"] intValue],
						tilesDownPref = [[plugInDefaults objectForKey:@"Tiles Down"] intValue];
		
		[self setTilesAcross:(tilesAcrossPref > 0 ? tilesAcrossPref : 40)];
		[self setTilesDown:(tilesDownPref > 0 ? tilesDownPref : 40)];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXPuzzleTileShapes	*copy = [[MacOSaiXPuzzleTileShapes allocWithZone:zone] init];
	
	[copy setTilesAcross:[self tilesAcross]];
	[copy setTilesDown:[self tilesDown]];
	
	return copy;
}


- (void)setTilesAcross:(unsigned int)count
{
    tilesAcross = count;
}


- (unsigned int)tilesAcross
{
	return tilesAcross;
}


- (void)setTilesDown:(unsigned int)count
{
    tilesDown = count;
}


- (unsigned int)tilesDown
{
	return tilesDown;
}


- (id)briefDescription
{
	return [NSString stringWithFormat:@"%d by %d puzzle pieces", tilesAcross, tilesDown];
}


- (NSString *)settingsAsXMLElement
{
	return [NSString stringWithFormat:@"<DIMENSIONS ACROSS=\"%d\" DOWN=\"%d\"/>", tilesAcross, tilesDown];
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXTileShapesSettingType];
	
	if ([settingType isEqualToString:@"DIMENSIONS"])
	{
		[self setTilesAcross:[[[settingDict objectForKey:@"ACROSS"] description] intValue]];
		[self setTilesDown:[[[settingDict objectForKey:@"DOWN"] description] intValue]];
	}
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	// not needed
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
	// not needed
}


- (NSBezierPath *)puzzlePathWithSize:(NSSize)tileSize
							  topTab:(PuzzleTabType)topTabType 
							 leftTab:(PuzzleTabType)leftTabType 
							rightTab:(PuzzleTabType)rightTabType 
						   bottomTab:(PuzzleTabType)bottomTabType
{
	NSBezierPath	*tileOutline = [NSBezierPath bezierPath];
	float			xSize = tileSize.width,
					ySize = tileSize.height, 
					tabSize = MIN(xSize, ySize) / 3.0;
	int				orientation;
	
		// Add a point at the outward tip of each possible tab so that each tile has 
		// the exact same size and images in adjacent tiles will be aligned, even if 
		// all of a tile's tabs are pointing inwards.
	[tileOutline moveToPoint:NSMakePoint(-tabSize, -tabSize)];
	[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
	[tileOutline moveToPoint:NSMakePoint(-tabSize, ySize + tabSize)];
	[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
	[tileOutline moveToPoint:NSMakePoint(xSize + tabSize, -tabSize)];
	[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
	[tileOutline moveToPoint:NSMakePoint(xSize + tabSize, ySize + tabSize)];
	[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
	
				// Start the real tile outline at the bottom left corner.
	[tileOutline moveToPoint:NSMakePoint(0.0, 0.0)];
	
				// Add the bottom edge.
	if (bottomTabType != noTab)
	{
		orientation = (bottomTabType == inwardsTab) ? 1 : -1;
		[tileOutline lineToPoint:NSMakePoint(xSize / 4,			0.0)];
		[tileOutline curveToPoint:NSMakePoint(xSize * 5 / 12,	tabSize / 2.0 * orientation)
					controlPoint1:NSMakePoint(xSize / 3,		0.0)
					controlPoint2:NSMakePoint(xSize / 2,		tabSize / 4.0 * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize / 2,		tabSize * orientation)
					controlPoint1:NSMakePoint(xSize / 3,		tabSize * 0.75 * orientation)
					controlPoint2:NSMakePoint(xSize * 3 / 8,	tabSize * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize * 7 / 12,	tabSize / 2.0 * orientation)
					controlPoint1:NSMakePoint(xSize * 15 / 24,	tabSize * orientation)
					controlPoint2:NSMakePoint(xSize * 2 / 3,	tabSize * 0.75 * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize * 3 / 4,	0.0)
					controlPoint1:NSMakePoint(xSize / 2,		tabSize / 4.0 * orientation)
					controlPoint2:NSMakePoint(xSize * 2 / 3,	0.0)];
	}
	[tileOutline lineToPoint:NSMakePoint(xSize, 0.0)];
	
		// Add the right edge.
	if (rightTabType != noTab)
	{
		orientation = (rightTabType == inwardsTab) ? -1 : 1;
		[tileOutline lineToPoint:NSMakePoint(xSize,									ySize / 4)];
		[tileOutline curveToPoint:NSMakePoint(xSize + tabSize / 2.0 * orientation,	ySize * 5 / 12)
					controlPoint1:NSMakePoint(xSize,								ySize / 3)
					controlPoint2:NSMakePoint(xSize + tabSize / 4.0 * orientation,	ySize / 2)];
		[tileOutline curveToPoint:NSMakePoint(xSize + tabSize * orientation,		ySize / 2)
					controlPoint1:NSMakePoint(xSize + tabSize * 0.75 * orientation,	ySize / 3)
					controlPoint2:NSMakePoint(xSize + tabSize * orientation,		ySize * 3 / 8)];
		[tileOutline curveToPoint:NSMakePoint(xSize + tabSize / 2.0 * orientation,	ySize * 7 / 12)
					controlPoint1:NSMakePoint(xSize + tabSize * orientation,		ySize * 15 / 24)
					controlPoint2:NSMakePoint(xSize + tabSize * 0.75 * orientation,	ySize * 2 / 3)];
		[tileOutline curveToPoint:NSMakePoint(xSize,								ySize * 3 / 4)
					controlPoint1:NSMakePoint(xSize + tabSize / 4.0 * orientation,	ySize / 2)
					controlPoint2:NSMakePoint(xSize,								ySize * 2 / 3)];
	}
	[tileOutline lineToPoint:NSMakePoint(xSize, ySize)];
	
		// Add the top edge.
	if (topTabType != noTab)
	{
		orientation = (topTabType == inwardsTab) ? -1 : 1;
		[tileOutline lineToPoint:NSMakePoint(xSize * 3 / 4,		ySize)];
		[tileOutline curveToPoint:NSMakePoint(xSize * 7 / 12,	ySize + tabSize / 2.0 * orientation)
					controlPoint1:NSMakePoint(xSize * 2 / 3,	ySize)
					controlPoint2:NSMakePoint(xSize / 2,		ySize + tabSize / 4.0 * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize / 2,		ySize + tabSize * orientation)
					controlPoint1:NSMakePoint(xSize * 2 / 3,	ySize + tabSize * 0.75 * orientation)
					controlPoint2:NSMakePoint(xSize * 15 / 24,	ySize + tabSize * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize * 5 / 12,	ySize + tabSize / 2.0 * orientation)
					controlPoint1:NSMakePoint(xSize * 3 / 8,	ySize + tabSize * orientation)
					controlPoint2:NSMakePoint(xSize / 3,		ySize + tabSize * 0.75 * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize / 4,		ySize)
					controlPoint1:NSMakePoint(xSize / 2,		ySize + tabSize / 4.0 * orientation)
					controlPoint2:NSMakePoint(xSize / 3,		ySize)];
	}
	[tileOutline lineToPoint:NSMakePoint(0.0, ySize)];
	
		// Add the left edge.
	if (leftTabType != noTab)
	{
		orientation = (bottomTabType == inwardsTab) ? 1 : -1;
		[tileOutline lineToPoint:NSMakePoint(0.0,							ySize * 3 / 4)];
		[tileOutline curveToPoint:NSMakePoint(tabSize / 2.0 * orientation,	ySize * 7 / 12)
					controlPoint1:NSMakePoint(0.0,							ySize * 2 / 3)
					controlPoint2:NSMakePoint(tabSize / 4.0 * orientation,	ySize / 2)];
		[tileOutline curveToPoint:NSMakePoint(tabSize * orientation,		ySize / 2)
					controlPoint1:NSMakePoint(tabSize * 0.75 * orientation,	ySize * 2 / 3)
					controlPoint2:NSMakePoint(tabSize * orientation,		ySize * 15 / 24)];
		[tileOutline curveToPoint:NSMakePoint(tabSize / 2.0 * orientation,	ySize * 5 / 12)
					controlPoint1:NSMakePoint(tabSize * orientation,		ySize * 3 / 8)
					controlPoint2:NSMakePoint(tabSize * 0.75 * orientation,	ySize / 3)];
		[tileOutline curveToPoint:NSMakePoint(0.0,							ySize / 4)
					controlPoint1:NSMakePoint(tabSize / 4.0 * orientation,	ySize / 2)
					controlPoint2:NSMakePoint(0.0,							ySize / 3)];
	}
	[tileOutline lineToPoint:NSMakePoint(0.0, 0.0)];

	[tileOutline closePath];
	
	return tileOutline;
}


- (NSArray *)shapes
{
	NSMutableArray	*tileOutlines = [NSMutableArray arrayWithCapacity:(tilesAcross * tilesDown)];

		// Decide which way all of the tabs will point.
	BOOL			tabs[tilesAcross * 2 + 1][tilesDown];
	int				x, y;
	for (x = 0; x < tilesAcross * 2 + 1; x++)
		for (y = 0; y < tilesDown; y++)
			tabs[x][y] = (random() % 2 == 0);
	    
		// Add a bezier path for each puzzle piece.
	float			xSize = 1.0 / tilesAcross, 
					ySize = 1.0 / tilesDown,
					tabSize = MIN(xSize, ySize) / 3.0;
	for (x = 0; x < tilesAcross; x++)
		for (y = 0; y < tilesDown; y++)
		{
			NSBezierPath	*tileOutline = [NSBezierPath bezierPath];
			float			originX = xSize * x, 
							originY = ySize * y;
			int				orientation;
			
				// Add a point at the outward tip of each possible tab so that each tile has 
				// the exact same size and images in adjacent tiles will be aligned, even if 
				// all of a tile's tabs are pointing inwards.
//			[tileOutline moveToPoint:NSMakePoint(originX - tabSize, originY - tabSize)];
//			[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
//			[tileOutline moveToPoint:NSMakePoint(originX - tabSize, originY + tabSize)];
//			[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
//			[tileOutline moveToPoint:NSMakePoint(originX + tabSize, originY - tabSize)];
//			[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
//			[tileOutline moveToPoint:NSMakePoint(originX + tabSize, originY + tabSize)];
//			[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
			
				// Start the real tile outline at the bottom left corner.
			[tileOutline moveToPoint:NSMakePoint(originX, originY)];
			
				// Add the bottom edge.
			if (y > 0)
			{
				orientation = (tabs[x * 2][y - 1] ? 1 : -1);
				[tileOutline lineToPoint:NSMakePoint(originX + xSize / 4, originY)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize * 5 / 12,
													  originY + tabSize / 2.0 * orientation)
							controlPoint1:NSMakePoint(originX + xSize / 3,
													  originY)
							controlPoint2:NSMakePoint(originX + xSize / 2,
													  originY + tabSize / 4.0 * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize / 2,
													  originY + tabSize * orientation)
							controlPoint1:NSMakePoint(originX + xSize / 3,
													  originY + tabSize * 0.75 * orientation)
							controlPoint2:NSMakePoint(originX + xSize * 3 / 8,
													  originY + tabSize * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize * 7 / 12,
													  originY + tabSize / 2.0 * orientation)
							controlPoint1:NSMakePoint(originX + xSize * 15 / 24,
													  originY + tabSize * orientation)
							controlPoint2:NSMakePoint(originX + xSize * 2 / 3,
													  originY + tabSize * 0.75 * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize * 3 / 4,
													  originY)
							controlPoint1:NSMakePoint(originX + xSize / 2,
													  originY + tabSize / 4.0 * orientation)
							controlPoint2:NSMakePoint(originX + xSize * 2 / 3,
													  originY)];
			}
			[tileOutline lineToPoint:NSMakePoint(originX + xSize, originY)];
			
				// Add the right edge.
			if (x < tilesAcross - 1)
			{
				orientation = (tabs[x * 2 + 1][y] ? 1 : -1);
				[tileOutline lineToPoint:NSMakePoint(originX + xSize, originY + ySize / 4)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize + tabSize / 2.0 * orientation,
													  originY + ySize * 5 / 12)
							controlPoint1:NSMakePoint(originX + xSize,
													  originY + ySize / 3)
							controlPoint2:NSMakePoint(originX + xSize + tabSize / 4.0 * orientation,
													  originY + ySize / 2)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize + tabSize * orientation,
													  originY + ySize / 2)
							controlPoint1:NSMakePoint(originX + xSize + tabSize * 0.75 * orientation,
													  originY + ySize / 3)
							controlPoint2:NSMakePoint(originX + xSize + tabSize * orientation,
													  originY + ySize * 3 / 8)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize + tabSize / 2.0 * orientation,
													  originY + ySize * 7 / 12)
							controlPoint1:NSMakePoint(originX + xSize + tabSize * orientation,
													  originY + ySize * 15 / 24)
							controlPoint2:NSMakePoint(originX + xSize + tabSize * 0.75 * orientation,
													  originY + ySize * 2 / 3)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize,
													  originY + ySize * 3 / 4)
							controlPoint1:NSMakePoint(originX + xSize + tabSize / 4.0 * orientation,
													  originY + ySize / 2)
							controlPoint2:NSMakePoint(originX + xSize,
													  originY + ySize * 2 / 3)];
			}
			[tileOutline lineToPoint:NSMakePoint(originX + xSize, originY + ySize)];
			
				// Add the top edge.
			if (y < tilesDown - 1)
			{
				orientation = (tabs[x * 2][y] ? 1 : -1);
				[tileOutline lineToPoint:NSMakePoint(originX + xSize * 3 / 4, originY + ySize)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize * 7 / 12,
													  originY + ySize + tabSize / 2.0 * orientation)
							controlPoint1:NSMakePoint(originX + xSize * 2 / 3,
													  originY + ySize)
							controlPoint2:NSMakePoint(originX + xSize / 2,
													  originY + ySize + tabSize / 4.0 * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize / 2,
													  originY + ySize + tabSize * orientation)
							controlPoint1:NSMakePoint(originX + xSize * 2 / 3,
													  originY + ySize + tabSize * 0.75 * orientation)
							controlPoint2:NSMakePoint(originX + xSize * 15 / 24,
													  originY + ySize + tabSize * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize * 5 / 12,
													  originY + ySize + tabSize / 2.0 * orientation)
							controlPoint1:NSMakePoint(originX + xSize * 3 / 8,
													  originY + ySize + tabSize * orientation)
							controlPoint2:NSMakePoint(originX + xSize / 3,
													  originY + ySize + tabSize * 0.75 * orientation)];
				[tileOutline curveToPoint:NSMakePoint(originX + xSize / 4,
													  originY + ySize)
							controlPoint1:NSMakePoint(originX + xSize / 2,
													  originY + ySize + tabSize / 4.0 * orientation)
							controlPoint2:NSMakePoint(originX + xSize / 3,
													  originY + ySize)];
			}
			[tileOutline lineToPoint:NSMakePoint(originX, originY + ySize)];
			
				// Add the left edge.
			if (x > 0)
			{
				orientation = (tabs[x * 2 - 1][y] ? 1 : -1);
				[tileOutline lineToPoint:NSMakePoint(originX, originY + ySize * 3 / 4)];
				[tileOutline curveToPoint:NSMakePoint(originX + tabSize / 2.0 * orientation,
													  originY + ySize * 7 / 12)
							controlPoint1:NSMakePoint(originX,
													  originY + ySize * 2 / 3)
							controlPoint2:NSMakePoint(originX + tabSize / 4.0 * orientation,
													  originY + ySize / 2)];
				[tileOutline curveToPoint:NSMakePoint(originX + tabSize * orientation,
													  originY + ySize / 2)
							controlPoint1:NSMakePoint(originX + tabSize * 0.75 * orientation,
													  originY + ySize * 2 / 3)
							controlPoint2:NSMakePoint(originX + tabSize * orientation,
													  originY + ySize * 15 / 24)];
				[tileOutline curveToPoint:NSMakePoint(originX + tabSize / 2.0 * orientation,
													  originY + ySize * 5 / 12)
							controlPoint1:NSMakePoint(originX + tabSize * orientation,
													  originY + ySize * 3 / 8)
							controlPoint2:NSMakePoint(originX + tabSize * 0.75 * orientation,
													  originY + ySize / 3)];
				[tileOutline curveToPoint:NSMakePoint(originX,
													  originY + ySize / 4)
							controlPoint1:NSMakePoint(originX + tabSize / 4.0 * orientation,
													  originY + ySize / 2)
							controlPoint2:NSMakePoint(originX,
													  originY + ySize / 3)];
			}
			[tileOutline closePath];
			[tileOutlines addObject:tileOutline];
		}
		
	return [NSArray arrayWithArray:tileOutlines];
}


@end

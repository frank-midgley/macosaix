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
			[tileOutline moveToPoint:NSMakePoint(originX - tabSize, originY - tabSize)];
			[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
			[tileOutline moveToPoint:NSMakePoint(originX - tabSize, originY + tabSize)];
			[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
			[tileOutline moveToPoint:NSMakePoint(originX + tabSize, originY - tabSize)];
			[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
			[tileOutline moveToPoint:NSMakePoint(originX + tabSize, originY + tabSize)];
			[tileOutline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
			
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

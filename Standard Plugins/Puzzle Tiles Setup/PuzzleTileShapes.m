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


+ (NSBezierPath *)puzzlePathWithSize:(NSSize)tileSize
						  attributes:(PuzzlePiece)attributes
{
	NSBezierPath	*tileOutline = [NSBezierPath bezierPath];
	float			xSize = tileSize.width,
					ySize = tileSize.height, 
					tabSize = MIN(xSize, ySize) / 3.0;
	int				orientation;
	
	PuzzlePiece		controlAttributes = attributes;
	controlAttributes.topLeftHorizontalCurve *= tabSize * 0.25;
	controlAttributes.topLeftVerticalCurve *= tabSize * 0.25;
	controlAttributes.topRightHorizontalCurve *= tabSize * 0.25;
	controlAttributes.topRightVerticalCurve *= tabSize * 0.25;
	controlAttributes.bottomLeftHorizontalCurve *= tabSize * 0.25;
	controlAttributes.bottomLeftVerticalCurve *= tabSize * 0.25;
	controlAttributes.bottomRightHorizontalCurve *= tabSize * 0.25;
	controlAttributes.bottomRightVerticalCurve *= tabSize * 0.25;
	
	if (attributes.alignImages)
	{
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
	}
	
		// Start the real tile outline at the bottom left corner.
	[tileOutline moveToPoint:NSMakePoint(0.0, 0.0)];
	
		// Add the bottom edge.
	if (attributes.bottomTabType == noTab)
	{
		[tileOutline curveToPoint:NSMakePoint(xSize, 0.0) 
					controlPoint1:NSMakePoint(xSize / 3,		tabSize * attributes.bottomLeftHorizontalCurve)
					controlPoint2:NSMakePoint(xSize * 2 / 3,	tabSize * attributes.bottomRightHorizontalCurve)];
	}
	else
	{
		orientation = (attributes.bottomTabType == inwardsTab) ? 1 : -1;
		[tileOutline curveToPoint:NSMakePoint(xSize / 4,		0.0) 
					controlPoint1:NSMakePoint(xSize / 12,		controlAttributes.bottomLeftHorizontalCurve)
					controlPoint2:NSMakePoint(xSize / 6,		controlAttributes.bottomLeftHorizontalCurve)];
		[tileOutline curveToPoint:NSMakePoint(xSize * 5 / 12,	tabSize / 2.0 * orientation)
					controlPoint1:NSMakePoint(xSize / 3,		-controlAttributes.bottomLeftHorizontalCurve)
					controlPoint2:NSMakePoint(xSize / 2,		tabSize / 4.0 * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize / 2,		tabSize * orientation)
					controlPoint1:NSMakePoint(xSize / 3,		tabSize * 0.75 * orientation)
					controlPoint2:NSMakePoint(xSize * 3 / 8,	tabSize * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize * 7 / 12,	tabSize / 2.0 * orientation)
					controlPoint1:NSMakePoint(xSize * 15 / 24,	tabSize * orientation)
					controlPoint2:NSMakePoint(xSize * 2 / 3,	tabSize * 0.75 * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize * 3 / 4,	0.0)
					controlPoint1:NSMakePoint(xSize / 2,		tabSize / 4.0 * orientation)
					controlPoint2:NSMakePoint(xSize * 2 / 3,	-controlAttributes.bottomRightHorizontalCurve)];
		[tileOutline curveToPoint:NSMakePoint(xSize,			0.0) 
					controlPoint1:NSMakePoint(xSize * 10 / 12,	controlAttributes.bottomRightHorizontalCurve)
					controlPoint2:NSMakePoint(xSize * 11 / 12,	controlAttributes.bottomRightHorizontalCurve)];
	}
	
		// Add the right edge.
	if (attributes.rightTabType == noTab)
	{
		[tileOutline curveToPoint:NSMakePoint(xSize, ySize) 
					controlPoint1:NSMakePoint(xSize + tabSize * attributes.bottomRightVerticalCurve,	ySize / 3)
					controlPoint2:NSMakePoint(xSize + tabSize * attributes.topRightVerticalCurve,		ySize * 2 / 3)];
	}
	else
	{
		orientation = (attributes.rightTabType == inwardsTab) ? -1 : 1;
		[tileOutline curveToPoint:NSMakePoint(xSize,													ySize / 4)
					controlPoint1:NSMakePoint(xSize + controlAttributes.bottomRightVerticalCurve,		ySize / 12)
					controlPoint2:NSMakePoint(xSize + controlAttributes.bottomRightVerticalCurve,		ySize / 6)];
		[tileOutline curveToPoint:NSMakePoint(xSize + tabSize / 2.0 * orientation,						ySize * 5 / 12)
					controlPoint1:NSMakePoint(xSize - controlAttributes.bottomRightVerticalCurve,		ySize / 3)
					controlPoint2:NSMakePoint(xSize + tabSize / 4.0 * orientation,						ySize / 2)];
		[tileOutline curveToPoint:NSMakePoint(xSize + tabSize * orientation,							ySize / 2)
					controlPoint1:NSMakePoint(xSize + tabSize * 0.75 * orientation,						ySize / 3)
					controlPoint2:NSMakePoint(xSize + tabSize * orientation,							ySize * 3 / 8)];
		[tileOutline curveToPoint:NSMakePoint(xSize + tabSize / 2.0 * orientation,						ySize * 7 / 12)
					controlPoint1:NSMakePoint(xSize + tabSize * orientation,							ySize * 15 / 24)
					controlPoint2:NSMakePoint(xSize + tabSize * 0.75 * orientation,						ySize * 2 / 3)];
		[tileOutline curveToPoint:NSMakePoint(xSize,													ySize * 3 / 4)
					controlPoint1:NSMakePoint(xSize + tabSize / 4.0 * orientation,						ySize / 2)
					controlPoint2:NSMakePoint(xSize - controlAttributes.topRightVerticalCurve,			ySize * 2 / 3)];
		[tileOutline curveToPoint:NSMakePoint(xSize,													ySize)
					controlPoint1:NSMakePoint(xSize + controlAttributes.topRightVerticalCurve,			ySize * 10 / 12)
					controlPoint2:NSMakePoint(xSize + controlAttributes.topRightVerticalCurve,			ySize * 11 / 12)];
	}
	
		// Add the top edge.
	if (attributes.topTabType == noTab)
	{
		[tileOutline curveToPoint:NSMakePoint(0.0, ySize) 
					controlPoint1:NSMakePoint(xSize * 2 / 3,	ySize + tabSize * attributes.topRightHorizontalCurve)
					controlPoint2:NSMakePoint(xSize / 3,		ySize + tabSize * attributes.topLeftHorizontalCurve)];
	}
	else
	{
		orientation = (attributes.topTabType == inwardsTab) ? -1 : 1;
		[tileOutline curveToPoint:NSMakePoint(xSize * 3 / 4,	ySize)
					controlPoint1:NSMakePoint(xSize * 11 / 12,	ySize + controlAttributes.topRightHorizontalCurve)
					controlPoint2:NSMakePoint(xSize * 10 / 12,	ySize + controlAttributes.topRightHorizontalCurve)];
		[tileOutline curveToPoint:NSMakePoint(xSize * 7 / 12,	ySize + tabSize / 2.0 * orientation)
					controlPoint1:NSMakePoint(xSize * 2 / 3,	ySize - controlAttributes.topRightHorizontalCurve)
					controlPoint2:NSMakePoint(xSize / 2,		ySize + tabSize / 4.0 * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize / 2,		ySize + tabSize * orientation)
					controlPoint1:NSMakePoint(xSize * 2 / 3,	ySize + tabSize * 0.75 * orientation)
					controlPoint2:NSMakePoint(xSize * 15 / 24,	ySize + tabSize * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize * 5 / 12,	ySize + tabSize / 2.0 * orientation)
					controlPoint1:NSMakePoint(xSize * 3 / 8,	ySize + tabSize * orientation)
					controlPoint2:NSMakePoint(xSize / 3,		ySize + tabSize * 0.75 * orientation)];
		[tileOutline curveToPoint:NSMakePoint(xSize / 4,		ySize)
					controlPoint1:NSMakePoint(xSize / 2,		ySize + tabSize / 4.0 * orientation)
					controlPoint2:NSMakePoint(xSize / 3,		ySize - controlAttributes.topLeftHorizontalCurve)];
		[tileOutline curveToPoint:NSMakePoint(0.0,				ySize)
					controlPoint1:NSMakePoint(xSize / 6,		ySize + controlAttributes.topLeftHorizontalCurve)
					controlPoint2:NSMakePoint(xSize / 12,		ySize + controlAttributes.topLeftHorizontalCurve)];
	}
	
		// Add the left edge.
	if (attributes.leftTabType == noTab)
	{
		[tileOutline curveToPoint:NSMakePoint(0.0, 0.0) 
					controlPoint1:NSMakePoint(tabSize * attributes.topLeftVerticalCurve,	ySize * 2 / 3)
					controlPoint2:NSMakePoint(tabSize * attributes.bottomLeftVerticalCurve,		ySize / 3)];
	}
	else
	{
		orientation = (attributes.leftTabType == inwardsTab) ? 1 : -1;
		[tileOutline curveToPoint:NSMakePoint(0.0,											ySize * 3 / 4)
					controlPoint1:NSMakePoint(controlAttributes.topLeftVerticalCurve,		ySize * 11 / 12)
					controlPoint2:NSMakePoint(controlAttributes.topLeftVerticalCurve,		ySize * 10 / 12)];
		[tileOutline curveToPoint:NSMakePoint(tabSize / 2.0 * orientation,					ySize * 7 / 12)
					controlPoint1:NSMakePoint(-controlAttributes.topLeftVerticalCurve,		ySize * 2 / 3)
					controlPoint2:NSMakePoint(tabSize / 4.0 * orientation,					ySize / 2)];
		[tileOutline curveToPoint:NSMakePoint(tabSize * orientation,						ySize / 2)
					controlPoint1:NSMakePoint(tabSize * 0.75 * orientation,					ySize * 2 / 3)
					controlPoint2:NSMakePoint(tabSize * orientation,						ySize * 15 / 24)];
		[tileOutline curveToPoint:NSMakePoint(tabSize / 2.0 * orientation,					ySize * 5 / 12)
					controlPoint1:NSMakePoint(tabSize * orientation,						ySize * 3 / 8)
					controlPoint2:NSMakePoint(tabSize * 0.75 * orientation,					ySize / 3)];
		[tileOutline curveToPoint:NSMakePoint(0.0,											ySize / 4)
					controlPoint1:NSMakePoint(tabSize / 4.0 * orientation,					ySize / 2)
					controlPoint2:NSMakePoint(-controlAttributes.bottomLeftVerticalCurve,	ySize / 3)];
		[tileOutline curveToPoint:NSMakePoint(0.0,											0.0)
					controlPoint1:NSMakePoint(controlAttributes.bottomLeftVerticalCurve,	ySize / 6)
					controlPoint2:NSMakePoint(controlAttributes.bottomLeftVerticalCurve,	ySize / 12)];
	}
	
	[tileOutline closePath];
	
	//	Add the bits that make the Tile Shapes toolbar icon.
	//	[tileOutline appendBezierPathWithOvalInRect:NSMakeRect(xSize * 0.15, ySize * 0.2, xSize * 0.2, xSize * 0.2)];
	//	[tileOutline moveToPoint:NSMakePoint(xSize * 0.45, ySize * 0.3)];
	//	[tileOutline lineToPoint:NSMakePoint(xSize * 0.85, ySize * 0.3)];
	//	[tileOutline appendBezierPathWithOvalInRect:NSMakeRect(xSize * 0.15, ySize * 0.6, xSize * 0.2, xSize * 0.2)];
	//	[tileOutline moveToPoint:NSMakePoint(xSize * 0.45, ySize * 0.7)];
	//	[tileOutline lineToPoint:NSMakePoint(xSize * 0.85, ySize * 0.7)];
	
	return tileOutline;
}


+ (NSImage *)image
{
	static	NSImage	*image = nil;
	
	if (!image)
	{
		PuzzlePiece			piece;
		piece.topTabType = inwardsTab;
		piece.leftTabType = inwardsTab;
		piece.rightTabType = outwardsTab;
		piece.bottomTabType = outwardsTab;
		piece.topLeftHorizontalCurve = 0.0;
		piece.topLeftVerticalCurve = 0.0;
		piece.topRightHorizontalCurve = 0.0;
		piece.topRightVerticalCurve = 0.0;
		piece.bottomLeftHorizontalCurve = 0.0;
		piece.bottomLeftVerticalCurve = 0.0;
		piece.bottomRightHorizontalCurve = 0.0;
		piece.bottomRightVerticalCurve = 0.0;
		piece.alignImages = NO;
		NSBezierPath		*tileOutline = [self puzzlePathWithSize:NSMakeSize(22.0, 22.0) attributes:piece];
		
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform translateXBy:3.0 yBy:7.0];
		
		image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
		[image lockFocus];
			tileOutline = [transform transformBezierPath:tileOutline];
			[[NSColor lightGrayColor] set];
			[tileOutline fill];
			
			transform = [NSAffineTransform transform];
			[transform translateXBy:-1.0 yBy:1.0];
			tileOutline = [transform transformBezierPath:tileOutline];
			[[NSColor whiteColor] set];
			[tileOutline fill];
			[[NSColor blackColor] set];
			[tileOutline stroke];
		[image unlockFocus];
	}
	
	return image;
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
		float			tabbedSidesPref = [[plugInDefaults objectForKey:@"Tabbed Sides Percentage"] floatValue] / 100.0,
						curvinessPref = [[plugInDefaults objectForKey:@"Curviness Percentage"] floatValue] / 100.0;

		[self setTilesAcross:MIN(MAX(10, tilesAcrossPref), 200)];
		[self setTilesDown:MIN(MAX(10, tilesDownPref), 200)];
		[self setTabbedSidesRatio:MIN(MAX(0.0, tabbedSidesPref), 1.0)];
		[self setCurviness:MIN(MAX(0.0, curvinessPref), 1.0)];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXPuzzleTileShapes	*copy = [[MacOSaiXPuzzleTileShapes allocWithZone:zone] init];
	
	[copy setTilesAcross:[self tilesAcross]];
	[copy setTilesDown:[self tilesDown]];
	[copy setTabbedSidesRatio:[self tabbedSidesRatio]];
	[copy setCurviness:[self curviness]];
	[copy setImagesAligned:[self imagesAligned]];
	
	return copy;
}


- (NSImage *)image
{
	PuzzlePiece			piece;
	piece.topTabType = outwardsTab;
	piece.leftTabType = inwardsTab;
	piece.rightTabType = inwardsTab;
	piece.bottomTabType = outwardsTab;
	piece.topLeftHorizontalCurve = 0.0;
	piece.topLeftVerticalCurve = 0.0;
	piece.topRightHorizontalCurve = 0.0;
	piece.topRightVerticalCurve = 0.0;
	piece.bottomLeftHorizontalCurve = 0.0;
	piece.bottomLeftVerticalCurve = 0.0;
	piece.bottomRightHorizontalCurve = 0.0;
	piece.bottomRightVerticalCurve = 0.0;
	piece.alignImages = YES;
	NSBezierPath		*tileOutline = [[self class] puzzlePathWithSize:NSMakeSize(25.0, 19.0) attributes:piece];
	
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:4.5 yBy:5.5];
	NSImage				*image = [[[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)] autorelease];
	NSDictionary		*attributes = [NSDictionary dictionaryWithObject:[NSFont boldSystemFontOfSize:7.0] 
																  forKey:NSFontAttributeName];
	
	[image lockFocus];
		tileOutline = [transform transformBezierPath:tileOutline];
		[[NSColor lightGrayColor] set];
		[tileOutline fill];
		
		transform = [NSAffineTransform transform];
		[transform translateXBy:-1.0 yBy:1.0];
		tileOutline = [transform transformBezierPath:tileOutline];
		[[NSColor whiteColor] set];
		[tileOutline fill];
		[[NSColor blackColor] set];
		[tileOutline stroke];
		
		NSString	*string = [NSString stringWithFormat:@"%d", tilesAcross];
		NSSize		stringSize = [string sizeWithAttributes:attributes];
		[string drawAtPoint:NSMakePoint(16.0 - stringSize.width / 2.0, 
										32.0 - stringSize.height - 6.0) 
			 withAttributes:attributes];
		string = [NSString stringWithFormat:@"%d", tilesDown];
		stringSize = [string sizeWithAttributes:attributes];
		[string drawAtPoint:NSMakePoint(16.0 - stringSize.width / 2.0, 6.0) 
			 withAttributes:attributes];
		
		[NSBezierPath strokeLineFromPoint:NSMakePoint(16.0 - 2.0, 16.0 - 2.0) 
								  toPoint:NSMakePoint(16.0 + 2.0, 16.0 + 2.0)];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(16.0 - 2.0, 16.0 + 2.0) 
								  toPoint:NSMakePoint(16.0 + 2.0, 16.0 - 2.0)];
	[image unlockFocus];
	
	return image;
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


- (void)setTabbedSidesRatio:(float)ratio
{
	tabbedSidesRatio = ratio;
}


- (float)tabbedSidesRatio
{
	return tabbedSidesRatio;
}


- (void)setCurviness:(float)value
{
	curviness = value;
}


- (float)curviness
{
	return curviness;
}


- (void)setImagesAligned:(BOOL)flag
{
	alignImages = flag;
}


- (BOOL)imagesAligned
{
	return alignImages;
}


- (id)briefDescription
{
	return [NSString stringWithFormat:@"%d by %d puzzle pieces\n%.0f%% tabbed sides\n%.0f%% curviness", 
									  tilesAcross, tilesDown, tabbedSidesRatio * 100.0, curviness * 100.0];
}


- (NSString *)settingsAsXMLElement
{
	return [NSString stringWithFormat:@"<DIMENSIONS ACROSS=\"%d\" DOWN=\"%d\"/>\n" \
									  @"<ATTRIBUTES TABBED_SIDES=\"%.3f\" CURVINESS=\"%.3f\" ALIGN_IMAGES=\"%@\"/>", 
									  tilesAcross, tilesDown, tabbedSidesRatio, curviness, (alignImages ? @"YES" : @"NO")];
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXTileShapesSettingType];
	
	if ([settingType isEqualToString:@"DIMENSIONS"])
	{
		[self setTilesAcross:[[[settingDict objectForKey:@"ACROSS"] description] intValue]];
		[self setTilesDown:[[[settingDict objectForKey:@"DOWN"] description] intValue]];
	}
	if ([settingType isEqualToString:@"ATTRIBUTES"])
	{
		[self setTabbedSidesRatio:[[settingDict objectForKey:@"TABBED_SIDES"] floatValue]];
		[self setCurviness:[[settingDict objectForKey:@"CURVINESS"] floatValue]];
		[self setImagesAligned:([[settingDict objectForKey:@"ALIGN_IMAGES"] isEqualToString:@"YES"])];
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
	PuzzleTabType	tabTypes[tilesAcross * 2 + 1][tilesDown];
	int				x, y;
	for (x = 0; x < tilesAcross * 2 + 1; x++)
		for (y = 0; y < tilesDown; y++)
		{
			if (random() % 100 >= tabbedSidesRatio * 100.0)
				tabTypes[x][y] = noTab;
			else
				tabTypes[x][y] = (random() % 2 == 0 ? inwardsTab : outwardsTab);
		}
	
		// Decide the curviness of the sides
	float			horizontalCurviness[tilesAcross + 1][tilesDown + 1],
					verticalCurviness[tilesAcross + 1][tilesDown + 1];
	for (x = 0; x < tilesAcross + 1; x++)
		for (y = 0; y < tilesDown + 1; y++)
		{
			horizontalCurviness[x][y] = (y == 0 || y == tilesDown) ? 0.0 : (random() % 200 - 100) / 100.0 * curviness;
			verticalCurviness[x][y] = (x == 0 || x == tilesAcross) ? 0.0 : (random() % 200 - 100) / 100.0 * curviness;
		}
	
		// Add a bezier path for each puzzle piece.
	float			xSize = 1.0 / tilesAcross, 
					ySize = 1.0 / tilesDown;
	for (x = 0; x < tilesAcross; x++)
		for (y = 0; y < tilesDown; y++)
		{
				// Set the attributes of this piece.
			PuzzlePiece			piece;
			piece.topTabType = (y == tilesDown - 1 ? noTab : tabTypes[x * 2][y]);
			piece.leftTabType = (x == 0 ? noTab : tabTypes[x * 2 - 1][y]);
			piece.rightTabType = (x == tilesAcross - 1 ? noTab : -tabTypes[x * 2 + 1][y]);
			piece.bottomTabType = (y == 0 ? noTab : -tabTypes[x * 2][y - 1]);
			piece.topLeftHorizontalCurve = horizontalCurviness[x][y + 1];
			piece.topLeftVerticalCurve = -verticalCurviness[x][y + 1];
			piece.topRightHorizontalCurve = -horizontalCurviness[x + 1][y + 1];
			piece.topRightVerticalCurve = -verticalCurviness[x + 1][y + 1];
			piece.bottomLeftHorizontalCurve = horizontalCurviness[x][y];
			piece.bottomLeftVerticalCurve = verticalCurviness[x][y];
			piece.bottomRightHorizontalCurve = -horizontalCurviness[x + 1][y];
			piece.bottomRightVerticalCurve = verticalCurviness[x + 1][y];
			piece.alignImages = alignImages;
			
				// Create the outline of this piece and move it to the right place.
			NSBezierPath		*tileOutline = [[self class] puzzlePathWithSize:NSMakeSize(xSize, ySize) attributes:piece];
			NSAffineTransform	*transform = [NSAffineTransform transform];
			[transform translateXBy:xSize * x yBy:ySize * y];
			[tileOutline transformUsingAffineTransform:transform];
			
				// Add this piece to the list.
			[tileOutlines addObject:tileOutline];
		}
		
	return [NSArray arrayWithArray:tileOutlines];
}


@end

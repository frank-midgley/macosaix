//
//  RectangularTileShapes.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "PuzzleTileShapes.h"
#import "PuzzleTileShapesEditor.h"


@implementation MacOSaiXPuzzleTileShape


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
									alignImage:(BOOL)alignImage 
{
	return [[[self alloc] initWithBounds:tileBounds
							  topTabType:topTabType 
							 leftTabType:leftTabType 
							rightTabType:rightTabType 
						   bottomTabType:bottomTabType 
				  topLeftHorizontalCurve:topLeftHorizontalCurve 
					topLeftVerticalCurve:topLeftVerticalCurve 
				 topRightHorizontalCurve:topRightHorizontalCurve 
				   topRightVerticalCurve:topRightVerticalCurve 
			   bottomLeftHorizontalCurve:bottomLeftHorizontalCurve 
				 bottomLeftVerticalCurve:bottomLeftVerticalCurve 
			  bottomRightHorizontalCurve:bottomRightHorizontalCurve 
				bottomRightVerticalCurve:bottomRightVerticalCurve 
							  alignImage:alignImage] autorelease];
}


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
				  alignImage:(BOOL)alignImage 
{
	if (self = [super init])
	{
		outline = [[NSBezierPath bezierPath] retain];
		
		float	xSize = NSWidth(tileBounds),
				ySize = NSHeight(tileBounds), 
				tabSize = MIN(xSize, ySize) / 3.0;
		int		tabOrientation;
		
			// Pre-calculate the dimensions used for the tab curve control points.
		float	controlTopLeftHorizontalCurve = topLeftHorizontalCurve * tabSize * 0.25, 
				controlTopLeftVerticalCurve = topLeftVerticalCurve * tabSize * 0.25, 
				controlTopRightHorizontalCurve = topRightHorizontalCurve * tabSize * 0.25, 
				controlTopRightVerticalCurve = topRightVerticalCurve * tabSize * 0.25, 
				controlBottomLeftHorizontalCurve = bottomLeftHorizontalCurve * tabSize * 0.25, 
				controlBottomLeftVerticalCurve = bottomLeftVerticalCurve * tabSize * 0.25, 
				controlBottomRightHorizontalCurve = bottomRightHorizontalCurve * tabSize * 0.25, 
				controlBottomRightVerticalCurve = bottomRightVerticalCurve * tabSize * 0.25;
		
		if (alignImage)
		{
			// Add a point at the outward tip of each possible tab so that each tile has the exact same size and images in adjacent tiles will be aligned, even if  all of a tile's tabs are pointing inwards.
			[outline moveToPoint:NSMakePoint(-tabSize, -tabSize)];
			[outline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
			[outline moveToPoint:NSMakePoint(-tabSize, ySize + tabSize)];
			[outline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
			[outline moveToPoint:NSMakePoint(xSize + tabSize, -tabSize)];
			[outline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
			[outline moveToPoint:NSMakePoint(xSize + tabSize, ySize + tabSize)];
			[outline relativeLineToPoint:NSMakePoint(0.0, 0.0)];
		}
		
			// Start the real tile outline at the bottom left corner.
		[outline moveToPoint:NSMakePoint(0.0, 0.0)];
		
			// Add the bottom edge.
		if (bottomTabType == noTab)
		{
			[outline curveToPoint:NSMakePoint(xSize, 0.0) 
					controlPoint1:NSMakePoint(xSize / 3,		tabSize * bottomLeftHorizontalCurve)
					controlPoint2:NSMakePoint(xSize * 2 / 3,	tabSize * bottomRightHorizontalCurve)];
		}
		else
		{
			tabOrientation = (bottomTabType == inwardsTab) ? 1 : -1;
			[outline curveToPoint:NSMakePoint(xSize / 4,		0.0) 
					controlPoint1:NSMakePoint(xSize / 12,		controlBottomLeftHorizontalCurve)
					controlPoint2:NSMakePoint(xSize / 6,		controlBottomLeftHorizontalCurve)];
			[outline curveToPoint:NSMakePoint(xSize * 5 / 12,	tabSize / 2.0 * tabOrientation)
					controlPoint1:NSMakePoint(xSize / 3,		-controlBottomLeftHorizontalCurve)
					controlPoint2:NSMakePoint(xSize / 2,		tabSize / 4.0 * tabOrientation)];
			[outline curveToPoint:NSMakePoint(xSize / 2,		tabSize * tabOrientation)
					controlPoint1:NSMakePoint(xSize / 3,		tabSize * 0.75 * tabOrientation)
					controlPoint2:NSMakePoint(xSize * 3 / 8,	tabSize * tabOrientation)];
			[outline curveToPoint:NSMakePoint(xSize * 7 / 12,	tabSize / 2.0 * tabOrientation)
					controlPoint1:NSMakePoint(xSize * 15 / 24,	tabSize * tabOrientation)
					controlPoint2:NSMakePoint(xSize * 2 / 3,	tabSize * 0.75 * tabOrientation)];
			[outline curveToPoint:NSMakePoint(xSize * 3 / 4,	0.0)
					controlPoint1:NSMakePoint(xSize / 2,		tabSize / 4.0 * tabOrientation)
					controlPoint2:NSMakePoint(xSize * 2 / 3,	-controlBottomRightHorizontalCurve)];
			[outline curveToPoint:NSMakePoint(xSize,			0.0) 
					controlPoint1:NSMakePoint(xSize * 10 / 12,	controlBottomRightHorizontalCurve)
					controlPoint2:NSMakePoint(xSize * 11 / 12,	controlBottomRightHorizontalCurve)];
		}
		
			// Add the right edge.
		if (rightTabType == noTab)
		{
			[outline curveToPoint:NSMakePoint(xSize, ySize) 
					controlPoint1:NSMakePoint(xSize + tabSize * bottomRightVerticalCurve,	ySize / 3)
					controlPoint2:NSMakePoint(xSize + tabSize * topRightVerticalCurve,		ySize * 2 / 3)];
		}
		else
		{
			tabOrientation = (rightTabType == inwardsTab) ? -1 : 1;
			[outline curveToPoint:NSMakePoint(xSize,										ySize / 4)
					controlPoint1:NSMakePoint(xSize + controlBottomRightVerticalCurve,		ySize / 12)
					controlPoint2:NSMakePoint(xSize + controlBottomRightVerticalCurve,		ySize / 6)];
			[outline curveToPoint:NSMakePoint(xSize + tabSize / 2.0 * tabOrientation,		ySize * 5 / 12)
					controlPoint1:NSMakePoint(xSize - controlBottomRightVerticalCurve,		ySize / 3)
					controlPoint2:NSMakePoint(xSize + tabSize / 4.0 * tabOrientation,		ySize / 2)];
			[outline curveToPoint:NSMakePoint(xSize + tabSize * tabOrientation,				ySize / 2)
					controlPoint1:NSMakePoint(xSize + tabSize * 0.75 * tabOrientation,		ySize / 3)
					controlPoint2:NSMakePoint(xSize + tabSize * tabOrientation,				ySize * 3 / 8)];
			[outline curveToPoint:NSMakePoint(xSize + tabSize / 2.0 * tabOrientation,		ySize * 7 / 12)
					controlPoint1:NSMakePoint(xSize + tabSize * tabOrientation,				ySize * 15 / 24)
					controlPoint2:NSMakePoint(xSize + tabSize * 0.75 * tabOrientation,		ySize * 2 / 3)];
			[outline curveToPoint:NSMakePoint(xSize,										ySize * 3 / 4)
					controlPoint1:NSMakePoint(xSize + tabSize / 4.0 * tabOrientation,		ySize / 2)
					controlPoint2:NSMakePoint(xSize - controlTopRightVerticalCurve,			ySize * 2 / 3)];
			[outline curveToPoint:NSMakePoint(xSize,										ySize)
					controlPoint1:NSMakePoint(xSize + controlTopRightVerticalCurve,			ySize * 10 / 12)
					controlPoint2:NSMakePoint(xSize + controlTopRightVerticalCurve,			ySize * 11 / 12)];
		}
		
			// Add the top edge.
		if (topTabType == noTab)
		{
			[outline curveToPoint:NSMakePoint(0.0, ySize) 
					controlPoint1:NSMakePoint(xSize * 2 / 3,	ySize + tabSize * topRightHorizontalCurve)
					controlPoint2:NSMakePoint(xSize / 3,		ySize + tabSize * topLeftHorizontalCurve)];
		}
		else
		{
			tabOrientation = (topTabType == inwardsTab) ? -1 : 1;
			[outline curveToPoint:NSMakePoint(xSize * 3 / 4,	ySize)
					controlPoint1:NSMakePoint(xSize * 11 / 12,	ySize + controlTopRightHorizontalCurve)
					controlPoint2:NSMakePoint(xSize * 10 / 12,	ySize + controlTopRightHorizontalCurve)];
			[outline curveToPoint:NSMakePoint(xSize * 7 / 12,	ySize + tabSize / 2.0 * tabOrientation)
					controlPoint1:NSMakePoint(xSize * 2 / 3,	ySize - controlTopRightHorizontalCurve)
					controlPoint2:NSMakePoint(xSize / 2,		ySize + tabSize / 4.0 * tabOrientation)];
			[outline curveToPoint:NSMakePoint(xSize / 2,		ySize + tabSize * tabOrientation)
					controlPoint1:NSMakePoint(xSize * 2 / 3,	ySize + tabSize * 0.75 * tabOrientation)
					controlPoint2:NSMakePoint(xSize * 15 / 24,	ySize + tabSize * tabOrientation)];
			[outline curveToPoint:NSMakePoint(xSize * 5 / 12,	ySize + tabSize / 2.0 * tabOrientation)
					controlPoint1:NSMakePoint(xSize * 3 / 8,	ySize + tabSize * tabOrientation)
					controlPoint2:NSMakePoint(xSize / 3,		ySize + tabSize * 0.75 * tabOrientation)];
			[outline curveToPoint:NSMakePoint(xSize / 4,		ySize)
					controlPoint1:NSMakePoint(xSize / 2,		ySize + tabSize / 4.0 * tabOrientation)
					controlPoint2:NSMakePoint(xSize / 3,		ySize - controlTopLeftHorizontalCurve)];
			[outline curveToPoint:NSMakePoint(0.0,				ySize)
					controlPoint1:NSMakePoint(xSize / 6,		ySize + controlTopLeftHorizontalCurve)
					controlPoint2:NSMakePoint(xSize / 12,		ySize + controlTopLeftHorizontalCurve)];
		}
		
			// Add the left edge.
		if (leftTabType == noTab)
		{
			[outline curveToPoint:NSMakePoint(0.0, 0.0) 
					controlPoint1:NSMakePoint(tabSize * topLeftVerticalCurve,	ySize * 2 / 3)
					controlPoint2:NSMakePoint(tabSize * bottomLeftVerticalCurve,		ySize / 3)];
		}
		else
		{
			tabOrientation = (leftTabType == inwardsTab) ? 1 : -1;
			[outline curveToPoint:NSMakePoint(0.0,								ySize * 3 / 4)
					controlPoint1:NSMakePoint(controlTopLeftVerticalCurve,		ySize * 11 / 12)
					controlPoint2:NSMakePoint(controlTopLeftVerticalCurve,		ySize * 10 / 12)];
			[outline curveToPoint:NSMakePoint(tabSize / 2.0 * tabOrientation,	ySize * 7 / 12)
					controlPoint1:NSMakePoint(-controlTopLeftVerticalCurve,		ySize * 2 / 3)
					controlPoint2:NSMakePoint(tabSize / 4.0 * tabOrientation,	ySize / 2)];
			[outline curveToPoint:NSMakePoint(tabSize * tabOrientation,			ySize / 2)
					controlPoint1:NSMakePoint(tabSize * 0.75 * tabOrientation,	ySize * 2 / 3)
					controlPoint2:NSMakePoint(tabSize * tabOrientation,			ySize * 15 / 24)];
			[outline curveToPoint:NSMakePoint(tabSize / 2.0 * tabOrientation,	ySize * 5 / 12)
					controlPoint1:NSMakePoint(tabSize * tabOrientation,			ySize * 3 / 8)
					controlPoint2:NSMakePoint(tabSize * 0.75 * tabOrientation,	ySize / 3)];
			[outline curveToPoint:NSMakePoint(0.0,								ySize / 4)
					controlPoint1:NSMakePoint(tabSize / 4.0 * tabOrientation,	ySize / 2)
					controlPoint2:NSMakePoint(-controlBottomLeftVerticalCurve,	ySize / 3)];
			[outline curveToPoint:NSMakePoint(0.0,								0.0)
					controlPoint1:NSMakePoint(controlBottomLeftVerticalCurve,	ySize / 6)
					controlPoint2:NSMakePoint(controlBottomLeftVerticalCurve,	ySize / 12)];
		}
		
		[outline closePath];
		
		//	Add the bits that make the Tile Shapes toolbar icon.
		//	[outline appendBezierPathWithOvalInRect:NSMakeRect(xSize * 0.15, ySize * 0.2, xSize * 0.2, xSize * 0.2)];
		//	[outline moveToPoint:NSMakePoint(xSize * 0.45, ySize * 0.3)];
		//	[outline lineToPoint:NSMakePoint(xSize * 0.85, ySize * 0.3)];
		//	[outline appendBezierPathWithOvalInRect:NSMakeRect(xSize * 0.15, ySize * 0.6, xSize * 0.2, xSize * 0.2)];
		//	[outline moveToPoint:NSMakePoint(xSize * 0.45, ySize * 0.7)];
		//	[outline lineToPoint:NSMakePoint(xSize * 0.85, ySize * 0.7)];
		
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform translateXBy:NSMinX(tileBounds) yBy:NSMinY(tileBounds)];
		[outline transformUsingAffineTransform:transform];
	}
	
	return self;
}


- (NSBezierPath *)outline
{
	return outline;
}


- (NSNumber *)imageOrientation
{
	return nil;
}


- (void)dealloc
{
	[outline release];
	
	[super dealloc];
}


@end


@implementation MacOSaiXPuzzleTileShapes


+ (void)initialize
{
		// Seed the random number generator
	srandom(time(NULL));
}


- (id)init
{
	if (self = [super init])
	{
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Puzzle Tile Shapes"];

		[self setTilesAcross:[[plugInDefaults objectForKey:@"Tiles Across"] intValue]];
		[self setTilesDown:[[plugInDefaults objectForKey:@"Tiles Down"] intValue]];
		[self setTabbedSidesRatio:[[plugInDefaults objectForKey:@"Tabbed Sides Percentage"] floatValue] / 100.0];
		[self setCurviness:[[plugInDefaults objectForKey:@"Curviness Percentage"] floatValue] / 100.0];
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


- (NSImage *)image
{
	MacOSaiXPuzzleTileShape	*tileShape = [MacOSaiXPuzzleTileShape tileShapeWithBounds:NSMakeRect(0.0, 0.0, 25.0, 19.0) 
																		   topTabType:outwardsTab 
																		  leftTabType:inwardsTab 
																		 rightTabType:inwardsTab 
																		bottomTabType:outwardsTab 
															   topLeftHorizontalCurve:0.0 
																 topLeftVerticalCurve:0.0 
															  topRightHorizontalCurve:0.0 
																topRightVerticalCurve:0.0 
															bottomLeftHorizontalCurve:0.0 
															  bottomLeftVerticalCurve:0.0 
														   bottomRightHorizontalCurve:0.0 
															 bottomRightVerticalCurve:0.0 
																		   alignImage:YES];
	NSBezierPath			*tileOutline = [tileShape outline];
	
	NSAffineTransform		*transform = [NSAffineTransform transform];
	[transform translateXBy:4.5 yBy:5.5];
	NSImage					*image = [[[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)] autorelease];
	NSDictionary			*attributes = [NSDictionary dictionaryWithObject:[NSFont boldSystemFontOfSize:7.0] 
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


- (BOOL)isFixedSize
{
	return isFixedSize;
}


- (void)setTilesAcross:(unsigned int)count
{
	if (isFixedSize || tilesAcross != count)
	{
		isFixedSize = NO;
		
		tilesAcross = MIN(MAX(10, count), 200);
		
		[tileShapes release];
		tileShapes = nil;
	}
}


- (unsigned int)tilesAcross
{
	return tilesAcross;
}


- (void)setTilesDown:(unsigned int)count
{
	if (isFixedSize || tilesDown != count)
	{
		isFixedSize = NO;
		
		tilesDown = MIN(MAX(10, count), 200);
		
		[tileShapes release];
		tileShapes = nil;
	}
}


- (unsigned int)tilesDown
{
	return tilesDown;
}


- (void)setTileAspectRatio:(float)ratio
{
	if (!isFixedSize || tileAspectRatio != ratio)
	{
		isFixedSize = YES;
		
		tileAspectRatio = ratio;
		
		[tileShapes release];
		tileShapes = nil;
	}
}


- (float)tileAspectRatio
{
	return tileAspectRatio;
}


- (void)setTileCountFraction:(float)fraction
{
	if (!isFixedSize || tileCountFraction != fraction)
	{
		isFixedSize = YES;
		
		tileCountFraction = fraction;
		
		[tileShapes release];
		tileShapes = nil;
	}
}


- (float)tileCountFraction
{
	return tileCountFraction;
}


- (void)setTabbedSidesRatio:(float)ratio
{
	if (tabbedSidesRatio != ratio)
	{
		tabbedSidesRatio = MIN(MAX(0.0, ratio), 1.0);
		
		[tileShapes release];
		tileShapes = nil;
	}
}


- (float)tabbedSidesRatio
{
	return tabbedSidesRatio;
}


- (void)setCurviness:(float)value
{
	if (curviness != value)
	{
		curviness = MIN(MAX(0.0, value), 1.0);
		
		[tileShapes release];
		tileShapes = nil;
	}
}


- (float)curviness
{
	return curviness;
}


- (void)setImagesAligned:(BOOL)flag
{
	alignImages = flag;
	
	[tileShapes release];
	tileShapes = nil;
}


- (BOOL)imagesAligned
{
	return alignImages;
}


- (id)briefDescription
{
	return [NSString stringWithFormat:NSLocalizedString(@"%d by %d puzzle pieces\n%.0f%% tabbed sides\n%.0f%% curviness", @""), 
									  tilesAcross, tilesDown, tabbedSidesRatio * 100.0, curviness * 100.0];
}


- (BOOL)settingsAreValid
{
	return YES;
}


+ (NSString *)settingsExtension
{
	return @"plist";
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	NSMutableDictionary	*settings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:isFixedSize], @"Fixed Size Pieces", 
										[NSNumber numberWithFloat:tabbedSidesRatio * 100.0], @"Tabbed Sides", 
										[NSNumber numberWithFloat:curviness * 100.0], @"Curviness", 
										[NSNumber numberWithBool:alignImages], @"Align Images", 
										nil];
	
	if (isFixedSize)
	{
		[settings setObject:[NSNumber numberWithFloat:tileAspectRatio] forKey:@"Tile Aspect Ratio"];
		[settings setObject:[NSNumber numberWithFloat:tileCountFraction] forKey:@"Tile Count"];
	}
	else
	{
		[settings setObject:[NSNumber numberWithInt:tilesAcross] forKey:@"Tiles Across"];
		[settings setObject:[NSNumber numberWithInt:tilesDown] forKey:@"Tiles Down"];
	}

	return [settings writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	if ([[settings objectForKey:@"Fixed Size Pieces"] boolValue])
	{
		[self setTileAspectRatio:[[settings objectForKey:@"Tile Aspect Ratio"] floatValue]];
		[self setTileCountFraction:[[settings objectForKey:@"Tile Count"] floatValue]];
	}
	else
	{
		[self setTilesAcross:[[settings objectForKey:@"Tiles Across"] intValue]];
		[self setTilesDown:[[settings objectForKey:@"Tiles Down"] intValue]];
	}
	
	[self setTabbedSidesRatio:[[settings objectForKey:@"Tabbed Sides"] floatValue] / 100.0];
	[self setCurviness:[[settings objectForKey:@"Curviness"] floatValue] / 100.0];
	[self setImagesAligned:[[settings objectForKey:@"Align Images"] boolValue]];
	
	return YES;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:@"Element Type"];
	
	if ([settingType isEqualToString:@"DIMENSIONS"])
	{
		[self setTilesAcross:[[[settingDict objectForKey:@"ACROSS"] description] intValue]];
		[self setTilesDown:[[[settingDict objectForKey:@"DOWN"] description] intValue]];
	}
	if ([settingType isEqualToString:@"ATTRIBUTES"])
	{
		// TODO
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


- (NSArray *)shapesForMosaicOfSize:(NSSize)mosaicSize
{
	if (!tileShapes)
	{
		int				xCount, 
						yCount;
		if (isFixedSize)
		{
			int		minX = 10, 
					minY = 10, 
					maxX = 200, 
					maxY = 200;
			
			if (mosaicSize.height * minX * tileAspectRatio / mosaicSize.width < minY)
				minX = mosaicSize.width * minY / tileAspectRatio / mosaicSize.height;
			if (mosaicSize.width * minY / tileAspectRatio / mosaicSize.height < minX)
				minY = minX * mosaicSize.height * tileAspectRatio / mosaicSize.width;
			if (mosaicSize.height * maxX * tileAspectRatio / mosaicSize.width > maxY)
				maxX = mosaicSize.width * maxY / tileAspectRatio / mosaicSize.height;
			if (mosaicSize.width * maxY / tileAspectRatio / mosaicSize.height > maxX)
				maxY = maxX * mosaicSize.height * tileAspectRatio / mosaicSize.width;
			
			xCount = minX + (maxX - minX) * tileCountFraction;
			yCount = minY + (maxY - minY) * tileCountFraction;
		}
		else
		{
			xCount = tilesAcross;
			yCount = tilesDown;
		}
		
		NSMutableArray	*temporaryShapes = [NSMutableArray arrayWithCapacity:(xCount * yCount)];

			// Decide which way all of the tabs will point.
		PuzzleTabType	tabTypes[xCount * 2 + 1][yCount];
		int				x, y;
		for (x = 0; x < xCount * 2 + 1; x++)
			for (y = 0; y < yCount; y++)
			{
				if (random() % 100 >= tabbedSidesRatio * 100.0)
					tabTypes[x][y] = noTab;
				else
					tabTypes[x][y] = (random() % 2 == 0 ? inwardsTab : outwardsTab);
			}
		
			// Decide the curviness of the sides
		float			horizontalCurviness[xCount + 1][yCount + 1],
						verticalCurviness[xCount + 1][yCount + 1];
		for (x = 0; x < xCount + 1; x++)
			for (y = 0; y < yCount + 1; y++)
			{
				horizontalCurviness[x][y] = (y == 0 || y == yCount) ? 0.0 : (random() % 200 - 100) / 100.0 * curviness;
				verticalCurviness[x][y] = (x == 0 || x == xCount) ? 0.0 : (random() % 200 - 100) / 100.0 * curviness;
			}
		
			// Add a bezier path for each puzzle piece.
		float			xSize = mosaicSize.width / xCount, 
						ySize = mosaicSize.height / yCount;
		for (y = yCount - 1; y >= 0; y--)
			for (x = 0; x < xCount; x++)
			{
					// Add this piece to the list.
				NSRect					tileBounds = NSMakeRect(xSize * x, ySize * y, xSize, ySize);
				
				[temporaryShapes addObject:[MacOSaiXPuzzleTileShape tileShapeWithBounds:tileBounds 
																			 topTabType:(y == yCount - 1 ? noTab : tabTypes[x * 2][y]) 
																			leftTabType:(x == 0 ? noTab : tabTypes[x * 2 - 1][y]) 
																		   rightTabType:(x == xCount - 1 ? noTab : -tabTypes[x * 2 + 1][y]) 
																		  bottomTabType:(y == 0 ? noTab : -tabTypes[x * 2][y - 1]) 
																 topLeftHorizontalCurve:horizontalCurviness[x][y + 1] 
																   topLeftVerticalCurve:-verticalCurviness[x][y + 1] 
																topRightHorizontalCurve:-horizontalCurviness[x + 1][y + 1] 
																  topRightVerticalCurve:-verticalCurviness[x + 1][y + 1] 
															  bottomLeftHorizontalCurve:horizontalCurviness[x][y] 
																bottomLeftVerticalCurve:verticalCurviness[x][y] 
															 bottomRightHorizontalCurve:-horizontalCurviness[x + 1][y] 
															   bottomRightVerticalCurve:verticalCurviness[x + 1][y] 
																			 alignImage:alignImages]];
			}
		
		tileShapes = [[NSArray arrayWithArray:temporaryShapes] retain];
	}
		
	return tileShapes;
}


@end

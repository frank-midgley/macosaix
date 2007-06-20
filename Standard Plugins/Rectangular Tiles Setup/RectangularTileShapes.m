//
//  RectangularTileShapes.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "RectangularTileShapes.h"
#import "RectangularTileShapesEditor.h"


@implementation MacOSaiXRectangularTileShape


+ (MacOSaiXRectangularTileShape *)tileShapeWithOutline:(NSBezierPath *)inOutline
{
	return [[[MacOSaiXRectangularTileShape alloc] initWithOutline:inOutline] autorelease];
}


- (id)initWithOutline:(NSBezierPath *)inOutline
{
	if (self = [super init])
	{
		outline = [inOutline retain];
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


@implementation MacOSaiXRectangularTileShapes


- (id)init
{
	if (self = [super init])
	{
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Rectangular Tile Shapes"];
		
		isFreeForm = YES;
		[self setTilesAcross:[[plugInDefaults objectForKey:@"Tiles Across"] intValue]];
		[self setTilesDown:[[plugInDefaults objectForKey:@"Tiles Down"] intValue]];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXRectangularTileShapes	*copy = [[MacOSaiXRectangularTileShapes allocWithZone:zone] init];
	
	if (isFreeForm)
	{
		[copy setTilesAcross:[self tilesAcross]];
		[copy setTilesDown:[self tilesDown]];
	}
	else
	{
		[copy setTileAspectRatio:[self tileAspectRatio]];
		[copy setTileCount:[self tileCount]];
	}
	
	return copy;
}


- (NSImage *)image
{
	NSImage	*image = [[[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)] autorelease];
	NSRect	rect = NSMakeRect(0.0, 4.0, 31.0, 25.0);
	
	[image lockFocus];
		[[NSColor lightGrayColor] set];
		NSFrameRect(NSOffsetRect(rect, 1.0, -1.0));
		[[NSColor whiteColor] set];
		NSRectFill(rect);
		[[NSColor blackColor] set];
		NSFrameRect(rect);
		
		NSDictionary	*attributes = [NSDictionary dictionaryWithObjectsAndKeys:
												[NSFont boldSystemFontOfSize:9.0], NSFontAttributeName, 
												nil];
		NSString		*string = [NSString stringWithFormat:@"%d", tilesAcross];
		NSSize			stringSize = [string sizeWithAttributes:attributes];
		[string drawAtPoint:NSMakePoint(NSMidX(rect) - stringSize.width / 2.0, 
										NSMaxY(rect) - stringSize.height + 1.0) 
			 withAttributes:attributes];
		string = [NSString stringWithFormat:@"%d", tilesDown];
		stringSize = [string sizeWithAttributes:attributes];
		[string drawAtPoint:NSMakePoint(NSMidX(rect) - stringSize.width / 2.0, NSMinY(rect)) 
			 withAttributes:attributes];
		
		[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMidX(rect) - 2.0, NSMidY(rect) - 2.0) 
								  toPoint:NSMakePoint(NSMidX(rect) + 2.0, NSMidY(rect) + 2.0)];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMidX(rect) - 2.0, NSMidY(rect) + 2.0) 
								  toPoint:NSMakePoint(NSMidX(rect) + 2.0, NSMidY(rect) - 2.0)];
	[image unlockFocus];
	
	return image;
}


- (BOOL)isFreeForm
{
	return isFreeForm;
}


- (void)setTilesAcross:(unsigned int)count
{
	isFreeForm = YES;
	
    tilesAcross = (count > 0 ? count : 40);
}


- (unsigned int)tilesAcross
{
	return tilesAcross;
}


- (void)setTilesDown:(unsigned int)count
{
	isFreeForm = YES;
	
    tilesDown = (count > 0 ? count : 40);
}


- (unsigned int)tilesDown
{
	return tilesDown;
}

- (void)setTileAspectRatio:(float)aspectRatio
{
	isFreeForm = NO;
	
	tileAspectRatio = aspectRatio;
}


- (float)tileAspectRatio
{
	return tileAspectRatio;
}


- (void)setTileCount:(float)count
{
	isFreeForm = NO;
	
	tileCount = count;
}


- (float)tileCount
{
	return tileCount;
}


- (void)setUseMatrixStyleOrdering:(BOOL)flag
{
	useMatrixStyleOrdering = flag;
}


- (BOOL)useMatrixStyleOrdering
{
	return useMatrixStyleOrdering;
}


- (id)briefDescription
{
	if (isFreeForm)
		return [NSString stringWithFormat:NSLocalizedString(@"%d by %d rectangles", @""), tilesAcross, tilesDown];
	else
		return [NSString stringWithFormat:NSLocalizedString(@"%d by %d rectangles", @""), tilesAcross, tilesDown];
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
	NSMutableDictionary	*settings =[NSMutableDictionary dictionary];
	
	if ([self isFreeForm])
	{
		[settings setObject:@"Free-form" forKey:@"Sizing"];
		[settings setObject:[NSNumber numberWithInt:[self tilesAcross]] forKey:@"Tiles Across"];
		[settings setObject:[NSNumber numberWithInt:[self tilesDown]] forKey:@"Tiles Down"];
	}
	else
	{
		[settings setObject:@"Fixed Size" forKey:@"Sizing"];
		[settings setObject:[NSNumber numberWithFloat:[self tileAspectRatio]] forKey:@"Tile Aspect Ratio"];
		[settings setObject:[NSNumber numberWithFloat:[self tileCount]] forKey:@"Tile Count"];
	}
	
	[settings setObject:[NSNumber numberWithBool:[self useMatrixStyleOrdering]] forKey:@"Use Matrix Style Ordering"];

	return [settings writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	isFreeForm = (![settings objectForKey:@"Sizing"] || [[settings objectForKey:@"Sizing"] isEqualToString:@"Free-form"]);
	
	if (isFreeForm)
	{
		[self setTilesAcross:[[settings objectForKey:@"Tiles Across"] intValue]];
		[self setTilesDown:[[settings objectForKey:@"Tiles Down"] intValue]];
	}
	else
	{
		[self setTileAspectRatio:[[settings objectForKey:@"Tile Aspect Ratio"] floatValue]];
		[self setTileCount:[[settings objectForKey:@"Tile Count"] floatValue]];
	}
	
	[self setUseMatrixStyleOrdering:[[settings objectForKey:@"Use Matrix Style Ordering"] boolValue]];

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
	int				xCount, yCount;
	
	if (isFreeForm)
	{
		xCount = [self tilesAcross];
		yCount = [self tilesDown];
	}
	else
	{
		int		minX = 10, 
				minY = 10, 
				maxX = 200, 
				maxY = 200;
		
		if (mosaicSize.height * [self tileAspectRatio] / mosaicSize.width < 1.0)
			minX = mosaicSize.width * minY / [self tileAspectRatio] / mosaicSize.height;
		if (mosaicSize.width / [self tileAspectRatio] / mosaicSize.height < 1.0)
			minY = minX * mosaicSize.height * [self tileAspectRatio] / mosaicSize.width;
		if (mosaicSize.height * [self tileAspectRatio] / mosaicSize.width > 1.0)
			maxX = mosaicSize.width * maxY / [self tileAspectRatio] / mosaicSize.height;
		if (mosaicSize.width / [self tileAspectRatio] / mosaicSize.height > 1.0)
			maxY = maxX * mosaicSize.height * [self tileAspectRatio] / mosaicSize.width;
		
		xCount = minX + (maxX - minX) * [self tileCount];
		yCount = minY + (maxY - minY) * [self tileCount];
	}
	
	NSMutableArray	*tileOutlines = [NSMutableArray arrayWithCapacity:(xCount * yCount)];
	NSRect			tileRect = NSMakeRect(0.0, 0.0, mosaicSize.width / xCount, mosaicSize.height / yCount);
	
	if ([self useMatrixStyleOrdering])
	{
		int				counts[xCount], x;
		for (x = 0; x < xCount; x++)
			counts[x] = 0;
		
		unsigned long	totalCount = xCount * yCount, 
						currentCount = 0;
		while (currentCount < totalCount)
		{
			x = random() % xCount;
			
			if (counts[x] < yCount)
			{
				tileRect.origin.x = x * tileRect.size.width;
				tileRect.origin.y = (yCount - counts[x] - 1) * tileRect.size.height;
				
				NSBezierPath	*path = [NSBezierPath bezierPath];
				[path moveToPoint:NSMakePoint(NSMinX(tileRect), NSMinY(tileRect))];
				[path lineToPoint:NSMakePoint(NSMaxX(tileRect), NSMinY(tileRect))];
				[path lineToPoint:NSMakePoint(NSMaxX(tileRect), NSMaxY(tileRect))];
				[path lineToPoint:NSMakePoint(NSMinX(tileRect), NSMaxY(tileRect))];
				[tileOutlines addObject:[MacOSaiXRectangularTileShape tileShapeWithOutline:path]];
				
				counts[x]++;
				currentCount++;
			}
		}
	}
	else
	{
		int		x, y;
		
		for (y = yCount - 1; y >= 0; y--)
			for (x = 0; x < xCount; x++)
			{
				tileRect.origin.x = x * tileRect.size.width;
				tileRect.origin.y = y * tileRect.size.height;
				
				NSBezierPath	*path = [NSBezierPath bezierPath];
				[path moveToPoint:NSMakePoint(NSMinX(tileRect), NSMinY(tileRect))];
				[path lineToPoint:NSMakePoint(NSMaxX(tileRect), NSMinY(tileRect))];
				[path lineToPoint:NSMakePoint(NSMaxX(tileRect), NSMaxY(tileRect))];
				[path lineToPoint:NSMakePoint(NSMinX(tileRect), NSMaxY(tileRect))];
				[tileOutlines addObject:[MacOSaiXRectangularTileShape tileShapeWithOutline:path]];
			}
	}

	return [NSArray arrayWithArray:tileOutlines];
}


@end

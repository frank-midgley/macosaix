//
//  HexagonalTileShapes.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "HexagonalTileShapes.h"
#import "HexagonalTileShapesEditor.h"


@implementation MacOSaiXHexagonalTileShape


+ (MacOSaiXHexagonalTileShape *)tileShapeWithOutline:(NSBezierPath *)inOutline
{
	return [[[MacOSaiXHexagonalTileShape alloc] initWithOutline:inOutline] autorelease];
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


@implementation MacOSaiXHexagonalTileShapes


- (id)init
{
	if (self = [super init])
	{
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Hexagonal Tile Shapes"];
		
		isFreeForm = YES;
		[self setTilesAcross:[[plugInDefaults objectForKey:@"Tiles Across"] intValue]];
		[self setTilesDown:[[plugInDefaults objectForKey:@"Tiles Down"] intValue]];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXHexagonalTileShapes	*copy = [[MacOSaiXHexagonalTileShapes allocWithZone:zone] init];
	
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
	NSImage			*image = [[[[self class] image] copy] autorelease];
	NSDictionary	*attributes = [NSDictionary dictionaryWithObject:[NSFont boldSystemFontOfSize:9.0] 
															  forKey:NSFontAttributeName];
	
	[image lockFocus];
		NSRect		rect = NSMakeRect(0.0, 0.0, 32.0, 32.0);
		NSString	*string = [NSString stringWithFormat:@"%d", tilesAcross];
		NSSize		stringSize = [string sizeWithAttributes:attributes];
		[string drawAtPoint:NSMakePoint(NSMidX(rect) - stringSize.width / 2.0, 
										NSMaxY(rect) - stringSize.height - 2.0) 
			 withAttributes:attributes];
		string = [NSString stringWithFormat:@"%d", tilesDown];
		stringSize = [string sizeWithAttributes:attributes];
		[string drawAtPoint:NSMakePoint(NSMidX(rect) - stringSize.width / 2.0, NSMinY(rect) + 3.0) 
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


- (id)briefDescription
{
	// TODO: handle both size types
	
	return [NSString stringWithFormat:NSLocalizedString(@"%d by %d hexagons", @""), tilesAcross, tilesDown];
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
	
    int				x, y;
    float			xSize = mosaicSize.width / (xCount - 1.0/3.0), 
					ySize = mosaicSize.height / yCount, originX, originY;
    NSMutableArray	*tileOutlines = [NSMutableArray arrayWithCapacity:(xCount * yCount)];
    
    for (x = 0; x < xCount; x++)
        for (y = 0; y < ((x % 2 == 0) ? yCount : yCount + 1); y++)
        {
            originX = xSize * (x - 1.0 / 3.0);
            originY = ySize * ((x % 2 == 0) ? y : y - 0.5);
			
            NSBezierPath	*tileOutline = [NSBezierPath bezierPath];
            [tileOutline moveToPoint:NSMakePoint(MIN(MAX(originX + xSize / 3, 0) , mosaicSize.width),
												 MIN(MAX(originY, 0) , mosaicSize.height))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize, 0) , mosaicSize.width),
												 MIN(MAX(originY, 0) , mosaicSize.height))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize * 4 / 3, 0) , mosaicSize.width),
												 MIN(MAX(originY + ySize / 2, 0) , mosaicSize.height))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize, 0) , mosaicSize.width),
												 MIN(MAX(originY + ySize, 0) , mosaicSize.height))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize / 3, 0) , mosaicSize.width),
												 MIN(MAX(originY + ySize, 0), mosaicSize.height))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX, 0) , mosaicSize.width),
												 MIN(MAX(originY + ySize / 2, 0), mosaicSize.height))];
            [tileOutline closePath];
            [tileOutlines addObject:[MacOSaiXHexagonalTileShape tileShapeWithOutline:tileOutline]];
        }
    
	return [NSArray arrayWithArray:tileOutlines];
}


@end

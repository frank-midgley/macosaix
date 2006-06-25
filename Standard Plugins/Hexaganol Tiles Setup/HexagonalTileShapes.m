//
//  HexagonalTileShapes.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "HexagonalTileShapes.h"
#import "HexagonalTileShapesEditor.h"


@implementation MacOSaiXHexagonalTileShapes


+ (NSImage *)image
{
	static	NSImage	*image = nil;
	
	if (!image)
	{
		NSBezierPath	*path = [NSBezierPath bezierPath];
		[path moveToPoint:NSMakePoint(1.5, 15.5)];
		[path lineToPoint:NSMakePoint(9.5, 0.5)];
		[path lineToPoint:NSMakePoint(23.5, 0.5)];
		[path lineToPoint:NSMakePoint(31.5, 15.5)];
		[path lineToPoint:NSMakePoint(23.5, 30.5)];
		[path lineToPoint:NSMakePoint(9.5, 30.5)];
		[path lineToPoint:NSMakePoint(1.5, 15.5)];
		[path closePath];
		
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform translateXBy:-1.0 yBy:1.0];
		
		image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
		[image lockFocus];
			[[NSColor lightGrayColor] set];
			[path fill];
			
			path = [transform transformBezierPath:path];
			[[NSColor whiteColor] set];
			[path fill];
			[[NSColor blackColor] set];
			[path stroke];
		[image unlockFocus];
	}
	
	return image;
}


+ (Class)editorClass
{
	return [MacOSaiXHexagonalTileShapesEditor class];
}


+ (Class)preferencesControllerClass
{
	return nil;
}


- (id)init
{
	if (self = [super init])
	{
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Hexagonal Tile Shapes"];
		int				tilesAcrossPref = [[plugInDefaults objectForKey:@"Tiles Across"] intValue],
						tilesDownPref = [[plugInDefaults objectForKey:@"Tiles Down"] intValue];
		
		[self setTilesAcross:(tilesAcrossPref > 0 ? tilesAcrossPref : 40)];
		[self setTilesDown:(tilesDownPref > 0 ? tilesDownPref : 40)];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXHexagonalTileShapes	*copy = [[MacOSaiXHexagonalTileShapes allocWithZone:zone] init];
	
	[copy setTilesAcross:[self tilesAcross]];
	[copy setTilesDown:[self tilesDown]];
	
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


- (NSString *)briefDescription
{
	return [NSString stringWithFormat:NSLocalizedString(@"%d by %d hexagons", @""), tilesAcross, tilesDown];
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
    int				x, y;
    float			xSize = 1.0 / (tilesAcross - 1.0/3.0), ySize = 1.0 / tilesDown, originX, originY;
    NSMutableArray	*tileOutlines = [NSMutableArray arrayWithCapacity:(tilesAcross * tilesDown)];
    
    for (x = 0; x < tilesAcross; x++)
        for (y = 0; y < ((x % 2 == 0) ? tilesDown : tilesDown + 1); y++)
        {
            originX = xSize * (x - 1.0 / 3.0);
            originY = ySize * ((x % 2 == 0) ? y : y - 0.5);
			
            NSBezierPath	*tileOutline = [NSBezierPath bezierPath];
            [tileOutline moveToPoint:NSMakePoint(MIN(MAX(originX + xSize / 3, 0) , 1),
                            MIN(MAX(originY, 0) , 1))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize, 0) , 1),
                            MIN(MAX(originY, 0) , 1))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize * 4 / 3, 0) , 1),
                            MIN(MAX(originY + ySize / 2, 0) , 1))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize, 0) , 1),
                            MIN(MAX(originY + ySize, 0) , 1))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize / 3, 0) , 1),
                            MIN(MAX(originY + ySize, 0), 1))];
            [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX, 0) , 1),
                            MIN(MAX(originY + ySize / 2, 0), 1))];
            [tileOutline closePath];
            [tileOutlines addObject:tileOutline];
        }
    
	return [NSArray arrayWithArray:tileOutlines];
}


@end

//
//  RectangularTileShapes.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "RectangularTileShapes.h"
#import "RectangularTileShapesEditor.h"


@implementation MacOSaiXRectangularTileShapes


+ (NSString *)name
{
	return @"Rectangular";
}


+ (Class)editorClass
{
	return [MacOSaiXRectangularTileShapesEditor class];
}


+ (Class)preferencesControllerClass
{
	return nil;
}


- (id)init
{
	if (self = [super init])
	{
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Rectangular Tile Shapes"];
		
		[self setTilesAcross:[[plugInDefaults objectForKey:@"Tiles Across"] intValue]];
		[self setTilesDown:[[plugInDefaults objectForKey:@"Tiles Down"] intValue]];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXRectangularTileShapes	*copy = [[MacOSaiXRectangularTileShapes allocWithZone:zone] init];
	
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
	return [NSString stringWithFormat:@"%d by %d rectangles", tilesAcross, tilesDown];
}


- (NSString *)settingsAsXMLElement
{
	return [NSString stringWithFormat:@"<DIMENSIONS ACROSS=\"%d\" DOWN=\"%d\"/>", tilesAcross, tilesDown];
}


- (NSArray *)shapes
{
	int				x, y;
	NSRect			tileRect = NSMakeRect(0.0, 0.0, 1.0 / tilesAcross, 1.0 / tilesDown);
	NSMutableArray	*tileOutlines = [NSMutableArray arrayWithCapacity:(tilesAcross * tilesDown)];
		
	for (x = 0; x < tilesAcross; x++)
		for (y = tilesDown - 1; y >= 0; y--)
			{
				tileRect.origin.x = x * tileRect.size.width;
				tileRect.origin.y = y * tileRect.size.height;
				[tileOutlines addObject:[NSBezierPath bezierPathWithRect:tileRect]];
			}
		
	return [NSArray arrayWithArray:tileOutlines];
}


@end

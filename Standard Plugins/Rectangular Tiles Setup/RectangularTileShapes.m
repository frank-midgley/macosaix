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


+ (NSImage *)image
{
	static	NSImage	*image = nil;
	
	if (!image)
	{
		NSRect	rect = NSMakeRect(0.0, 4.0, 31.0, 23.0);
		
		image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
		[image lockFocus];
			[[NSColor lightGrayColor] set];
			NSFrameRect(NSOffsetRect(rect, 1.0, -1.0));
			[[NSColor whiteColor] set];
			NSRectFill(rect);
			[[NSColor blackColor] set];
			NSFrameRect(rect);
		[image unlockFocus];
	}
	
	return image;
}


+ (Class)editorClass
{
	return [MacOSaiXRectangularTileShapesEditor class];
}


+ (Class)preferencesControllerClass
{
	return self;
}


- (id)init
{
	if (self = [super init])
	{
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Rectangular Tile Shapes"];
		int				tilesAcrossPref = [[plugInDefaults objectForKey:@"Tiles Across"] intValue],
						tilesDownPref = [[plugInDefaults objectForKey:@"Tiles Down"] intValue];
		
		[self setTilesAcross:(tilesAcrossPref > 0 ? tilesAcrossPref : 40)];
		[self setTilesDown:(tilesDownPref > 0 ? tilesDownPref : 40)];
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

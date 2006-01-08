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


+ (NSImage *)imageWithSize:(NSSize)size label:(NSString *)label
{
	NSImage	*image = [[[NSImage alloc] initWithSize:size] autorelease];

	[image lockFocus];
		float	height = size.width / 4.0 * 3.0;
		NSRect	rect = NSMakeRect(0.0, (size.height - height) / 2.0, size.width - 1.0, height);
		
		[[NSColor lightGrayColor] set];
		NSFrameRect(NSOffsetRect(rect, 1.0, -1.0));
		[[NSColor whiteColor] set];
		NSRectFill(rect);
		[[NSColor blackColor] set];
		NSFrameRect(rect);
		
		if ([label length] > 0)
		{
			NSDictionary	*attributes = [NSDictionary dictionaryWithObjectsAndKeys:
												[NSFont systemFontOfSize:8.0], NSFontAttributeName, 
												nil];
			NSSize			labelSize = [label sizeWithAttributes:attributes];
			
			[label drawInRect:NSMakeRect(NSMinX(rect) + (NSWidth(rect) - labelSize.width) / 2.0,
										 NSMinY(rect) + (NSHeight(rect) - labelSize.height) / 2.0, 
										 labelSize.width, labelSize.height)
			   withAttributes:attributes];
		}
	[image unlockFocus];
	
	return image;
}


+ (NSImage *)image
{
	static	NSImage	*image = nil;
	
	if (!image)
	{
		NSImage	*smallImage = [self imageWithSize:NSMakeSize(16.0, 16.0) label:nil];
		
		image = [[self imageWithSize:NSMakeSize(32.0, 32.0) label:nil] retain];
		[image addRepresentations:[smallImage representations]];
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
	NSString	*labelFormat = (tilesAcross < 100 && tilesDown < 100) ? @"%dx%d" : @"%dx\n%d";
	
	return [[self class] imageWithSize:NSMakeSize(32.0, 32.0) 
								 label:[NSString stringWithFormat:labelFormat, tilesAcross, tilesDown]];
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

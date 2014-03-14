//
//  GuitarPickTileShapes.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "GuitarPickTileShapes.h"
#import "GuitarPickTileShapesEditor.h"


@implementation MacOSaiXGuitarPickTileShapes


+ (NSImage *)image
{
	static	NSImage	*image = nil;
	
	if (!image)
	{
		image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
		
		NSBezierPath	*downTilePath = [NSBezierPath bezierPath];
		[downTilePath moveToPoint:NSMakePoint(16.0,  2.0)];
		[downTilePath lineToPoint:NSMakePoint(28.0, 14.0)];
		[downTilePath lineToPoint:NSMakePoint(28.0, 26.0)];
		[downTilePath lineToPoint:NSMakePoint(16.0, 30.0)];
		[downTilePath lineToPoint:NSMakePoint( 4.0, 26.0)];
		[downTilePath lineToPoint:NSMakePoint( 4.0, 14.0)];
		[downTilePath lineToPoint:NSMakePoint(16.0,  2.0)];
		
		[image lockFocus];
			[[NSColor whiteColor] set];
			[downTilePath fill];
			[[NSColor blackColor] set];
			[downTilePath stroke];
		[image unlockFocus];
	}
	
	return image;
}


+ (Class)editorClass
{
	return [MacOSaiXGuitarPickTileShapesEditor class];
}


+ (Class)preferencesControllerClass
{
	return nil;
}


- (id)init
{
	if (self = [super init])
	{
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Guitar Pick Tile Shapes"];
		int				rowCountPref = [[plugInDefaults objectForKey:@"Row Count"] intValue];
		
		[self setRowCount:(rowCountPref > 0 ? rowCountPref : 40) aspectRatio:1.0];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXGuitarPickTileShapes	*copy = [[MacOSaiXGuitarPickTileShapes allocWithZone:zone] init];
	
	[copy setRowCount:[self rowCount] aspectRatio:[self aspectRatio]];
	
	return copy;
}


- (NSImage *)image
{
	NSImage	*image = [[[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)] autorelease];
	NSBezierPath	*downTilePath = [NSBezierPath bezierPath];
	[downTilePath moveToPoint:NSMakePoint(  0.0,  0.0)];
	[downTilePath lineToPoint:NSMakePoint( 12.0, 12.0)];
	[downTilePath lineToPoint:NSMakePoint( 12.0, 24.0)];
	[downTilePath lineToPoint:NSMakePoint(  0.0, 28.0)];
	[downTilePath lineToPoint:NSMakePoint(-12.0, 24.0)];
	[downTilePath lineToPoint:NSMakePoint(-12.0, 12.0)];
	[downTilePath lineToPoint:NSMakePoint(  0.0,  0.0)];
	
	[image lockFocus];
//		[[NSColor lightGrayColor] set];
//		NSFrameRect(NSOffsetRect(rect, 1.0, -1.0));
		[[NSColor whiteColor] set];
		[downTilePath fill];
		[[NSColor blackColor] set];
		[downTilePath stroke];
		
//		NSDictionary	*attributes = [NSDictionary dictionaryWithObjectsAndKeys:
//												[NSFont boldSystemFontOfSize:9.0], NSFontAttributeName, 
//												nil];
//		NSString		*string = [NSString stringWithFormat:@"%d", tilesAcross];
//		NSSize			stringSize = [string sizeWithAttributes:attributes];
//		[string drawAtPoint:NSMakePoint(NSMidX(rect) - stringSize.width / 2.0, 
//										NSMaxY(rect) - stringSize.height + 1.0) 
//			 withAttributes:attributes];
//		string = [NSString stringWithFormat:@"%d", tilesDown];
//		stringSize = [string sizeWithAttributes:attributes];
//		[string drawAtPoint:NSMakePoint(NSMidX(rect) - stringSize.width / 2.0, NSMinY(rect)) 
//			 withAttributes:attributes];
	[image unlockFocus];
	
	return image;
}


- (void)setRowCount:(unsigned int)count aspectRatio:(float)ratio
{
    rowCount = count;
	aspectRatio = ratio;
}


- (unsigned int)rowCount
{
	return rowCount;
}


- (float)aspectRatio
{
	return aspectRatio;
}


- (id)briefDescription
{
	return [NSString stringWithFormat:@"%d rows of guitar picks", rowCount];
}


- (NSString *)settingsAsXMLElement
{
	return [NSString stringWithFormat:@"<DIMENSIONS ROWCOUNT=\"%d\" ASPECTRATIO=\"%f\"/>", rowCount, aspectRatio];
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXTileShapesSettingType];
	
	if ([settingType isEqualToString:@"DIMENSIONS"])
	{
		[self setRowCount:[[[settingDict objectForKey:@"ROWCOUNT"] description] intValue] 
			  aspectRatio:[[[settingDict objectForKey:@"ASPECTRATIO"] description] floatValue]];
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
	float			unitSize = 0.1 / (rowCount + 0.1);
	int				colCount = (aspectRatio / unitSize - 3) / 6;
	float			xOff = 0.0;	//(1.0 - (colCount * 6 + 3) * unitSize * aspectRatio) / 2.0;
	
	int				x, y;
	NSMutableArray	*tileOutlines = [NSMutableArray arrayWithCapacity:(rowCount * colCount * 2)];

	NSBezierPath	*upTilePath = [NSBezierPath bezierPath];
	[upTilePath moveToPoint:NSMakePoint(0.0            , 0.0)];
	[upTilePath lineToPoint:NSMakePoint(3.0 * unitSize , 1.0 * unitSize)];
	[upTilePath lineToPoint:NSMakePoint(3.0 * unitSize , 4.0 * unitSize)];
	[upTilePath lineToPoint:NSMakePoint(0.0            , 7.0 * unitSize)];
	[upTilePath lineToPoint:NSMakePoint(-3.0 * unitSize, 4.0 * unitSize)];
	[upTilePath lineToPoint:NSMakePoint(-3.0 * unitSize, 1.0 * unitSize)];
	[upTilePath lineToPoint:NSMakePoint(0.0            , 0.0)];
	
	NSBezierPath	*downTilePath = [NSBezierPath bezierPath];
	[downTilePath moveToPoint:NSMakePoint(0.0            , 0.0)];
	[downTilePath lineToPoint:NSMakePoint(3.0 * unitSize , 3.0 * unitSize)];
	[downTilePath lineToPoint:NSMakePoint(3.0 * unitSize , 6.0 * unitSize)];
	[downTilePath lineToPoint:NSMakePoint(0.0            , 7.0 * unitSize)];
	[downTilePath lineToPoint:NSMakePoint(-3.0 * unitSize, 6.0 * unitSize)];
	[downTilePath lineToPoint:NSMakePoint(-3.0 * unitSize, 3.0 * unitSize)];
	[downTilePath lineToPoint:NSMakePoint(0.0            , 0.0)];
	
	for (y = 0; y < rowCount; y++)
		for (x = 0; x < colCount; x++)
			{
				NSAffineTransform	*upTransform = [NSAffineTransform transform];
				[upTransform translateXBy:xOff + (x * 6 + 3) * unitSize yBy:(y * 10) * unitSize];
				[tileOutlines addObject:[upTransform transformBezierPath:upTilePath]];
				
				NSAffineTransform	*downTransform = [NSAffineTransform transform];
				[downTransform translateXBy:xOff + (x * 6) * unitSize yBy:(y * 10 + 4) * unitSize];
				[tileOutlines addObject:[downTransform transformBezierPath:downTilePath]];
			}
		
	return [NSArray arrayWithArray:tileOutlines];
}


@end

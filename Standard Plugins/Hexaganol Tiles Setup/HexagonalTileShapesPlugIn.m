//
//  HexagonalTileShapesPlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 1/4/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "HexagonalTileShapesPlugIn.h"
#import "HexagonalTileShapes.h"
#import "HexagonalTileShapesEditor.h"


@implementation MacOSaiXHexagonalTileShapesPlugIn


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


+ (Class)dataSourceClass
{
	return [MacOSaiXHexagonalTileShapes class];
}


+ (Class)editorClass
{
	return [MacOSaiXHexagonalTileShapesEditor class];
}


+ (Class)preferencesEditorClass
{
	return nil;
}


@end

//
//  SpiralTileShapesPlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 8/16/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXSpiralTileShapesPlugIn.h"
#import "MacOSaiXSpiralTileShapes.h"
#import "MacOSaiXSpiralTileShapesEditor.h"


@implementation MacOSaiXSpiralTileShapesPlugIn


+ (NSImage *)image
{
	static	NSImage	*image = nil;
	
	if (!image)
	{
		NSBezierPath	*innerShape = [NSBezierPath bezierPath];
		
		float			midX = 12.5, 
						midY = 20.0, 
						radiusIncrement = 19.0, 
						angle = 0.0;
		
		[innerShape moveToPoint:NSMakePoint(midX, midY)];
		while (angle <= 2.0 * M_PI)
		{
			float	radius = radiusIncrement * angle / 2.0 / M_PI;
			
			[innerShape lineToPoint:NSMakePoint(midX + radius * cos(angle), midY + radius * sin(angle))];
			
			angle += 2.0 * M_PI / 360.0;
		}
		[innerShape lineToPoint:NSMakePoint(midX, midY)];
		
		image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
		
		[image lockFocus];
			[[NSColor lightGrayColor] set];
			[innerShape fill];
			
			NSAffineTransform	*transform = [NSAffineTransform transform];
			[transform translateXBy:-1.0 yBy:1.0];
			innerShape = [transform transformBezierPath:innerShape];
			[[NSColor whiteColor] set];
			[innerShape fill];
			[[NSColor blackColor] set];
			[innerShape stroke];
		[image unlockFocus];
	}
	
	return image;
}


+ (Class)dataSourceClass
{
	return [MacOSaiXSpiralTileShapes class];
}


+ (Class)editorClass
{
	return [MacOSaiXSpiralTileShapesEditor class];
}


+ (Class)preferencesEditorClass
{
	return nil;
}


@end

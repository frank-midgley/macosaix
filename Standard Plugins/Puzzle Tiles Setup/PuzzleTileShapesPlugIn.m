//
//  PuzzleTileShapesPlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 1/4/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "PuzzleTileShapesPlugIn.h"
#import "PuzzleTileShapes.h"
#import "PuzzleTileShapesEditor.h"


@implementation MacOSaiXPuzzleTileShapesPlugIn


+ (NSImage *)image
{
	static	NSImage	*image = nil;
	
	if (!image)
	{
		MacOSaiXPuzzleTileShape	*tileShape = [MacOSaiXPuzzleTileShape tileShapeWithBounds:NSMakeRect(0.0, 0.0, 22.0, 22.0) 
																			   topTabType:inwardsTab 
																			  leftTabType:inwardsTab 
																			 rightTabType:outwardsTab 
																			bottomTabType:outwardsTab 
																   topLeftHorizontalCurve:0.0 
																	 topLeftVerticalCurve:0.0 
																  topRightHorizontalCurve:0.0 
																	topRightVerticalCurve:0.0 
																bottomLeftHorizontalCurve:0.0 
																  bottomLeftVerticalCurve:0.0 
															   bottomRightHorizontalCurve:0.0 
																 bottomRightVerticalCurve:0.0 
																			   alignImage:NO];
		NSBezierPath			*tileOutline = [tileShape unitOutline];
		
		NSAffineTransform		*transform = [NSAffineTransform transform];
		[transform translateXBy:3.0 yBy:7.0];
		
		image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
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
		[image unlockFocus];
	}
	
	return image;
}


+ (Class)dataSourceClass
{
	return [MacOSaiXPuzzleTileShapes class];
}


+ (Class)dataSourceEditorClass
{
	return [MacOSaiXPuzzleTileShapesEditor class];
}


+ (Class)preferencesEditorClass
{
	return nil;
}


@end

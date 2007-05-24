//
//  MacOSaiXImageOrientationsEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageOrientationsEditor.h"

#import "MacOSaiX.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXImageOrientations.h"


@implementation MacOSaiXImageOrientationsEditor


- (id)initWithMosaicViev:(MosaicView *)inMosaicView
{
	if (self = [super initWithMosaicView:inMosaicView])
	{
	}
	
	return self;
}


- (NSString *)editorNibName
{
	return @"Image Orientations Editor";
}


- (NSString *)title
{
	return NSLocalizedString(@"Image Orientations", @"");
}


- (NSArray *)plugInClasses
{
	return [(MacOSaiX *)[NSApp delegate] imageOrientationsPlugIns];
}


- (NSString *)plugInTitleFormat
{
	return NSLocalizedString(@"%@", @"");
}


- (void)setMosaicDataSource:(id<MacOSaiXDataSource>)dataSource
{
	[[[self mosaicView] mosaic] setImageOrientations:(id<MacOSaiXImageOrientations>)dataSource];
}


- (id<MacOSaiXDataSource>)mosaicDataSource
{
	return [[[self mosaicView] mosaic] imageOrientations];
}


- (void)beginEditing
{
	[super beginEditing];
	
	[[self mosaicView] setTargetImageFraction:1.0];
}


- (void)embellishMosaicViewInRect:(NSRect)rect
{
	[super embellishMosaicViewInRect:rect];
	
	MacOSaiXMosaic	*mosaic = [[self mosaicView] mosaic];
	NSRect			imageBounds = [[self mosaicView] imageBounds];
	
		// Draw the vector field 
	NSBezierPath	*path = [NSBezierPath bezierPath];
	[path moveToPoint:NSMakePoint(-4.0, -4.0)];
	[path lineToPoint:NSMakePoint(0.0, 4.0)];
	[path lineToPoint:NSMakePoint(0.0, 4.0)];
	[path lineToPoint:NSMakePoint(4.0, -4.0)];
	[path lineToPoint:NSMakePoint(-4.0, -4.0)];
	[path moveToPoint:NSMakePoint(-12.0, -8.0)];
	[path lineToPoint:NSMakePoint(12.0, -8.0)];
	[path lineToPoint:NSMakePoint(12.0, 8.0)];
	[path lineToPoint:NSMakePoint(-12.0, 8.0)];
	[path lineToPoint:NSMakePoint(-12.0, -8.0)];
	
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.4] set];
	int		xCount = NSWidth(imageBounds) / 30, 
			yCount = NSHeight(imageBounds) / 30;
	float	xSize = NSWidth(imageBounds) / xCount, 
			ySize = NSHeight(imageBounds) / yCount;
	float	x, y;
	for (y = ySize / 2.0 + NSMinY(imageBounds); y < NSMaxY(imageBounds); y += ySize)
		for (x = xSize / 2.0 + NSMinX(imageBounds); x < NSMaxX(imageBounds); x += xSize)
		{
			float	angle = [[mosaic imageOrientations] imageOrientationAtPoint:NSMakePoint(x, y) inRectOfSize:imageBounds.size];
			
			NSAffineTransform	*transform = [NSAffineTransform transform];
			[transform translateXBy:x yBy:y];
			[transform rotateByDegrees:-angle];
			[[transform transformBezierPath:path] fill];
		}
			
	
		// TODO: Draw the focus point (with an eye?)
}


- (void)handleEventInMosaicView:(NSEvent *)event
{
	// TODO: change the focus point
}


- (void)dataSource:(id<MacOSaiXDataSource>)dataSource settingsDidChange:(NSString *)changeDescription
{
//	[[[self mosaicView] mosaic] setTileShapes:[[[self mosaicView] mosaic] tileShapes] creatingTiles:YES];
	
	[[self mosaicView] setNeedsDisplay:YES];
}


//- (void)dealloc
//{
//	[super dealloc];
//}


@end

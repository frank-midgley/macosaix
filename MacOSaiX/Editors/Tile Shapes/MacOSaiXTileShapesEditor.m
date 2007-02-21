//
//  MacOSaiXTileShapesEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapesEditor.h"

#import "MacOSaiX.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXPlugIn.h"
#import "MacOSaiXTileShapes.h"


@implementation MacOSaiXTileShapesEditor


- (id)initWithMosaicView:(MosaicView *)inMosaicView
{
	if (self = [super initWithMosaicView:inMosaicView])
	{
		tileShapesToDraw = [[NSMutableArray alloc] initWithCapacity:16];
	}
	
	return self;
}


- (NSString *)editorNibName
{
	return @"Tile Shapes Editor";
}


- (NSString *)title
{
	return NSLocalizedString(@"Tile Shapes", @"");
}


- (NSArray *)plugInClasses
{
	return [(MacOSaiX *)[NSApp delegate] tileShapesPlugIns];
}


- (NSString *)plugInTitleFormat
{
	return NSLocalizedString(@"%@ Tile Shapes", @"");
}


- (void)setMosaicDataSource:(id<MacOSaiXDataSource>)dataSource
{
	[[[self mosaicView] mosaic] setTileShapes:(id<MacOSaiXTileShapes>)dataSource creatingTiles:YES];
}


- (id<MacOSaiXDataSource>)mosaicDataSource
{
	return [[[self mosaicView] mosaic] tileShapes];
}


- (void)beginEditing
{
	[super beginEditing];
	
	[[self mosaicView] setTargetImageFraction:1.0];
}


- (void)continueEmbellishingMosaicView
{
	NSDate					*startTime = [NSDate date];
	
	[[self mosaicView] lockFocus];
	
	NSRect					imageBounds = [[self mosaicView] imageBounds];
	NSSize					targetImageSize = [[[[self mosaicView] mosaic] targetImage] size];
	NSAffineTransform		*darkenTransform = [NSAffineTransform transform], 
							*lightenTransform = [NSAffineTransform transform];
	[darkenTransform translateXBy:NSMinX(imageBounds) - 0.5 yBy:NSMinY(imageBounds) + 0.5];
	[darkenTransform scaleXBy:NSWidth(imageBounds) / targetImageSize.width 
						  yBy:NSHeight(imageBounds) / targetImageSize.height];
	[lightenTransform translateXBy:NSMinX(imageBounds) + 0.5 yBy:NSMinY(imageBounds) - 0.5];
	[lightenTransform scaleXBy:NSWidth(imageBounds) / targetImageSize.width 
						   yBy:NSHeight(imageBounds) / targetImageSize.height];
	NSColor					*darkenColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.25], 
							*lightenColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.25];
	
	while ([tileShapesToDraw count] > 0 && [startTime timeIntervalSinceNow] > -0.05)
	{
		NSBezierPath	*tileOutline = [[tileShapesToDraw objectAtIndex:0] outline];
		
		[darkenColor set];
		[[darkenTransform transformBezierPath:tileOutline] stroke];
		[lightenColor set];
		[[lightenTransform transformBezierPath:tileOutline] stroke];
		
		[tileShapesToDraw removeObjectAtIndex:0];
	}

	[[NSGraphicsContext currentContext] flushGraphics];
	
	[[self mosaicView] unlockFocus];
	
	if ([tileShapesToDraw count] > 0)
		[self performSelector:_cmd withObject:nil afterDelay:0.0];
}


- (void)embellishMosaicViewInRect:(NSRect)updateRect
{
	if (![[self mosaicView] inLiveResize])
	{
		NSSize	targetImageSize = [[[[self mosaicView] mosaic] targetImage] size];
		
		[tileShapesToDraw removeAllObjects];
		[tileShapesToDraw addObjectsFromArray:[[[[self mosaicView] mosaic] tileShapes] shapesForMosaicOfSize:targetImageSize]];
		
		[self continueEmbellishingMosaicView];
	}
}


- (void)plugInSettingsDidChange:(NSString *)description
{
	[[[self mosaicView] mosaic] setTileShapes:[[[self mosaicView] mosaic] tileShapes] creatingTiles:YES];
	
	[[self mosaicView] setNeedsDisplay:YES];
}


- (void)endEditing
{
	[tileShapesToDraw removeAllObjects];
	
	[super endEditing];
}


- (void)dealloc
{
	[tileShapesToDraw release];
	
	[super dealloc];
}


@end

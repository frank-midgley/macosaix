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


+ (NSImage *)image
{
	return [NSImage imageNamed:@"Tile Shapes"];
}


- (id)initWithDelegate:(id<MacOSaiXMosaicEditorDelegate>)delegate
{
	if (self = [super initWithDelegate:delegate])
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
	return NSLocalizedString(@"%@", @"");
}


- (void)setMosaicDataSource:(id<MacOSaiXDataSource>)dataSource
{
	[[[self delegate] mosaic] setTileShapes:(id<MacOSaiXTileShapes>)dataSource creatingTiles:YES];
}


- (id<MacOSaiXDataSource>)mosaicDataSource
{
	return [[[self delegate] mosaic] tileShapes];
}


- (void)beginEditing
{
	[super beginEditing];
}


- (void)continueEmbellishingMosaicView:(MosaicView *)mosaicView
{
	NSDate					*startTime = [NSDate date];
	
	[mosaicView lockFocus];
	
	NSRect					imageBounds = [mosaicView imageBounds];
	NSSize					targetImageSize = [[[[self delegate] mosaic] targetImage] size];
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
	
	[mosaicView unlockFocus];
	
	if ([tileShapesToDraw count] > 0)
		[self performSelector:_cmd withObject:mosaicView afterDelay:0.0];
}


- (void)embellishMosaicView:(MosaicView *)mosaicView inRect:(NSRect)rect;
{
	if (![mosaicView inLiveResize])
	{
		NSSize	targetImageSize = [[[[self delegate] mosaic] targetImage] size];
		
		[tileShapesToDraw removeAllObjects];
		[tileShapesToDraw addObjectsFromArray:[[[[self delegate] mosaic] tileShapes] shapesForMosaicOfSize:targetImageSize]];
		
		[self continueEmbellishingMosaicView:mosaicView];
	}
}


- (void)dataSource:(id<MacOSaiXDataSource>)dataSource settingsDidChange:(NSString *)changeDescription
{
	[[[self delegate] mosaic] setTileShapes:[[[self delegate] mosaic] tileShapes] creatingTiles:YES];
	
	[[self delegate] embellishmentNeedsDisplay];
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

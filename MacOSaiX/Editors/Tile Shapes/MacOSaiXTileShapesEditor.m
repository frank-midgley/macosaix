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
#import "Tiles.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXWarningController.h"


@implementation MacOSaiXTileShapesEditor


+ (void)load
{
	[super load];
}


+ (NSImage *)image
{
	return [NSImage imageNamed:@"Tile Shapes"];
}


+ (NSString *)title
{
	return NSLocalizedString(@"Tile Shapes", @"");
}


+ (NSString *)description
{
	return NSLocalizedString(@"This setting lets you choose the shapes of the tiles in the mosaic.", @"");
}


+ (NSString *)sortKey
{
	return @"1";
}


- (id)initWithDelegate:(id<MacOSaiXMosaicEditorDelegate>)delegate
{
	if (self = [super initWithDelegate:delegate])
	{
		tilesToEmbellish = [[NSMutableSet alloc] initWithCapacity:[[[delegate mosaic] tiles] count]];
	}
	
	return self;
}


- (NSString *)editorNibName
{
	return @"Tile Shapes Editor";
}


- (NSArray *)plugInClasses
{
	return [(MacOSaiX *)[NSApp delegate] tileShapesPlugIns];
}


- (NSString *)plugInTitleFormat
{
	return NSLocalizedString(@"%@", @"");
}


- (BOOL)shouldChangePlugInClass:(id)sender
{
	return (sender == self ||
			[[[self delegate] mosaic] numberOfImagesFound] == 0 || 
			![MacOSaiXWarningController warningIsEnabled:@"Changing Tile Shapes"] || 
			[MacOSaiXWarningController runAlertForWarning:@"Changing Tile Shapes" 
													title:NSLocalizedString(@"Do you wish to change the tile shapes?", @"") 
												  message:NSLocalizedString(@"All work in the current mosaic will be lost.", @"") 
											 buttonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Change", @""), NSLocalizedString(@"Cancel", @""), nil]] == 0);
}


- (NSSize)minimumViewSize
{
	NSSize	minSize = [editorView frame].size;

		// Subtract out the current size of the plug-in's editor view.
	minSize.width -= NSWidth([[plugInEditorBox contentView] frame]);
	minSize.height -= NSHeight([[plugInEditorBox contentView] frame]);
	
		// Add the minimum size of the plug-in's editor view.
	minSize.width += [plugInEditor minimumSize].width;
	minSize.height += [plugInEditor minimumSize].height;
	
	return minSize;
}


- (void)setMosaicDataSource:(id<MacOSaiXDataSource>)dataSource
{
	[[[self delegate] mosaic] setTileShapes:(id<MacOSaiXTileShapes>)dataSource];
}


- (id<MacOSaiXDataSource>)mosaicDataSource
{
	return [[[self delegate] mosaic] tileShapes];
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
	
	while ([tilesToEmbellish count] > 0 && [startTime timeIntervalSinceNow] > -0.1)
	{
		MacOSaiXTile	*tileToEmbellish = [tilesToEmbellish anyObject];
		NSBezierPath	*tileOutline = [tileToEmbellish outline], 
						*darkenOutline = [darkenTransform transformBezierPath:tileOutline];
		
		if (NSIntersectsRect([mosaicView visibleRect], [darkenOutline bounds]))
		{
			[darkenColor set];
			[darkenOutline stroke];
			[lightenColor set];
			[[lightenTransform transformBezierPath:tileOutline] stroke];
		}
		
		[tilesToEmbellish removeObject:tileToEmbellish];
	}
	
	[[NSGraphicsContext currentContext] flushGraphics];
	
	[mosaicView unlockFocus];
	
	if ([tilesToEmbellish count] > 0)
		[self performSelector:_cmd withObject:mosaicView afterDelay:0.0];
}


- (void)embellishMosaicView:(MosaicView *)mosaicView inRect:(NSRect)rect;
{
	if (![mosaicView inLiveRedraw])
	{
		[tilesToEmbellish addObjectsFromArray:[mosaicView tilesInRect:rect]];
		
		[self continueEmbellishingMosaicView:mosaicView];
	}
}


- (void)setDataSource:(id<MacOSaiXDataSource>)dataSource value:(id)value forKey:(NSString *)key
{
	[super setDataSource:dataSource value:value forKey:key];
	
	[[[self delegate] mosaic] createTiles];
	
	[tilesToEmbellish removeAllObjects];
	
	[[self delegate] embellishmentNeedsDisplay];
}


- (NSString *)lastChosenPlugInClassDefaultsKey
{
	return @"Last Chosen Tile Shapes Class";
}


- (void)dataSource:(id<MacOSaiXDataSource>)dataSource 
	  didChangeKey:(NSString *)key
		 fromValue:(id)previousValue 
		actionName:(NSString *)actionName;
{
	// TODO: don't display the warning continuously
	if ([[[self delegate] mosaic] numberOfImagesFound] == 0 || 
		![MacOSaiXWarningController warningIsEnabled:@"Changing Tile Shapes"] || 
		[MacOSaiXWarningController runAlertForWarning:@"Changing Tile Shapes" 
												title:NSLocalizedString(@"Do you wish to change the tile shapes?", @"") 
											  message:NSLocalizedString(@"All work in the current mosaic will be lost.", @"") 
										 buttonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Change", @""), NSLocalizedString(@"Cancel", @""), nil]] == 0)
	{
		[super dataSource:dataSource didChangeKey:key fromValue:previousValue actionName:actionName];
		
		[[[self delegate] mosaic] setTileShapes:[[[self delegate] mosaic] tileShapes]];
		
		[tilesToEmbellish removeAllObjects];
		
		[[self delegate] embellishmentNeedsDisplay];
	}
	else
		[self setDataSource:dataSource value:previousValue forKey:key];
}


- (BOOL)endEditing
{
	if ([super endEditing])
	{
		[tilesToEmbellish removeAllObjects];
		return YES;
	}
	else
		return NO;
}


- (void)dealloc
{
	[tilesToEmbellish release];
	
	[super dealloc];
}


@end

#import "MosaicView.h"
#import "Tiles.h"
#import "MacOSaiXDocument.h"

@implementation MosaicView


- (id)init
{
    if (self = [super init])
	{
		highlightedTile = nil;
		phase = 0;
	}
    return self;
}


- (void)setOriginalImage:(NSImage *)inOriginalImage
{
	if (originalImage != inOriginalImage && viewMode == viewTilesOutline)
		[self setNeedsDisplay:YES];
	[originalImage autorelease];
	originalImage = [inOriginalImage retain];
}


- (void)setMosaicImage:(NSImage *)inMosaicImage
{
	if (mosaicImage != inMosaicImage && viewMode != viewTilesOutline)
		[self setNeedsDisplay:YES];
	[mosaicImage autorelease];
	mosaicImage = [inMosaicImage retain];
}


- (void)setViewMode:(MosaicViewMode)mode
{
	if (viewMode != mode)
		[self setNeedsDisplay:YES];
	viewMode = mode;
}


- (MosaicViewMode)viewMode
{
    return viewMode;
}


- (void)mouseDown:(NSEvent *)theEvent
{
    BOOL keepOn = YES;
    NSPoint mouseLoc;

	switch (viewMode)
	{
		case viewMosaic:
		case viewImageSources:
		case viewImageRegions:
			break;
		case viewTilesOutline:
		case viewHighlightedTile:
			while (keepOn)
			{
				theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask];
				if ([theEvent type] == NSLeftMouseUp)
				{
					mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
					if ([self mouse:mouseLoc inRect:[self bounds]])
						[(MacOSaiXDocument *)[[self window] delegate] selectTileAtPoint:mouseLoc];
					keepOn = NO;
				}
			}
			break;
	}
	
    return;
}


- (void)drawRect:(NSRect)theRect
{
	if (viewMode == viewTilesOutline || viewMode == viewImageRegions)
		[originalImage drawInRect:[self bounds] fromRect:NSMakeRect(0, 0, [originalImage size].width,
																	 [originalImage size].height)
						 operation:NSCompositeCopy fraction:1.0];
	else
		[mosaicImage drawInRect:[self bounds] fromRect:NSMakeRect(0, 0, [mosaicImage size].width,
																   [mosaicImage size].height)
					   operation:NSCompositeCopy fraction:1.0];
	
	switch (viewMode)
	{
		case viewMosaic:
			break;

		case viewTilesOutline:
			if (tilesOutline)
			{
				NSAffineTransform	*transform;
				
				if (highlightedTile)
				{
						// Draw the outlines of the neighboring tiles.
					transform = [NSAffineTransform transform];
					[transform translateXBy:0.5 yBy:-0.5];
					[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
					[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];	// darken
					[[transform transformBezierPath:neighborhoodOutline] stroke];
					transform = [NSAffineTransform transform];
					[transform translateXBy:-0.5 yBy:0.5];
					[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
					[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];	// lighten
					[[transform transformBezierPath:neighborhoodOutline] stroke];
					
						// Draw the tile's outline with a 4pt thick dashed line.
					NSAffineTransform	*transform = [NSAffineTransform transform];
					[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
					NSBezierPath		*bezierPath = [transform transformBezierPath:[highlightedTile outline]];
					[bezierPath setLineWidth:4];
					
					float				dashes[2] = {5.0, 5.0};
					[bezierPath setLineDash:dashes count:2 phase:phase];
					[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
					[bezierPath stroke];
				
					[bezierPath setLineDash:dashes count:2 phase:(phase + 5) % 10];
					[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
					[bezierPath stroke];
				}
				else
				{
					transform = [NSAffineTransform transform];
					[transform translateXBy:0.5 yBy:-0.5];
					[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
					[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];	// darken
					[[transform transformBezierPath:tilesOutline] stroke];
					
					transform = [NSAffineTransform transform];
					[transform translateXBy:-0.5 yBy:0.5];
					[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
					[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];	// lighten
					[[transform transformBezierPath:tilesOutline] stroke];
				}
			}
			break;
			
		case viewImageSources:
		case viewImageRegions:
			break;

		case viewHighlightedTile:
			if (highlightedTile != nil)
			{
				NSAffineTransform	*transform = [NSAffineTransform transform];
				NSBezierPath		*bezierPath;
				float				dashes[2] = {5.0, 5.0};
				
				[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
				bezierPath = [transform transformBezierPath:[highlightedTile outline]];
				[bezierPath setLineWidth:4];
				
				[bezierPath setLineDash:dashes count:2 phase:phase];
				[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
				[bezierPath stroke];
			
				[bezierPath setLineDash:dashes count:2 phase:(phase + 5) % 10];
				[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
				[bezierPath stroke];
			}
			break;
	}
}


#pragma mark Tile Setup methods


- (void)setTileOutlines:(NSArray *)tileOutlines;
{
	int	index;
	
	[tilesOutline release];
	tilesOutline = [[NSBezierPath bezierPath] retain];
	for (index = 0; index < [tileOutlines count]; index++)
	    [tilesOutline appendBezierPath:[tileOutlines objectAtIndex:index]];
	[self setNeedsDisplay:YES];
}


#pragma mark Highlight Tile methods


- (void)highlightTile:(Tile *)tile
{
    if (highlightedTile != nil)
    {
			// Erase any previous highlight.
		NSAffineTransform	*transform = [NSAffineTransform transform];
		NSBezierPath		*bezierPath;
		phase = ++phase % 10;
		[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
		bezierPath = [transform transformBezierPath:[highlightedTile outline]];
		[self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 2,
											   [bezierPath bounds].origin.y - 2,
											   [bezierPath bounds].size.width + 4,
											   [bezierPath bounds].size.height + 4)];
		bezierPath = [transform transformBezierPath:neighborhoodOutline];
		[self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 1,
											   [bezierPath bounds].origin.y - 1,
											   [bezierPath bounds].size.width + 2,
											   [bezierPath bounds].size.height + 2)];
		
			// Create a combined path for all neighbors of the tile.
		[neighborhoodOutline autorelease];
		neighborhoodOutline = [[NSBezierPath bezierPath] retain];
		NSEnumerator		*neighborEnumerator = [[tile neighbors] objectEnumerator];
		Tile				*neighbor = nil;
		while (neighbor = [neighborEnumerator nextObject])
			[neighborhoodOutline appendBezierPath:[neighbor outline]];
			
			// Mark the new neighborhood outline's bounds as needing display.
		bezierPath = [transform transformBezierPath:neighborhoodOutline];
		[self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 1,
											   [bezierPath bounds].origin.y - 1,
											   [bezierPath bounds].size.width + 2,
											   [bezierPath bounds].size.height + 2)];
    }
	else
		[self setNeedsDisplay:YES];
	
    highlightedTile = tile;
}


- (void)animateHighlight
{
    NSAffineTransform	*transform = [NSAffineTransform transform];
    NSBezierPath	*bezierPath;
    
    phase = ++phase % 10;
    [transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
    bezierPath = [transform transformBezierPath:[highlightedTile outline]];
    [self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 2,
					   [bezierPath bounds].origin.y - 2,
					   [bezierPath bounds].size.width + 4,
					   [bezierPath bounds].size.height + 4)];
//	bezierPath = [transform transformBezierPath:neighborhoodOutline];
//	[self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 1,
//										   [bezierPath bounds].origin.y - 1,
//										   [bezierPath bounds].size.width + 2,
//										   [bezierPath bounds].size.height + 2)];
}


- (void)dealloc
{
	[neighborhoodOutline release];
	
	[super dealloc];
}


@end

#import "MosaicView.h"
#import "MacOSaiXDocument.h"
#import "MacOSaiXWindowController.h"
#import "Tiles.h"


@implementation MosaicView


- (void)awakeFromNib
{
	mosaicImageLock = [[NSLock alloc] init];
	tilesOutline = [[NSBezierPath bezierPath] retain];
	tilesNeedingDisplay = [[NSMutableArray array] retain];
	lastUpdate = [[NSDate date] retain];
}


- (void)setDocument:(MacOSaiXDocument *)inDocument
{
    if (inDocument && document != inDocument)
	{
		document = inDocument;
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(originalImageDidChange:) 
													 name:MacOSaiXOriginalImageDidChangeNotification
												   object:document];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(tileShapesDidChange:) 
													 name:MacOSaiXTileShapesDidChangeStateNotification 
												   object:document];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(tileImageDidChange:) 
													 name:MacOSaiXTileImageDidChangeNotification 
												   object:document];
	}
}


- (BOOL)isOpaque
{
	return YES;
}


- (void)originalImageDidChange:(NSNotification *)notification
{
//	if (originalImage != inOriginalImage && viewMode == viewTilesOutline)
//		[self setNeedsDisplay:YES];
	NSImage	*originalImage = [document originalImage];
	
		// Create an NSImage to hold the mosaic image (somewhat arbitrary size)
	[mosaicImageLock lock];
		[mosaicImage autorelease];
		mosaicImage = [[NSImage alloc] initWithSize:NSMakeSize(1600.0, 1600.0 * [originalImage size].height / [originalImage size].width)];
		[mosaicImage lockFocus];
			[[NSColor blackColor] set];
			NSRectFill(NSMakeRect(0.0, 0.0, [mosaicImage size].width, [mosaicImage size].height));
		[mosaicImage unlockFocus];
		
			// set up a transform so we can scale tiles to the mosaic image's size (tile shapes are defined on a unit square)
		[mosaicImageTransform release];
		mosaicImageTransform = [[NSAffineTransform transform] retain];
		[mosaicImageTransform translateXBy:0.5 yBy:0.5];	// line up with pixel boundaries
		[mosaicImageTransform scaleXBy:[mosaicImage size].width yBy:[mosaicImage size].height];
	[mosaicImageLock unlock];
	
	[self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
}


- (void)setNeedsDisplay
{
	[super setNeedsDisplay:YES];
}


- (void)tileShapesDidChange:(NSNotification *)notification
{
	[tilesOutline removeAllPoints];
	
	NSEnumerator	*tileEnumerator = [[document tiles] objectEnumerator];
	Tile			*tile = nil;
	while (tile = [tileEnumerator nextObject])
	    [tilesOutline appendBezierPath:[tile outline]];
	
		// TODO: main thread?
	[self setNeedsDisplay:YES];
}


- (void)tileImageDidChange:(NSNotification *)notification
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	Tile				*tile = [[notification userInfo] objectForKey:@"Tile"];
	NSBezierPath		*clipPath = [mosaicImageTransform transformBezierPath:[tile outline]];
	ImageMatch			*imageMatch = [tile displayedImageMatch];
	NSImageRep			*newImageRep = [[document imageCache] imageRepAtSize:[clipPath bounds].size
															   forIdentifier:[imageMatch imageIdentifier] 
																  fromSource:[imageMatch imageSource]];
	
	if (newImageRep)
	{
			// Draw the tile's new image in the mosaic
		NSSize			newImageRepSize = [newImageRep size];
		NSRect			drawRect;
		
			// scale the image to the tile's size, but preserve it's aspect ratio
		if ([clipPath bounds].size.width / newImageRepSize.width <
			[clipPath bounds].size.height / newImageRepSize.height)
		{
			drawRect.size = NSMakeSize([clipPath bounds].size.height * newImageRepSize.width / newImageRepSize.height,
									   [clipPath bounds].size.height);
			drawRect.origin = NSMakePoint([clipPath bounds].origin.x - (drawRect.size.width - [clipPath bounds].size.width) / 2.0,
										  [clipPath bounds].origin.y);
		}
		else
		{
			drawRect.size = NSMakeSize([clipPath bounds].size.width,
									   [clipPath bounds].size.width * newImageRepSize.height / newImageRepSize.width);
			drawRect.origin = NSMakePoint([clipPath bounds].origin.x,
										  [clipPath bounds].origin.y - (drawRect.size.height - [clipPath bounds].size.height) /2.0);
		}		
			// ...
		[mosaicImageLock lock];
			NS_DURING
				[mosaicImage lockFocus];
					[clipPath setClip];
					[newImageRep drawInRect:drawRect];
				[mosaicImage unlockFocus];
			NS_HANDLER
				NSLog(@"Could not lock focus on mosaic image");
			NS_ENDHANDLER
		[mosaicImageLock unlock];
		
		[self performSelectorOnMainThread:@selector(setTileNeedsDisplay:) withObject:tile waitUntilDone:NO];
	}

	[pool release];
}


- (void)setTileNeedsDisplay:(Tile *)tile
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	[tilesNeedingDisplay addObject:tile];
	
	if ([tilesNeedingDisplay count] > 32 || [lastUpdate timeIntervalSinceNow] < -0.25)
	{
		NSAffineTransform	*transform = [[NSAffineTransform transform] retain];
		[transform translateXBy:0.5 yBy:0.5];	// line up with pixel boundaries
		[transform scaleXBy:[self frame].size.width yBy:[self frame].size.height];
		
		NSEnumerator	*tileEnumerator = [tilesNeedingDisplay objectEnumerator];
		Tile			*tileNeedingDisplay = nil;
		while (tileNeedingDisplay = [tileEnumerator nextObject])
			[self setNeedsDisplayInRect:[[transform transformBezierPath:[tileNeedingDisplay outline]] bounds]];
		
		[tilesNeedingDisplay removeAllObjects];
		
		[lastUpdate release];
		lastUpdate = [[NSDate date] retain];
	}
	
	[pool release];
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
						[(MacOSaiXWindowController *)[[self window] delegate] selectTileAtPoint:mouseLoc];
					keepOn = NO;
				}
			}
			break;
	}
	
    return;
}


- (void)drawRect:(NSRect)theRect
{
	NSImage	*originalImage = [document originalImage];
	
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
		NSEnumerator		*neighborEnumerator = [[tile neighboringTiles] objectEnumerator];
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
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[mosaicImage release];
	[mosaicImageLock release];
	[mosaicImageTransform release];
	[neighborhoodOutline release];
	[tilesNeedingDisplay release];
	[lastUpdate release];
	[tilesOutline release];
		
	[super dealloc];
}


@end

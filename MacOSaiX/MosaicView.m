#import "MosaicView.h"
#import "MacOSaiXDocument.h"
#import "MacOSaiXWindowController.h"
#import "MacOSaiXImageCache.h"
#import "Tiles.h"


@interface MosaicView (PrivateMethods)
- (void)tileShapesDidChange:(NSNotification *)notification;
@end


@implementation MosaicView


- (void)awakeFromNib
{
	mosaicImageLock = [[NSLock alloc] init];
	tilesOutline = [[NSBezierPath bezierPath] retain];
	tilesNeedingDisplay = [[NSMutableArray array] retain];
	tilesNeedingDisplayLock = [[NSLock alloc] init];
	lastUpdate = [[NSDate date] retain];
	
	NSImage	*blackImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
	[blackImage lockFocus];
		[[NSColor blackColor] set];
		[NSBezierPath fillRect:NSMakeRect(0.0, 0.0, 16.0, 16.0)];
	[blackImage unlockFocus];
	blackRep = [[blackImage bestRepresentationForDevice:nil] retain];
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
		
		[self tileShapesDidChange:nil];
	}
}


- (BOOL)isOpaque
{
	return YES;
}


- (void)originalImageDidChange:(NSNotification *)notification
{
	NSImage	*originalImage = [document originalImage];
	
		// Create an NSImage to hold the mosaic image (somewhat arbitrary size)
	[mosaicImageLock lock];
		[mosaicImage autorelease];
		mosaicImage = [[NSImage alloc] initWithSize:NSMakeSize(1600.0, 1600.0 * [originalImage size].height / [originalImage size].width)];
		[mosaicImage setCachedSeparately:YES];
		[mosaicImage setCacheMode:NSImageCacheNever];
		
		[mosaicImage lockFocus];
			[[NSColor blackColor] set];
			NSRectFill(NSMakeRect(0.0, 0.0, [mosaicImage size].width, [mosaicImage size].height));
		[mosaicImage unlockFocus];
		
			// set up a transform so we can scale tiles to the mosaic image's size (tile shapes are defined on a unit square)
		[mosaicImageTransform release];
		mosaicImageTransform = [[NSAffineTransform transform] retain];
		[mosaicImageTransform scaleXBy:[mosaicImage size].width yBy:[mosaicImage size].height];
	[mosaicImageLock unlock];
	
	[self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:YES];
}


- (void)setNeedsDisplay
{
	[super setNeedsDisplay:YES];
}


- (void)tileShapesDidChange:(NSNotification *)notification
{
	[tilesOutline removeAllPoints];
	
	NSEnumerator	*tileEnumerator = [[document tiles] objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
	    [tilesOutline appendBezierPath:[tile outline]];
	
		// TODO: main thread?
	[self setNeedsDisplay:YES];
}


- (void)refreshTile:(MacOSaiXTile *)tileToRefresh
{
	NSBezierPath		*clipPath = [mosaicImageTransform transformBezierPath:[tileToRefresh outline]];
	MacOSaiXImageMatch	*imageMatch = [tileToRefresh displayedImageMatch];
	NSImageRep			*newImageRep = nil;
	
	if (imageMatch)
		newImageRep = [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:[clipPath bounds].size
															  forIdentifier:[imageMatch imageIdentifier] 
															     fromSource:[imageMatch imageSource]];
	else
		newImageRep = blackRep;
	
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
		
#if 0
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
#else
		NSArray	*paramaters = [NSArray arrayWithObjects:clipPath, newImageRep, [NSValue valueWithRect:drawRect], nil];
		[self performSelectorOnMainThread:@selector(drawTileImage:) withObject:paramaters waitUntilDone:YES];
#endif
		
		[tilesNeedingDisplayLock lock];
			[tilesNeedingDisplay addObject:tileToRefresh];
		[tilesNeedingDisplayLock unlock];
		
		if ([lastUpdate timeIntervalSinceNow] < -0.1)
			[self performSelectorOnMainThread:@selector(setTileNeedsDisplay:) withObject:nil waitUntilDone:YES];
	}
}


- (void)drawTileImage:(NSArray *)paramaters
{
	NSBezierPath	*clipPath = [paramaters objectAtIndex:0];
	NSImageRep		*newImageRep = [paramaters objectAtIndex:1];
	NSRect			drawRect = [[paramaters objectAtIndex:2] rectValue];
	
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
}


- (void)setTileNeedsDisplay:(id)dummy
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	[tilesNeedingDisplayLock lock];
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform translateXBy:-1.0 yBy:-1.0];
		[transform scaleXBy:([self frame].size.width + 2.0) yBy:([self frame].size.height + 2.0)];
		
		NSEnumerator	*tileEnumerator = [tilesNeedingDisplay objectEnumerator];
		MacOSaiXTile	*tileNeedingDisplay = nil;
		while (tileNeedingDisplay = [tileEnumerator nextObject])
			[self setNeedsDisplayInRect:[[transform transformBezierPath:[tileNeedingDisplay outline]] bounds]];
		
		[tilesNeedingDisplay removeAllObjects];
		
		[lastUpdate release];
		lastUpdate = [[NSDate date] retain];
	[tilesNeedingDisplayLock unlock];
	
	[pool release];
}


- (void)setViewOriginal:(BOOL)inViewOriginal
{
	if (inViewOriginal != viewOriginal)
		[self setNeedsDisplay:YES];
	
	viewOriginal = inViewOriginal;
}


- (BOOL)viewOriginal
{
    return viewOriginal;
}


- (void)setViewTileOutlines:(BOOL)inViewTileOutlines
{
	if (inViewTileOutlines != viewTileOutlines)
		[self setNeedsDisplay:YES];
	
	viewTileOutlines = inViewTileOutlines;
}

	
- (BOOL)viewTileOutlines;
{
	return viewTileOutlines;
}


- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	
	if ([self mouse:mouseLoc inRect:[self bounds]])
		[(MacOSaiXWindowController *)[[self window] delegate] selectTileAtPoint:mouseLoc];
}


- (void)drawRect:(NSRect)theRect
{
	if (viewOriginal)
	{
		NSImage	*originalImage = [document originalImage];
		[originalImage drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	}
	else
	{
		[mosaicImageLock lock];
			[mosaicImage drawInRect:[self bounds] fromRect:NSMakeRect(0, 0, [mosaicImage size].width,
																	   [mosaicImage size].height)
						   operation:NSCompositeCopy fraction:1.0];
		[mosaicImageLock unlock];
	}
	
	if (tilesOutline && viewTileOutlines)
	{
		NSAffineTransform	*transform = [NSAffineTransform transform];
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
	
	if (highlightedTile)
	{
			// Draw the outlines of the neighboring tiles.
//		NSAffineTransform	*transform = [NSAffineTransform transform];
//		[transform translateXBy:0.5 yBy:-0.5];
//		[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
//		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];	// darken
//		[[transform transformBezierPath:neighborhoodOutline] stroke];
//		transform = [NSAffineTransform transform];
//		[transform translateXBy:-0.5 yBy:0.5];
//		[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
//		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];	// lighten
//		[[transform transformBezierPath:neighborhoodOutline] stroke];
		
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
}


#pragma mark Highlight Tile methods


- (void)highlightTile:(MacOSaiXTile *)tile
{
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
	
    if (highlightedTile)
    {
			// Mark the previously selected tile's area for re-display.
		NSBezierPath		*bezierPath = [transform transformBezierPath:[highlightedTile outline]];
		[self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 2,
											   [bezierPath bounds].origin.y - 2,
											   [bezierPath bounds].size.width + 4,
											   [bezierPath bounds].size.height + 4)];
//		bezierPath = [transform transformBezierPath:neighborhoodOutline];
//		[self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 1,
//											   [bezierPath bounds].origin.y - 1,
//											   [bezierPath bounds].size.width + 2,
//											   [bezierPath bounds].size.height + 2)];
		
			// Create a combined path for all neighbors of the tile.
//		[neighborhoodOutline autorelease];
//		neighborhoodOutline = [[NSBezierPath bezierPath] retain];
//		NSEnumerator		*neighborEnumerator = [[tile neighboringTiles] objectEnumerator];
//		MacOSaiXTile		*neighbor = nil;
//		while (neighbor = [neighborEnumerator nextObject])
//			[neighborhoodOutline appendBezierPath:[neighbor outline]];
			
			// Mark the new neighborhood outline's bounds as needing display.
//		bezierPath = [transform transformBezierPath:neighborhoodOutline];
//		[self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 1,
//											   [bezierPath bounds].origin.y - 1,
//											   [bezierPath bounds].size.width + 2,
//											   [bezierPath bounds].size.height + 2)];
    }
	
	if (tile)
	{
			// Mark the newly selected tile's area for re-display.
		NSBezierPath		*bezierPath = [transform transformBezierPath:[tile outline]];
		[self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 2,
											   [bezierPath bounds].origin.y - 2,
											   [bezierPath bounds].size.width + 4,
											   [bezierPath bounds].size.height + 4)];
	}
	
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
	[blackRep release];
		
	[super dealloc];
}


@end

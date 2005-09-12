#import "MosaicView.h"
#import "MacOSaiXDocument.h"
#import "MacOSaiXWindowController.h"
#import "MacOSaiXImageCache.h"
#import "Tiles.h"


@interface MosaicView (PrivateMethods)
- (void)tileShapesDidChange:(NSNotification *)notification;
- (void)createHighlightedImageSourcesOutline;
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
	[self setNeedsDisplay:YES];
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


- (void)refreshTile:(MacOSaiXTile *)tileToRefresh previousMatch:(MacOSaiXImageMatch *)previousMatch
{
	BOOL				tileNeedsDisplay = NO;
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
		NSArray	*parameters = [NSArray arrayWithObjects:clipPath, newImageRep, nil];
		[self performSelectorOnMainThread:@selector(drawTileImage:) withObject:parameters waitUntilDone:YES];
		tileNeedsDisplay = YES;
	}
	
		// Update the highlighted image sources outline if needed.
	if ([highlightedImageSources containsObject:[previousMatch imageSource]] && 
		![highlightedImageSources containsObject:[imageMatch imageSource]])
	{
			// There's no way to remove the tile's outline from the merged highlight 
			// outline so we have to rebuild it from scratch.
		[self createHighlightedImageSourcesOutline];
		tileNeedsDisplay = YES;
	}
	else if ([highlightedImageSources containsObject:[imageMatch imageSource]] && 
			 ![highlightedImageSources containsObject:[previousMatch imageSource]])
	{
		if (!highlightedImageSourcesOutline)
			highlightedImageSourcesOutline = [[NSBezierPath bezierPath] retain];
		[highlightedImageSourcesOutline appendBezierPath:[tileToRefresh outline]];
		tileNeedsDisplay = YES;
	}
	
	if (tileNeedsDisplay)
	{
		BOOL	timeToRefresh = NO;
		
		[tilesNeedingDisplayLock lock];
			[tilesNeedingDisplay addObject:tileToRefresh];
			timeToRefresh = ([lastUpdate timeIntervalSinceNow] < -0.1);
		[tilesNeedingDisplayLock unlock];
		
		if (timeToRefresh)
			[self performSelectorOnMainThread:@selector(setTileNeedsDisplay:) withObject:nil waitUntilDone:YES];
	}
}


- (void)drawTileImage:(NSArray *)paramaters
{
	NSBezierPath	*clipPath = [paramaters objectAtIndex:0];
	NSImageRep		*newImageRep = [paramaters objectAtIndex:1];
	
	[mosaicImageLock lock];
		NS_DURING
			[mosaicImage lockFocus];
				[clipPath setClip];
				[newImageRep drawInRect:[clipPath bounds]];
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
		[transform scaleXBy:([self frame].size.width) yBy:([self frame].size.height)];
		
		NSEnumerator	*tileEnumerator = [tilesNeedingDisplay objectEnumerator];
		MacOSaiXTile	*tileNeedingDisplay = nil;
		while (tileNeedingDisplay = [tileEnumerator nextObject])
			[self setNeedsDisplayInRect:NSInsetRect([[transform transformBezierPath:[tileNeedingDisplay outline]] bounds], -1.0, -1.0)];
		
		[tilesNeedingDisplay removeAllObjects];
		
		[lastUpdate release];
		lastUpdate = [[NSDate date] retain];
	[tilesNeedingDisplayLock unlock];
	
	[pool release];
}


- (void)setViewFade:(float)fade;
{
	if (viewFade != fade)
	{
		viewFade = fade;
		[self setNeedsDisplay:YES];
	}
}


- (float)fade
{
    return viewFade;
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
	[[document originalImage] drawInRect:[self bounds] 
								fromRect:NSZeroRect 
							   operation:NSCompositeCopy 
								fraction:1.0];

	if (viewFade > 0.0)
	{
		[mosaicImageLock lock];
			[mosaicImage drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:viewFade];
		[mosaicImageLock unlock];
	}
	
	if (tilesOutline && viewTileOutlines)
	{
			// Draw the outline of all of the tiles.
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
	
	if (highlightedImageSourcesOutline)
	{
		NSSize				boundsSize = [self bounds].size;
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform translateXBy:0.5 yBy:0.5];
		[transform scaleXBy:boundsSize.width yBy:boundsSize.height];
		NSBezierPath		*transformedOutline = [transform transformBezierPath:highlightedImageSourcesOutline];
		
			// Lighten the tiles not displaying images from the highlighted image sources.
		NSBezierPath		*lightenOutline = [NSBezierPath bezierPath];
		[lightenOutline moveToPoint:NSMakePoint(0, 0)];
		[lightenOutline lineToPoint:NSMakePoint(0, boundsSize.height)];
		[lightenOutline lineToPoint:NSMakePoint(boundsSize.width, boundsSize.height)];
		[lightenOutline lineToPoint:NSMakePoint(boundsSize.width, 0)];
		[lightenOutline closePath];
		[lightenOutline appendBezierPath:transformedOutline];
		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
		[lightenOutline fill];
		
			// Darken the outline of the tile.
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
		[transformedOutline stroke];
	}
	
	if (highlightedTile)
	{
			// Draw the highlight outline with a 4pt thick dashed line.
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


#pragma mark Highlight methods


- (void)highlightTile:(MacOSaiXTile *)tile
{
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
	
    if (highlightedTile)
    {
			// Mark the previously highlighted area for re-display.
		NSBezierPath		*bezierPath = [transform transformBezierPath:[highlightedTile outline]];
		[self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 2,
											   [bezierPath bounds].origin.y - 2,
											   [bezierPath bounds].size.width + 4,
											   [bezierPath bounds].size.height + 4)];
	}
	
	highlightedTile = tile;
	
    if (highlightedTile)
    {
			// Mark the previously highlighted area for re-display.
		NSBezierPath		*bezierPath = [transform transformBezierPath:[highlightedTile outline]];
		[self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 2,
											   [bezierPath bounds].origin.y - 2,
											   [bezierPath bounds].size.width + 4,
											   [bezierPath bounds].size.height + 4)];
	}
}


- (void)createHighlightedImageSourcesOutline
{
	NSEnumerator	*tileEnumerator = [[document tiles] objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
		if ([highlightedImageSources containsObject:[[tile displayedImageMatch] imageSource]])
		{
			if (!highlightedImageSourcesOutline)
				highlightedImageSourcesOutline = [[NSBezierPath bezierPath] retain];
			[highlightedImageSourcesOutline appendBezierPath:[tile outline]];
		}
}


- (void)highlightImageSources:(NSArray *)imageSources
{
	if (highlightedImageSourcesOutline)
		[self setNeedsDisplay:YES];
	
	[highlightedImageSources release];
	highlightedImageSources = [imageSources retain];
	
	[highlightedImageSourcesOutline release];
	highlightedImageSourcesOutline = nil;
	
		// Create a combined path for all tiles of our document that are not
		// currently displaying an image from any of the sources.
	if ([imageSources count] > 0)
		[self createHighlightedImageSourcesOutline];
	
	if (highlightedImageSourcesOutline)
		[self setNeedsDisplay:YES];
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
}


- (NSImage *)image
{
	return mosaicImage;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[mosaicImage release];
	[mosaicImageLock release];
	[mosaicImageTransform release];
	[highlightedImageSources release];
	[highlightedImageSourcesOutline release];
	[tilesNeedingDisplay release];
	[lastUpdate release];
	[tilesOutline release];
	[blackRep release];
		
	[super dealloc];
}


@end

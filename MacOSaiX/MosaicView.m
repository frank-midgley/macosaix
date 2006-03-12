//
//  MosaicView.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001-2005 Frank M. Midgley.  All rights reserved.
//

#import "MosaicView.h"
#import "MacOSaiXWindowController.h"
#import "MacOSaiXImageCache.h"

#import <pthread.h>


@interface MosaicView (PrivateMethods)
- (void)originalImageDidChange:(NSNotification *)notification;
- (void)tileShapesDidChange:(NSNotification *)notification;
- (void)createHighlightedImageSourcesOutline;
@end


@implementation MosaicView


- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect])
	{
		tilesToRefresh = [[NSMutableArray alloc] init];
		tileMatchTypesToRefresh = [[NSMutableArray alloc] init];
		tileRefreshLock = [[NSLock alloc] init];
	}
	
	return self;
}


- (void)awakeFromNib
{
	mainImageLock = [[NSLock alloc] init];
	backgroundImageLock = [[NSLock alloc] init];
	tilesOutline = [[NSBezierPath alloc] init];
	tilesNeedingDisplay = [[NSMutableArray alloc] init];
	tilesNeedDisplayLock = [[NSLock alloc] init];
	
	highlightedImageSourcesLock = [[NSLock alloc] init];
}


- (void)setMosaic:(MacOSaiXMosaic *)inMosaic
{
    if (inMosaic && mosaic != inMosaic)
	{
		if (mosaic)
			[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:mosaic];
		
		mosaic = inMosaic;
		
		if (mosaic)
		{
			[[NSNotificationCenter defaultCenter] addObserver:self 
													 selector:@selector(originalImageDidChange:) 
														 name:MacOSaiXOriginalImageDidChangeNotification
													   object:mosaic];
			[[NSNotificationCenter defaultCenter] addObserver:self 
													 selector:@selector(tileShapesDidChange:) 
														 name:MacOSaiXTileShapesDidChangeStateNotification 
													   object:mosaic];
			[[NSNotificationCenter defaultCenter] addObserver:self 
													 selector:@selector(tileImageDidChange:) 
														 name:MacOSaiXTileImageDidChangeNotification 
													   object:mosaic];
		}
		
		[self originalImageDidChange:nil];
		[self tileShapesDidChange:nil];
	}
}


- (NSRect)boundsForOriginalImage:(NSImage *)originalImage
{
	NSRect	bounds = [self bounds],
			mosaicBounds = bounds;
	NSSize	imageSize = [originalImage size];
	
	if ((NSWidth(bounds) / imageSize.width) < (NSHeight(bounds) / imageSize.height))
	{
		mosaicBounds.size.height = imageSize.height * NSWidth(bounds) / imageSize.width;
		mosaicBounds.origin.y = (NSHeight(bounds) - NSHeight(mosaicBounds)) / 2.0;
	}
	else
	{
		mosaicBounds.size.width = imageSize.width * NSHeight(bounds) / imageSize.height;
		mosaicBounds.origin.x = (NSWidth(bounds) - NSWidth(mosaicBounds)) / 2.0;
	}
	
	return mosaicBounds;
}


- (BOOL)isOpaque
{
	return NO;
}


- (void)originalImageDidChange:(NSNotification *)notification
{
	NSImage	*originalImage = [mosaic originalImage];
	
	if (originalImage != previousOriginalImage)
	{
		if (previousOriginalImage)
		{
			originalFade = 0.0;
			[NSTimer scheduledTimerWithTimeInterval:0.05 
											 target:self 
										   selector:@selector(fadeToNewOriginalImage:) 
										   userInfo:nil 
											repeats:YES];
		}
		else
			originalFade = 1.0;
		
			// De-queue any pending tile refreshes based on the previous original image.
		[tilesNeedDisplayLock lock];
			[tilesNeedingDisplay removeAllObjects];
		[tilesNeedDisplayLock unlock];
		
		if (originalImage)
		{
				// Pick a size for the main and background images.
				// (somewhat arbitrary but large enough for decent zooming)
			float	aspectRatio = [originalImage size].width / [originalImage size].height;
			mainImageSize = (aspectRatio > 1.0 ? NSMakeSize(3200.0, 3200.0 / aspectRatio) : 
												 NSMakeSize(3200.0 * aspectRatio, 3200.0));
			
			[mainImageLock lock];
					// Release the current main image.  A new one will be created later off the main thread.
				[mainImage autorelease];
				mainImage = nil;
				
					// Set up a transform so we can scale tiles to the mosaic image's size (tile shapes are defined on a unit square)
				[mainImageTransform autorelease];
				mainImageTransform = [[NSAffineTransform alloc] init];
				[mainImageTransform scaleXBy:mainImageSize.width yBy:mainImageSize.height];
			[mainImageLock unlock];
			
				// Release the current background image.  A new one will be created later if needed off the main thread.
			[backgroundImageLock lock];
					[backgroundImage autorelease];
					backgroundImage = nil;
			[backgroundImageLock unlock];
		}
	}
}


- (void)setOriginalFadeTime:(float)seconds
{
	originalFadeIncrement = seconds / 10.0;
}


- (void)fadeToNewOriginalImage:(NSTimer *)timer
{
	if (originalFade < 1.0)
	{
		if (originalFade == lastDrawnOriginalFade)
			[self setNeedsDisplay:YES];
		
		lastDrawnOriginalFade = originalFade;
	}
	else
		[timer invalidate];
}


- (void)setMainImage:(NSImage *)image
{
	if (image != mainImage)
	{
		[mainImage autorelease];
		mainImage = [image retain];
	}
}


- (NSImage *)mainImage
{
	return mainImage;
}


- (void)setBackgroundImage:(NSImage *)image
{
	if (image != backgroundImage)
	{
		[backgroundImage autorelease];
		backgroundImage = [image retain];
	}
}


- (NSImage *)backgroundImage
{
	return backgroundImage;
}


- (void)tileShapesDidChange:(NSNotification *)notification
{
	[tilesOutline removeAllPoints];
	
	NSEnumerator	*tileEnumerator = [[mosaic tiles] objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
	    [tilesOutline appendBezierPath:[tile outline]];
	
		// TODO: main thread?
	[self setNeedsDisplay:YES];
}


- (void)refreshTile:(NSDictionary *)tileDict
{
		// Add the tile to the queue of tiles to be refreshed and start the refresh 
		// thread if it isn't already running.
	MacOSaiXTile		*tile = [tileDict objectForKey:@"Tile"];
	NSString			*matchType = [tileDict objectForKey:@"Match Type"];
//	MacOSaiXImageMatch	*previousMatch = [tileDict objectForKey:@"Previous Match"];
	
	[tileRefreshLock lock];
		unsigned	index= [tilesToRefresh indexOfObject:tile];
		if (index != NSNotFound)
		{
				// Add the match type for the tile.
			NSMutableSet	*matchTypesToRefresh = [[[tileMatchTypesToRefresh objectAtIndex:index] retain] autorelease];
			[matchTypesToRefresh addObject:matchType];
			
				// Move the tile to the head of the refresh queue.
			[tilesToRefresh removeObjectAtIndex:index];
			[tilesToRefresh addObject:tile];
			[tileMatchTypesToRefresh removeObjectAtIndex:index];
			[tileMatchTypesToRefresh addObject:matchTypesToRefresh];
		}
		else
		{
				// Add the tile to the head of the refresh queue.
			[tilesToRefresh addObject:tile];
			[tileMatchTypesToRefresh addObject:[NSMutableSet setWithObject:matchType]];
		}
		
		if (!refreshingTiles)
		{
			refreshingTiles = YES;
			[NSApplication detachDrawingThread:@selector(fetchTileImages:) toTarget:self withObject:nil];
		}
	[tileRefreshLock unlock];
}


- (void)tileImageDidChange:(NSNotification *)notification
{
	[self refreshTile:[notification userInfo]];
}


- (void)fetchTileImages:(id)dummy
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	MacOSaiXTile		*tileToRefresh = nil;
	NSMutableSet		*matchTypesToRefresh = nil;
	NSDate				*lastRedraw = [NSDate date];
	NSMutableArray		*tilesToRedraw = [NSMutableArray array];
	MacOSaiXImageCache	*imageCache = [MacOSaiXImageCache sharedImageCache];
	
	do
	{
		NSAutoreleasePool	*innerPool = [[NSAutoreleasePool alloc] init];
		
			// Get the next tile from the queue, if there is one.
		[tileRefreshLock lock];
			if ([tilesToRefresh count] == 0)
				tileToRefresh = nil;
			else
			{
				tileToRefresh = [[[tilesToRefresh lastObject] retain] autorelease];
				[tilesToRefresh removeLastObject];
				matchTypesToRefresh = [[[tileMatchTypesToRefresh lastObject] retain] autorelease];
				[tileMatchTypesToRefresh removeLastObject];
			}
		[tileRefreshLock unlock];
		
		if (tileToRefresh)
		{
			NSBezierPath		*clipPath = [mainImageTransform transformBezierPath:[tileToRefresh outline]];
			if (clipPath)
			{
				MacOSaiXImageMatch	*mainImageMatch = ([tileToRefresh userChosenImageMatch] ? [tileToRefresh userChosenImageMatch] :
																							  [tileToRefresh uniqueImageMatch]), 
									*backgroundImageMatch = [tileToRefresh bestImageMatch];
				NSImageRep			*mainImageRep = nil,
									*backgroundImageRep = nil;
				BOOL				redrawMain = ([matchTypesToRefresh containsObject:@"User Chosen"] || 
												  [matchTypesToRefresh containsObject:@"Unique"]), 
									redrawBackground = [matchTypesToRefresh containsObject:@"Best"];
				
					// Get the image rep(s) to draw for this tile.
					// These steps are the primary reason we're in a separate thread because 
					// the cache may have to get the images from the sources which might have 
					// to hit the network, etc.
				if (redrawMain && mainImageMatch)
				{
						// The tile in main will draw over it so there's no need to redraw the background.
						// TBD: But what if the image rep isn't opaque?
					redrawBackground = NO;
					
					mainImageRep = [imageCache imageRepAtSize:NSIntegralRect([clipPath bounds]).size
												forIdentifier:[mainImageMatch imageIdentifier] 
												   fromSource:[mainImageMatch imageSource]];
				}
				
					// If no image will be displayed for the tile in the main layer then 
					// the background layer may need to be redrawn.
				if (redrawMain && !mainImageMatch)
					redrawBackground = YES;
				
					// TODO: background should not be redrawn if all tiles have a unique match.
				if (backgroundMode == bestMatchMode && redrawBackground && backgroundImageMatch)
					backgroundImageRep = [imageCache imageRepAtSize:NSIntegralRect([clipPath bounds]).size
													  forIdentifier:[backgroundImageMatch imageIdentifier] 
														 fromSource:[backgroundImageMatch imageSource]];
				
				[tileRefreshLock lock];
					if (redrawMain)
					{
						[tilesToRedraw addObject:[NSDictionary dictionaryWithObjectsAndKeys:
														@"Main", @"Layer", 
														tileToRefresh, @"Tile", 
														mainImageRep, @"Image Rep", // could be nil
														nil]];
						
							// Create an image to hold the mosaic if needed.
						[mainImageLock lock];
							if (!mainImage)
							{
								mainImage = [[NSImage alloc] initWithSize:mainImageSize];
								[mainImage setCachedSeparately:YES];
								
								[mainImage lockFocus];
									[[NSColor clearColor] set];
									NSRectFill(NSMakeRect(0.0, 0.0, mainImageSize.width, mainImageSize.height));
								[mainImage unlockFocus];
							}
						[mainImageLock unlock];
					}
					
					if (redrawBackground)
					{
						[tilesToRedraw addObject:[NSDictionary dictionaryWithObjectsAndKeys:
														@"Background", @"Layer", 
														tileToRefresh, @"Tile", 
														backgroundImageRep, @"Image Rep",  // could be nil
														nil]];
						
						
							// Create a new background image if needed.
						[backgroundImageLock lock];
							if (!backgroundImage)
							{
								backgroundImage = [[NSImage alloc] initWithSize:mainImageSize];
								[backgroundImage setCachedSeparately:YES];
								[backgroundImage lockFocus];
									[[NSColor clearColor] set];
									NSRectFill(NSMakeRect(0.0, 0.0, [backgroundImage size].width, [backgroundImage size].height));
								[backgroundImage unlockFocus];
							}
						[backgroundImageLock unlock];
					}
					
					if ([tilesToRedraw count] > 0 && [lastRedraw timeIntervalSinceNow] < -0.2)
					{
						[self performSelectorOnMainThread:@selector(redrawTiles:) 
											   withObject:[NSArray arrayWithArray:tilesToRedraw] 
											waitUntilDone:NO];
						[tilesToRedraw removeAllObjects];
					}
				[tileRefreshLock unlock];
				
				// Update the highlighted image sources outline if needed.
				//	MacOSaiXImageSource	*previousMatch = [refreshDict objectForKey:@"Previous Match"];
				//	[highlightedImageSourcesLock lock];
				//		if ([highlightedImageSources containsObject:[previousMatch imageSource]] && 
				//			![highlightedImageSources containsObject:[imageMatch imageSource]])
				//		{
				//				// There's no way to remove the tile's outline from the merged highlight 
				//				// outline so we have to rebuild it from scratch.
				//			[self createHighlightedImageSourcesOutline];
				//		}
				//		else if ([highlightedImageSources containsObject:[imageMatch imageSource]] && 
				//				 ![highlightedImageSources containsObject:[previousMatch imageSource]])
				//		{
				//			if (!highlightedImageSourcesOutline)
				//				highlightedImageSourcesOutline = [[NSBezierPath bezierPath] retain];
				//			[highlightedImageSourcesOutline appendBezierPath:[tileToRefresh outline]];
				//		}
				//	[highlightedImageSourcesLock unlock];
			}
		}
		
		[innerPool release];
	} while (tileToRefresh);
	
	[tileRefreshLock lock];
		if ([tilesToRedraw count] > 0)
			[self performSelectorOnMainThread:@selector(redrawTiles:) 
								   withObject:[NSArray arrayWithArray:tilesToRedraw] 
								waitUntilDone:NO];
		refreshingTiles = NO;
	[tileRefreshLock unlock];
	
	[pool release];
	
}


- (void)redrawTiles:(NSArray *)tilesToRedraw
{
	NSEnumerator	*tileDictEnumerator = [tilesToRedraw objectEnumerator];
	NSDictionary	*tileDict = nil;
	
	while (tileDict = [tileDictEnumerator nextObject])
	{
		MacOSaiXTile	*tile = [tileDict objectForKey:@"Tile"];
		NSImageRep		*imageRep = [tileDict objectForKey:@"Image Rep"];
		BOOL			redrawMain = [[tileDict objectForKey:@"Layer"] isEqualToString:@"Main"];
		NSBezierPath	*clipPath = [mainImageTransform transformBezierPath:[tile outline]];
		
		if (redrawMain)
		{
			[mainImageLock lock];
				if (mainImage)
				{
					NS_DURING
						[mainImage lockFocus];
							[clipPath setClip];
							if (imageRep)
								[imageRep drawAtPoint:[clipPath bounds].origin];
							else
							{
								[[NSColor clearColor] set];
								NSRectFill([clipPath bounds]);
							}
						[mainImage unlockFocus];
					NS_HANDLER
						NSLog(@"Could not lock focus on mosaic image");
					NS_ENDHANDLER
				}
			[mainImageLock unlock];
		}
		else
		{
			[backgroundImageLock lock];
				if (backgroundImage)
				{
					NS_DURING
						[backgroundImage lockFocus];
							[clipPath setClip];
							if (imageRep)
								[imageRep drawAtPoint:[clipPath bounds].origin];
							else
							{
								[[NSColor clearColor] set];
								NSRectFill([clipPath bounds]);
							}
						[backgroundImage unlockFocus];
					NS_HANDLER
						NSLog(@"Could not lock focus on non-unique image");
					NS_ENDHANDLER
				}
			[backgroundImageLock unlock];
		}
		
		[tilesNeedDisplayLock lock];
			[tilesNeedingDisplay addObject:tile];
		[tilesNeedDisplayLock unlock];
	}
	
		// Don't force a refresh every time we update the mosaic but make sure 
		// it gets refreshed at least 5 times a second.
	[tilesNeedDisplayLock lock];
		if (!tilesNeedDisplayTimer)
			tilesNeedDisplayTimer = [[NSTimer scheduledTimerWithTimeInterval:0.2 
																	  target:self 
																	selector:@selector(setTilesNeedDisplay:) 
																	userInfo:nil 
																	 repeats:NO] retain];
	[tilesNeedDisplayLock unlock];
}


- (void)setTilesNeedDisplay:(NSTimer *)timer
{
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform scaleXBy:([self frame].size.width) yBy:([self frame].size.height)];
	
	[tilesNeedDisplayLock lock];
		NSEnumerator	*tileEnumerator = [tilesNeedingDisplay objectEnumerator];
		MacOSaiXTile	*tileNeedingDisplay = nil;
		while (tileNeedingDisplay = [tileEnumerator nextObject])
			[self setNeedsDisplayInRect:NSInsetRect([[transform transformBezierPath:[tileNeedingDisplay outline]] bounds], -1.0, -1.0)];
		
		[tilesNeedingDisplay removeAllObjects];
		
		[tilesNeedDisplayTimer release];
		tilesNeedDisplayTimer = nil;
	[tilesNeedDisplayLock unlock];
}


- (void)setFade:(float)fade;
{
	if (viewFade != fade)
	{
		viewFade = fade;
		
		[self setNeedsDisplay:YES];
		
		[self setInLiveRedraw:[NSNumber numberWithBool:YES]];
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


- (void)setBackgroundMode:(MacOSaiXBackgroundMode)mode
{
	if (mode != backgroundMode)
	{
		backgroundMode = mode;
		
		[self setNeedsDisplay:YES];
	}
}


- (MacOSaiXBackgroundMode)backgroundMode
{
	return backgroundMode;
}


- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint						mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	MacOSaiXWindowController	*controller = [[self window] delegate];
	
	if ([controller isKindOfClass:[MacOSaiXWindowController class]] && [self mouse:mouseLoc inRect:[self bounds]])
		[controller selectTileAtPoint:mouseLoc];
}


- (void)drawRect:(NSRect)theRect
{
	NSLog(@"drawRect");
	
	if (originalFade < 1.0)
	{
		originalFade += originalFadeIncrement;
		if (originalFade >= 1.0)
		{
			originalFade = 1.0;
			
			[previousOriginalImage release];
			previousOriginalImage = [[mosaic originalImage] retain];
		}
	}
	
	BOOL	drawLoRes = ([self inLiveResize] || inLiveRedraw || originalFade < 1.0);
	[[NSGraphicsContext currentContext] setImageInterpolation:drawLoRes ? NSImageInterpolationNone : NSImageInterpolationHigh];
	
	NSRect	drawRects[1] = {theRect};
	int		drawRectCount = 1;
	if (NO)	//[self respondsToSelector:@selector(getRectsBeingDrawn:count:)])
		[self getRectsBeingDrawn:(const NSRect **)&drawRects count:&drawRectCount];
	
	NSRect	previousMosaicBounds = (originalFade < 1.0) ? [self boundsForOriginalImage:previousOriginalImage] : NSZeroRect;
	
	NSImage	*originalImage = [mosaic originalImage];
	NSRect	mosaicBounds = [self boundsForOriginalImage:originalImage];
	int		index = 0;
	for (; index < drawRectCount; index++)
	{
		NSRect	drawRect = NSIntersectionRect(drawRects[index], mosaicBounds), 
				drawUnitRect = NSMakeRect((NSMinX(drawRect) - NSMinX(mosaicBounds)) / NSWidth(mosaicBounds), 
										   (NSMinY(drawRect) - NSMinY(mosaicBounds)) / NSHeight(mosaicBounds), 
										   NSWidth(drawRect) / NSWidth(mosaicBounds), 
										   NSHeight(drawRect) / NSHeight(mosaicBounds)), 
				originalRect = NSMakeRect(NSMinX(drawUnitRect) * [originalImage size].width, 
										  NSMinY(drawUnitRect) * [originalImage size].height, 
										  NSWidth(drawUnitRect) * [originalImage size].width,
										  NSHeight(drawUnitRect) * [originalImage size].height), 
				mainImageRect = NSMakeRect(NSMinX(drawUnitRect) * [originalImage size].width, 
										   NSMinY(drawUnitRect) * [originalImage size].height, 
										   NSWidth(drawUnitRect) * [originalImage size].width,
										   NSHeight(drawUnitRect) * [originalImage size].height), 
				previousDrawRect = NSIntersectionRect(drawRects[index], previousMosaicBounds), 
				previousDrawUnitRect = NSMakeRect((NSMinX(previousDrawRect) - NSMinX(previousMosaicBounds)) / NSWidth(previousMosaicBounds), 
												  (NSMinY(previousDrawRect) - NSMinY(previousMosaicBounds)) / NSHeight(previousMosaicBounds), 
												  NSWidth(previousDrawRect) / NSWidth(previousMosaicBounds), 
												  NSHeight(previousDrawRect) / NSHeight(previousMosaicBounds)), 
				previousOriginalRect = NSMakeRect(NSMinX(previousDrawUnitRect) * [previousOriginalImage size].width, 
												  NSMinY(previousDrawUnitRect) * [previousOriginalImage size].height, 
												  NSWidth(previousDrawUnitRect) * [previousOriginalImage size].width,
												  NSHeight(previousDrawUnitRect) * [previousOriginalImage size].height);
		
			// Draw the user selected background.
		switch (backgroundMode)
		{
			case originalMode:
				[originalImage drawInRect:drawRect 
								 fromRect:originalRect 
								operation:NSCompositeSourceOver 
								 fraction:viewFade];
				break;
			case bestMatchMode:
				[backgroundImageLock lock];
					[backgroundImage drawInRect:drawRect 
									   fromRect:mainImageRect 
									  operation:NSCompositeSourceOver 
									   fraction:viewFade];
				[backgroundImageLock unlock];
				break;
			case blackMode:
				[[NSColor colorWithDeviceWhite:0.0 alpha:viewFade] set];
				NSRectFill(drawRect);
				break;
			default:
				;	// TODO: draw a user specified solid color...
		}
		
			// Draw the mosaic itself.
		[mainImageLock lock];
			[mainImage drawInRect:drawRect 
						 fromRect:mainImageRect 
						operation:NSCompositeSourceOver 
						 fraction:viewFade];
		[mainImageLock unlock];
		
			// Overlay the faded original if appropriate and if it's not already there.
		if (viewFade < 1.0 && backgroundMode != originalMode)
		{
			[previousOriginalImage drawInRect:previousDrawRect 
									 fromRect:previousOriginalRect 
									operation:NSCompositeSourceOver 
									 fraction:(1.0 - viewFade) * (1.0 - originalFade)];
			[[mosaic originalImage] drawInRect:drawRect 
									  fromRect:originalRect 
									 operation:NSCompositeSourceOver 
									  fraction:(1.0 - viewFade) * originalFade];
		}
	}
	
		// Highlight the selected image sources.
	[highlightedImageSourcesLock lock];
	if (highlightedImageSourcesOutline)
	{
		NSSize				boundsSize = mosaicBounds.size;
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
	[highlightedImageSourcesLock unlock];
	
		// Highlight the selected tile.
	if (highlightedTile)
	{
			// Draw the tile's outline with a 4pt thick dashed line.
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform scaleXBy:mosaicBounds.size.width yBy:mosaicBounds.size.height];
		NSBezierPath		*bezierPath = [transform transformBezierPath:[highlightedTile outline]];
		[bezierPath setLineWidth:4];
		
		float				dashes[2] = {5.0, 5.0};
		[bezierPath setLineDash:dashes count:2 phase:phase];
		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
		[bezierPath stroke];
		
		[bezierPath setLineDash:dashes count:2 phase:(phase + 5) % 10];
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
		[bezierPath stroke];
		
		// Make sure to draw the tile's outline which gives the animated highlight a 3-D look.
		if (!viewTileOutlines)
		{
			transform = [NSAffineTransform transform];
			[transform translateXBy:0.5 yBy:-0.5];
			[transform scaleXBy:mosaicBounds.size.width yBy:mosaicBounds.size.height];
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];	// darken
			[[transform transformBezierPath:[highlightedTile outline]] stroke];
			
			transform = [NSAffineTransform transform];
			[transform translateXBy:-0.5 yBy:0.5];
			[transform scaleXBy:mosaicBounds.size.width yBy:mosaicBounds.size.height];
			[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];	// lighten
			[[transform transformBezierPath:[highlightedTile outline]] stroke];
		}
	}
	
	if (tilesOutline && viewTileOutlines)
	{
			// Draw the outline of all of the tiles.
			// TODO: make this faster.  This is excruciating for large tile sets.
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform translateXBy:1.5 yBy:0.5];
		[transform scaleXBy:mosaicBounds.size.width yBy:mosaicBounds.size.height];
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];	// darken
		[[transform transformBezierPath:tilesOutline] stroke];
		
		transform = [NSAffineTransform transform];
		[transform translateXBy:0.5 yBy:1.5];
		[transform scaleXBy:mosaicBounds.size.width yBy:mosaicBounds.size.height];
		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];	// lighten
		[[transform transformBezierPath:tilesOutline] stroke];
	}
}


- (void)setInLiveRedraw:(NSNumber *)flag
{
	if (!inLiveRedraw && [flag boolValue])
	{
		inLiveRedraw = YES;
		[self performSelector:_cmd withObject:[NSNumber numberWithBool:NO] afterDelay:0.0];
	}
	else if (inLiveRedraw && ![flag boolValue])
	{
		inLiveRedraw = NO;
		if (originalFade == 1.0)
			[self setNeedsDisplay:YES];
	}
}


- (void)viewDidEndLiveResize
{
	[self setNeedsDisplay:YES];
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
	NSEnumerator	*tileEnumerator = [[mosaic tiles] objectEnumerator];
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
	[highlightedImageSourcesLock lock];
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
	[highlightedImageSourcesLock unlock];
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
	return mainImage;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[mainImage release];
	[mainImageLock release];
	[mainImageTransform release];
	[highlightedImageSources release];
	[highlightedImageSourcesLock release];
	[highlightedImageSourcesOutline release];
	if ([tilesNeedDisplayTimer isValid])
		[tilesNeedDisplayTimer invalidate];
	[tilesNeedDisplayTimer release];
	[tilesNeedingDisplay release];
	[tilesOutline release];
	[tilesToRefresh release];
	[tileMatchTypesToRefresh release];
	[previousOriginalImage release];
	
	[super dealloc];
}


@end

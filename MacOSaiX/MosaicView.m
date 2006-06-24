//
//  MosaicView.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001-2005 Frank M. Midgley.  All rights reserved.
//

#import "MosaicView.h"
#import "MacOSaiXFullScreenWindow.h"
#import "MacOSaiXWindowController.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXTextFieldCell.h"
#import "NSImage+MacOSaiX.h"

#import <Carbon/Carbon.h>
#import <pthread.h>


@interface MosaicView (PrivateMethods)
- (void)originalImageDidChange:(NSNotification *)notification;
- (void)tileShapesDidChange:(NSNotification *)notification;
- (void)updateTileOutlinesImage;
- (void)createHighlightedImageSourcesOutline;
- (NSRect)boundsForOriginalImage:(NSImage *)originalImage;
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
	tilesNeedingDisplay = [[NSMutableArray alloc] init];
	tilesNeedDisplayLock = [[NSLock alloc] init];
	
	highlightedImageSourcesLock = [[NSLock alloc] init];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(windowDidBecomeMain:)
												 name:NSWindowDidBecomeMainNotification 
											   object:[self window]];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(windowDidResignMain:)
												 name:NSWindowDidBecomeMainNotification 
											   object:[self window]];
}


- (void)setMosaic:(MacOSaiXMosaic *)inMosaic
{
    if (inMosaic && mosaic != inMosaic)
	{
		if (mosaic)
			[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:mosaic];
		
		[mosaic autorelease];
		mosaic = [inMosaic retain];
		
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


- (BOOL)isOpaque
{
	return NO;
}


- (void)originalImageDidChange:(NSNotification *)notification
{
	NSImage	*originalImage = [mosaic originalImage];
	
		// Phase out the previous image.
	if (previousOriginalImage && originalImage != previousOriginalImage)
	{
		[originalFadeStartTime release];
		originalFadeStartTime = [[NSDate alloc] init];
		if ([originalFadeTimer isValid])
			[originalFadeTimer invalidate];
		[originalFadeTimer release];
		originalFadeTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1 
															  target:self 
															selector:@selector(completeFadeToNewOriginalImage:) 
															userInfo:nil 
															 repeats:YES] retain];
		
			// De-queue any pending tile refreshes for the previous original image.
		[tilesNeedDisplayLock lock];
			[tilesNeedingDisplay removeAllObjects];
		[tilesNeedDisplayLock unlock];
	}
	
		// Phase in the new image.
	if (!originalImage || originalImage != previousOriginalImage)
	{
			// Pick a size for the main and background images.
			// (somewhat arbitrary but large enough for decent zooming)
		float	bitmapSize = 10.0 * 1024.0 * 1024.0;
		mainImageSize.width = floorf(sqrtf([mosaic aspectRatio] * bitmapSize));
		mainImageSize.height = floorf(bitmapSize / mainImageSize.width);
		
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
		
		if (viewTileOutlines)
			[self updateTileOutlinesImage];
	}
}


- (void)setOriginalFadeTime:(float)seconds
{
	originalFadeTime = seconds;
}


- (void)completeFadeToNewOriginalImage:(NSTimer *)timer
{
	if (!originalFadeStartTime || [[NSDate date] timeIntervalSinceDate:originalFadeStartTime] > originalFadeTime)
	{
		[timer invalidate];
		
		if (timer == originalFadeTimer)
		{
			[originalFadeTimer release];
			originalFadeTimer = nil;
			[self setNeedsDisplay:YES];
		}
	}
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
	[tileRefreshLock lock];
		[tilesToRefresh removeAllObjects];
		[tileMatchTypesToRefresh removeAllObjects];
	[tileRefreshLock unlock];
	
	[mainImageLock lock];
		if (mainImage)
		{
			[mainImage lockFocus];
				[[NSColor clearColor] set];
				NSRectFill(NSMakeRect(0.0, 0.0, [mainImage size].width, [mainImage size].height));
			[mainImage unlockFocus];
		}
	[mainImageLock unlock];
	
	[backgroundImageLock lock];
		if (backgroundImage)
		{
			[backgroundImage lockFocus];
				[[NSColor clearColor] set];
				NSRectFill(NSMakeRect(0.0, 0.0, [backgroundImage size].width, [backgroundImage size].height));
			[backgroundImage unlockFocus];
		}
	[backgroundImageLock unlock];
	
	if (viewTileOutlines)
		[self updateTileOutlinesImage];
	
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
					
					if (backgroundMode == bestMatchMode && redrawBackground)
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
	} while ([self window] && tileToRefresh);
	
	[tileRefreshLock lock];
		if ([tilesToRedraw count] > 0)
			[self performSelector:@selector(redrawTiles:) withObject:[NSArray arrayWithArray:tilesToRedraw]];
//			[self performSelectorOnMainThread:@selector(redrawTiles:) 
//								   withObject:[NSArray arrayWithArray:tilesToRedraw] 
//								waitUntilDone:NO];
		refreshingTiles = NO;
	[tileRefreshLock unlock];
	
	[pool release];
	
}


- (void)redrawTiles:(NSArray *)tilesToRedraw
{
	NSEnumerator	*tileDictEnumerator = [tilesToRedraw objectEnumerator];
	NSDictionary	*tileDict = nil;
	
	while (mosaic && (tileDict = [tileDictEnumerator nextObject]))
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
						#ifdef DEBUG
							NSLog(@"Could not lock focus on mosaic image");
						#endif
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
						#ifdef DEBUG
							NSLog(@"Could not lock focus on non-unique image");
						#endif
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
			[self performSelectorOnMainThread:@selector(startNeedsDisplayTimer) withObject:nil waitUntilDone:NO];
	[tilesNeedDisplayLock unlock];
}


- (void)startNeedsDisplayTimer
{
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
	NSRect				mosaicBounds = [self boundsForOriginalImage:[mosaic originalImage]];
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:NSMinX(mosaicBounds) yBy:NSMinY(mosaicBounds)];
	[transform scaleXBy:NSWidth(mosaicBounds) yBy:NSHeight(mosaicBounds)];
	
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


- (void)updateTileOutlinesImage
{
	NSEnumerator		*tileEnumerator = nil;
	MacOSaiXTile		*tile = nil;
	NSAffineTransform	*darkenTransform = [NSAffineTransform transform], 
						*lightenTransform = [NSAffineTransform transform];
	
	[darkenTransform translateXBy:1.0 yBy:-1.0];
	[darkenTransform scaleXBy:mainImageSize.width yBy:mainImageSize.height];
	[lightenTransform translateXBy:0.0 yBy:0.0];
	[lightenTransform scaleXBy:mainImageSize.width yBy:mainImageSize.height];
	
	[tileOutlinesImage release];
	tileOutlinesImage = [[NSImage alloc] initWithSize:mainImageSize];
	[tileOutlinesImage lockFocus];
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];	// darken
		tileEnumerator = [[mosaic tiles] objectEnumerator];
		while (tile = [tileEnumerator nextObject])
		{
			NSBezierPath	*transformedPath = [darkenTransform transformBezierPath:[tile outline]];
			[transformedPath setLineWidth:3.0];
			[transformedPath stroke];
		}
		
		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];	// lighten
		tileEnumerator = [[mosaic tiles] objectEnumerator];
		while (tile = [tileEnumerator nextObject])
		{
			NSBezierPath	*transformedPath = [lightenTransform transformBezierPath:[tile outline]];
			[transformedPath setLineWidth:3.0];
			[transformedPath stroke];
		}
		[tileOutlinesImage unlockFocus];
}


- (void)setViewTileOutlines:(BOOL)inViewTileOutlines
{
	if (inViewTileOutlines != viewTileOutlines)
	{
		viewTileOutlines = inViewTileOutlines;
		
		if (viewTileOutlines)
			[self updateTileOutlinesImage];
		else
		{
			[tileOutlinesImage release];
			tileOutlinesImage = nil;
		}
		
		[self setNeedsDisplay:YES];
	}
	
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
		
		if (mode == bestMatchMode)
		{
				// Queue the refresh of all tiles that don't have an image in the main layer.
			NSEnumerator	*tileEnumerator = [[mosaic tiles] objectEnumerator];
			MacOSaiXTile	*tile = nil;
			while (tile = [tileEnumerator nextObject])
				if (![tile userChosenImageMatch] && ![tile uniqueImageMatch])
					[self refreshTile:[NSDictionary dictionaryWithObjectsAndKeys:
											tile, @"Tile", 
											@"Best", @"Match Type", 
											nil]];
		}
		else if (backgroundImage)
		{
				// Get rid of the memory consuming background image since it's no longer needed.
				// A new one will be created if the mode is switched back to best match.
				// TODO: do this after a 10-15 second delay in case the user switches back.
			[backgroundImageLock lock];
				[backgroundImage autorelease];
				backgroundImage = nil;
			[backgroundImageLock unlock];
		}
		
		[self setNeedsDisplay:YES];
	}
}


- (MacOSaiXBackgroundMode)backgroundMode
{
	return backgroundMode;
}


- (MacOSaiXTile *)tileAtPoint:(NSPoint)thePoint
{
		// Convert the point to the unit square system that the tile outlines are in.
    thePoint.x = thePoint.x / [self frame].size.width;
    thePoint.y = thePoint.y / [self frame].size.height;
    
		// TBD: this isn't terribly efficient...
	NSEnumerator	*tileEnumerator = [[mosaic tiles] objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
        if ([[tile outline] containsPoint:thePoint])
			break;
	
	return tile;
}


- (NSRect)boundsForOriginalImage:(NSImage *)originalImage
{
	NSRect	viewBounds = [self bounds],
			mosaicBounds = viewBounds;
	NSSize	imageSize = [originalImage size];
	
	if ((NSWidth(viewBounds) / imageSize.width) < (NSHeight(viewBounds) / imageSize.height))
	{
		mosaicBounds.size.height = imageSize.height * NSWidth(viewBounds) / imageSize.width;
		mosaicBounds.origin.y = (NSHeight(viewBounds) - NSHeight(mosaicBounds)) / 2.0;
	}
	else
	{
		mosaicBounds.size.width = imageSize.width * NSHeight(viewBounds) / imageSize.height;
		mosaicBounds.origin.x = (NSWidth(viewBounds) - NSWidth(mosaicBounds)) / 2.0;
	}
	
	return mosaicBounds;
}


- (void)drawRect:(NSRect)theRect
{
	float	originalFade = 1.0;
	if (originalFadeStartTime)
	{
		originalFade = ([[NSDate date] timeIntervalSinceDate:originalFadeStartTime] / originalFadeTime);
		if (originalFade > 1.0)
			originalFade = 1.0;
	}
	if (originalFade == 1.0)
	{
		[previousOriginalImage release];
		previousOriginalImage = [[mosaic originalImage] retain];
		[originalFadeStartTime release];
		originalFadeStartTime = nil;
	}
	
	BOOL	drawLoRes = ([self inLiveResize] || inLiveRedraw || originalFade < 1.0);
	[[NSGraphicsContext currentContext] setImageInterpolation:drawLoRes ? NSImageInterpolationNone : NSImageInterpolationHigh];
	
		// Get the list of rectangles that need to be redrawn.
		// Especially when !drawLoRes the image rendering is expensive so the less done the better.
	NSRect			fallbackDrawRects[1] = { theRect };
	const NSRect	*drawRects = nil;
	int				drawRectCount = 0;
	if ([self respondsToSelector:@selector(getRectsBeingDrawn:count:)])
		[self getRectsBeingDrawn:&drawRects count:&drawRectCount];
	else
	{
		drawRects = fallbackDrawRects;
		drawRectCount = 1;
	}
	
	NSImage	*originalImage = [mosaic originalImage];
	NSRect	mosaicBounds = [self boundsForOriginalImage:originalImage], 
			previousMosaicBounds = (originalFade < 1.0) ? [self boundsForOriginalImage:previousOriginalImage] : NSZeroRect;
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
				mainImageRect = NSMakeRect(NSMinX(drawUnitRect) * mainImageSize.width, 
										   NSMinY(drawUnitRect) * mainImageSize.height, 
										   NSWidth(drawUnitRect) * mainImageSize.width,
										   NSHeight(drawUnitRect) * mainImageSize.height), 
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
		
		if (viewTileOutlines && !drawLoRes)
			[tileOutlinesImage drawInRect:drawRect 
								 fromRect:mainImageRect 
								operation:NSCompositeSourceOver 
								 fraction:1.0];
		
	}
	
		// Highlight the selected image sources.
	[highlightedImageSourcesLock lock];
	if (highlightedImageSourcesOutline && !drawLoRes)
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
		float	minX = NSMinX(mosaicBounds), 
				minY = NSMinY(mosaicBounds), 
				width = NSWidth(mosaicBounds), 
				height = NSHeight(mosaicBounds);
		
			// Draw the tile's outline with a 4pt thick dashed line.
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform translateXBy:minX yBy:minY];
		[transform scaleXBy:width yBy:height];
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
			[transform translateXBy:minX + 0.5 yBy:minY - 0.5];
			[transform scaleXBy:width yBy:height];
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];	// darken
			[[transform transformBezierPath:[highlightedTile outline]] stroke];
			
			transform = [NSAffineTransform transform];
			[transform translateXBy:minX - 0.5 yBy:minY + 0.5];
			[transform scaleXBy:width yBy:height];
			[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];	// lighten
			[[transform transformBezierPath:[highlightedTile outline]] stroke];
		}
	}
}


- (void)setInLiveRedraw:(NSNumber *)flag
{
	if (!inLiveRedraw && [flag boolValue])
		inLiveRedraw = YES;
	else if (inLiveRedraw && ![flag boolValue])
	{
		inLiveRedraw = NO;
		[self setNeedsDisplay:YES];
	}
}


- (void)viewDidEndLiveResize
{
	[self setNeedsDisplay:YES];
}


- (void)loadNib
{
	[NSBundle loadNibNamed:@"Mosaic View" owner:self];
	
	NSWindow	*nibWindow = tooltipWindow;
	tooltipWindow = [[MacOSaiXFullScreenWindow alloc] initWithContentRect:[nibWindow contentRectForFrameRect:[nibWindow frame]] 
																styleMask:NSBorderlessWindowMask 
																  backing:NSBackingStoreBuffered 
																	defer:NO 
																   screen:[nibWindow screen]];
	[tooltipWindow setContentView:[nibWindow contentView]];
	[nibWindow release];
	
	[imageSourceTextField setCell:[[[MacOSaiXTextFieldCell alloc] initTextCell:@""] autorelease]];
}


#pragma mark -
#pragma mark Tooltip methods


- (void)hideTooltip
{
	if ([tooltipWindow screen] && !tooltipHideTimer)
		tooltipHideTimer = [[NSTimer scheduledTimerWithTimeInterval:0.05 
															 target:self 
														   selector:@selector(animateHidingOfTooltip:) 
														   userInfo:[NSMutableString string] 
															repeats:YES] retain];
}


- (void)animateHidingOfTooltip:(NSTimer *)timer
{
	NSMutableString	*state = [timer userInfo];
	
	if ([state length] < 10)
	{
		[tooltipWindow setAlphaValue:1.0 - [state length] / 10.0];
		[state appendString:@"*"];
	}
	else
	{
		[tooltipHideTimer invalidate];
		[tooltipHideTimer release];
		tooltipHideTimer = nil;
		[tooltipWindow orderOut:self];
	}
}


- (void)setTooltipsEnabled:(BOOL)enabled
{
	if (enabled && !tooltipTimer)
	{
		//NSLog(@"Enabling tooltips");
		tooltipTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1 
														 target:self 
													   selector:@selector(updateTooltip:) 
													   userInfo:nil 
														repeats:YES] retain];
	}
	else if (!enabled)
	{
		//NSLog(@"Disabling tooltips");
		
		[tooltipTimer invalidate];
		[tooltipTimer release];
		tooltipTimer = nil;
		
		tooltipTile = nil;
		
		[self hideTooltip];
	}
}


- (void)updateTooltip:(NSTimer *)timer
{
	if (tooltipTile || GetCurrentEventTime() > [[[self window] currentEvent] timestamp] + 1)
	{
		NSPoint					screenPoint = [NSEvent mouseLocation],
								windowPoint = [[self window] convertScreenToBase:screenPoint];
		MacOSaiXTile			*tile = [self tileAtPoint:[self convertPoint:windowPoint fromView:nil]];
		
		if (tile != tooltipTile)
		{
			tooltipTile = tile;
			
			if (!tooltipWindow)
				[self loadNib];
			
				// Fill in the details for the tile under the mouse.
			MacOSaiXImageMatch		*imageMatch = [tile userChosenImageMatch];
			if (!imageMatch)
				imageMatch = [tile uniqueImageMatch];
			if (!imageMatch && backgroundMode == bestMatchMode)
				imageMatch = [tile bestImageMatch];
			
			if (imageMatch)
			{
				NSPoint point = NSMakePoint(screenPoint.x, screenPoint.y - 20.0);
				if (point.y < NSHeight([tooltipWindow frame]))
					point.y = screenPoint.y + NSHeight([tooltipWindow frame]) + 20.0;
				[tooltipWindow setFrameTopLeftPoint:point];
				
				id<MacOSaiXImageSource>	imageSource = [imageMatch imageSource];
				NSImage					*sourceImage = [[[imageSource image] copy] autorelease];
				[sourceImage setScalesWhenResized:YES];
				[sourceImage setSize:NSMakeSize(32.0, 32.0 * [sourceImage size].height / [sourceImage size].width)];
				[imageSourceImageView setImage:sourceImage];
				
				id						sourceDescription = [imageSource descriptor];
				if ([sourceDescription isKindOfClass:[NSAttributedString class]])
					[imageSourceTextField setAttributedStringValue:sourceDescription];
				else if ([sourceDescription isKindOfClass:[NSString class]])
					[imageSourceTextField setStringValue:sourceDescription];
				else
				{
					NSString	*genericDescription = [(id)[imageSource class] name];
					[imageSourceTextField setStringValue:(genericDescription ? genericDescription : @"")];
				}
				
				[tooltipHideTimer invalidate];
				[tooltipHideTimer release];
				tooltipHideTimer = nil;
				
				[tileImageView setImage:nil];
				[tileImageTextField setStringValue:@"Fetching..."];
				[tooltipWindow setAlphaValue:1.0];
				[tooltipWindow orderFront:self];
				
				[NSThread detachNewThreadSelector:@selector(updateTooltipWindowForImageMatch:) 
										 toTarget:self 
									   withObject:imageMatch];
			}
			else //if ([tooltipWindow orderedIndex] != NSNotFound)
				[self hideTooltip];
		}
	}
}


- (void)updateTooltipWindowForImageMatch:(id)parameter
{
	if (!pthread_main_np())
	{
		NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
		
		MacOSaiXImageMatch		*imageMatch = parameter;
		id<MacOSaiXImageSource>	imageSource = [imageMatch imageSource];
		NSString				*identifier = [imageMatch imageIdentifier];
		NSBitmapImageRep		*imageRep = [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:NSZeroSize 
																					forIdentifier:identifier 
																					   fromSource:imageSource];
		NSImage					*image = [[NSImage alloc] initWithSize:[imageRep size]];
		NSString				*imageDescription = (image ? [imageSource descriptionForIdentifier:identifier] : nil);
		
		[image addRepresentation:imageRep];
		[self performSelectorOnMainThread:_cmd 
							   withObject:[NSDictionary dictionaryWithObjectsAndKeys:
											   imageMatch, @"Image Match", 
											   image, @"Image", 
											   imageDescription, @"Image Description", 
											   nil]
							waitUntilDone:NO];
		
		[image release];
		[pool release];
	}
	else
	{
		NSDictionary		*parameters = parameter;
		MacOSaiXImageMatch	*imageMatch = [parameters objectForKey:@"Image Match"];
		
			// Only update the tooltip window if the mouse is still over the same tile.
		if ([imageMatch tile] == tooltipTile)
		{
			NSImage			*image = [parameters objectForKey:@"Image"];
			
			if (image)
			{
				image = [[image copyWithLargestDimension:256.0] autorelease];
				
				float		widthDiff = [image size].width - NSWidth([tileImageView frame]), 
							heightDiff = [image size].height - NSHeight([tileImageView frame]);
				[tileImageView setImage:image];
				
				NSString	*imageDescription = [parameters objectForKey:@"Image Description"];
				if (imageDescription)
					[tileImageTextField setStringValue:imageDescription];
				else
					[tileImageTextField setStringValue:@""];
				
				NSRect		frameRect = [tooltipWindow frame];
				if (NSMinY(frameRect) > NSHeight(frameRect) + 20.0)
					frameRect.origin.y -= heightDiff;
				frameRect.size.width += widthDiff;
				frameRect.size.height += heightDiff;
				[tooltipWindow setFrame:frameRect display:YES animate:YES];
			}
			else
				;	// TBD
		}
	}
}


#pragma mark -
#pragma mark Highlight methods


- (void)setHighlightedTile:(MacOSaiXTile *)tile
{
	NSRect				mosaicBounds = [self boundsForOriginalImage:[mosaic originalImage]];
    NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:NSMinX(mosaicBounds) yBy:NSMinY(mosaicBounds)];
	[transform scaleXBy:NSWidth(mosaicBounds) yBy:NSHeight(mosaicBounds)];
	
    if (highlightedTile)
    {
			// Mark the previously highlighted area for re-display.
		NSBezierPath		*bezierPath = [transform transformBezierPath:[highlightedTile outline]];
		[self setNeedsDisplayInRect:NSInsetRect([bezierPath bounds], -2.0, -2.0)];
	}
	
	[highlightedTile autorelease];
	highlightedTile = [tile retain];
	
    if (highlightedTile)
    {
			// Mark the newly highlighted area for re-display.
		NSBezierPath		*bezierPath = [transform transformBezierPath:[highlightedTile outline]];
		[self setNeedsDisplayInRect:NSInsetRect([bezierPath bounds], -2.0, -2.0)];
	}
}


- (MacOSaiXTile *)highlightedTile
{
	return highlightedTile;
}


- (void)createHighlightedImageSourcesOutline
{
	NSEnumerator	*tileEnumerator = [[mosaic tiles] objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
	{
		id<MacOSaiXImageSource>	displayedSource = [[tile userChosenImageMatch] imageSource];
		if (!displayedSource)
			displayedSource = [[tile uniqueImageMatch] imageSource];
		if (!displayedSource && backgroundMode == bestMatchMode)
			displayedSource = [[tile bestImageMatch] imageSource];
		
		if (displayedSource && [highlightedImageSources containsObject:displayedSource])
		{
			if (!highlightedImageSourcesOutline)
				highlightedImageSourcesOutline = [[NSBezierPath bezierPath] retain];
			[highlightedImageSourcesOutline appendBezierPath:[tile outline]];
		}
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


- (void)animateHighlightedTile:(NSTimer *)timer
{
    phase = ++phase % 10;
	
	NSRect				mosaicBounds = [self boundsForOriginalImage:[mosaic originalImage]];
    NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:NSMinX(mosaicBounds) yBy:NSMinY(mosaicBounds)];
	[transform scaleXBy:NSWidth(mosaicBounds) yBy:NSHeight(mosaicBounds)];
    NSBezierPath		*bezierPath = [transform transformBezierPath:[highlightedTile outline]];

    [self setNeedsDisplayInRect:NSInsetRect([bezierPath bounds], -2.0, -2.0)];
}


#pragma mark -


- (NSImage *)image
{
	return mainImage;
}


- (void)mouseDown:(NSEvent *)theEvent
{
	if (tooltipTile)
	{
		[self hideTooltip];
		tooltipTile = nil;
	}
	
	MacOSaiXTile	*clickedTile = [self tileAtPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
	
	if ([theEvent clickCount] == 1)
	{
			// Change the selection.
		if (clickedTile == highlightedTile)
		{
			[self setHighlightedTile:nil];
			
				// Get rid of the timer when no tile is selected.
			[animateHighlightedTileTimer invalidate];
			[animateHighlightedTileTimer release];
			animateHighlightedTileTimer = nil;
		}
		else
		{
			[self setHighlightedTile:clickedTile];
			
			if (!animateHighlightedTileTimer)
			{
					// Create a timer to animate the selected tile ten times per second.
				animateHighlightedTileTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1
																				target:(id)self
																			  selector:@selector(animateHighlightedTile:)
																			  userInfo:nil
																			   repeats:YES] retain];
			}
		}
	}
	else if ([theEvent clickCount] == 2)
	{
			// Edit the tile.
		[self setHighlightedTile:clickedTile];
		
		MacOSaiXWindowController	*controller = [[self window] windowController];
		if ([controller isKindOfClass:[MacOSaiXWindowController class]])
			[controller chooseImageForSelectedTile:self];
	}
}


- (void)mouseEntered:(NSEvent *)event
{
	[self setTooltipsEnabled:YES];
}


- (void)mouseExited:(NSEvent *)event
{
	[self setTooltipsEnabled:NO];
}


- (void)viewDidMoveToWindow
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeMainNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignMainNotification object:nil];
	
	if ([self window])
	{
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(windowDidBecomeMain:)
													 name:NSWindowDidBecomeMainNotification 
												   object:[self window]];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(windowDidResignMain:)
													 name:NSWindowDidBecomeMainNotification 
												   object:[self window]];
	}
}


- (void)windowDidBecomeMain:(NSNotification *)notification
{
	NSPoint	windowPoint = [[self window] convertScreenToBase:[NSEvent mouseLocation]];
	
	if (NSPointInRect([self convertPoint:windowPoint fromView:nil], [self bounds]))
		[self setTooltipsEnabled:YES];
}


- (void)windowDidResignMain:(NSNotification *)notification
{
	[self setTooltipsEnabled:NO];
}


- (NSMenu *)menuForEvent:(NSEvent *)event;
{
	[self setHighlightedTile:[self tileAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]]];
	
	if (!contextualMenu)
		[self loadNib];
	
	return contextualMenu;
}


- (BOOL)validateMenuItem:(NSMenuItem *)item
{
//	if ([item menu] == contextualMenu)
		return YES;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
//	[self tileShapesDidChange:nil];
	
	if ([originalFadeTimer isValid])
		[originalFadeTimer invalidate];
	[originalFadeTimer release];
	
	[self setTooltipsEnabled:NO];
	
	[mainImage release];
	[mainImageLock release];
	[mainImageTransform release];
	[backgroundImage release];
	[backgroundImageLock release];
	[tileOutlinesImage release];
	[highlightedImageSources release];
	[highlightedImageSourcesLock release];
	[highlightedImageSourcesOutline release];
	[contextualMenu release];
	if ([tilesNeedDisplayTimer isValid])
		[tilesNeedDisplayTimer invalidate];
	[tilesNeedDisplayTimer release];
	[tilesNeedingDisplay release];
	[tilesToRefresh release];
	[tileMatchTypesToRefresh release];
	[previousOriginalImage release];

	[mosaic release];
	mosaic = nil;

	[super dealloc];
}


@end

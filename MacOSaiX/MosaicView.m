//
//  MosaicView.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001-2005 Frank M. Midgley.  All rights reserved.
//

#import "MosaicView.h"

#import "MacOSaiXAnimationSettingsController.h"
#import "MacOSaiXWindowController.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXSourceImage.h"
#import "NSBezierPath+MacOSaiX.h"
#import "NSImage+MacOSaiX.h"

#import <pthread.h>


#define REDRAW_ON_MAIN_THREAD 1


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
		
		imagePlacementLock = [[NSLock alloc] init];
		imagePlacementLastTime = [[NSDate date] retain];
		
		mainImageLock = [[NSLock alloc] init];
		backgroundImageLock = [[NSLock alloc] init];
		tilesNeedingDisplay = [[NSMutableArray alloc] init];
		tilesNeedDisplayLock = [[NSLock alloc] init];
		
		highlightedImageSourcesLock = [[NSLock alloc] init];
	}
	
	return self;
}


- (void)setMosaic:(MacOSaiXMosaic *)inMosaic
{
    if (mosaic != inMosaic)
	{
		if (mosaic)
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:mosaic];
			
			[tileRefreshLock lock];
				[tilesToRefresh removeAllObjects];
			[tileRefreshLock unlock];
			
			while (refreshingTiles)
				[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		}
		
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
													 selector:@selector(imageSourcesDidChange:) 
														 name:MacOSaiXMosaicDidChangeImageSourcesNotification 
													   object:mosaic];
			[[NSNotificationCenter defaultCenter] addObserver:self 
													 selector:@selector(imageWasPlacedInMosaic:) 
														 name:MacOSaiXImageWasPlacedInMosaicNotification 
													   object:mosaic];
			[[NSNotificationCenter defaultCenter] addObserver:self 
													 selector:@selector(tileImageDidChange:) 
														 name:MacOSaiXTileImageDidChangeNotification 
													   object:mosaic];
			[[NSNotificationCenter defaultCenter] addObserver:self 
													 selector:@selector(mosaicDidExtractTileBitmaps:) 
														 name:MacOSaiXMosaicDidExtractTileBitmapsNotification 
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


- (void)resetMainAndBackgroundImages
{
		// Pick a size for the main and background images.
		// (somewhat arbitrary but large enough for decent zooming)
	NSImage	*originalImage = [mosaic originalImage];
	
	if (originalImage)
	{
		float	aspectRatio = [originalImage size].width / [originalImage size].height, 
				maxSize = 3200.0;	//([mosaic averageUnitTileSize].width > 0.01 ? 1600.0 : 3200.0);
		mainImageSize = (aspectRatio > 1.0 ? NSMakeSize(maxSize, round(maxSize / aspectRatio)) : 
						 NSMakeSize(round(maxSize * aspectRatio), maxSize));
		
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


- (void)originalImageDidChange:(NSNotification *)notification
{
	NSImage	*originalImage = [mosaic originalImage];
	
	if (originalImage != previousOriginalImage)
	{
		if (originalImage)
		{
			[originalFadeStartTime autorelease];
			originalFadeStartTime = [[NSDate alloc] init];
			[NSTimer scheduledTimerWithTimeInterval:0.1 
											 target:self 
										   selector:@selector(completeFadeToNewOriginalImage:) 
										   userInfo:nil 
											repeats:YES];
		}
		
			// De-queue any pending tile refreshes based on the previous original image.
		[tilesNeedDisplayLock lock];
			[tilesNeedingDisplay removeAllObjects];
		[tilesNeedDisplayLock unlock];
		
		if (originalImage)
			[self resetMainAndBackgroundImages];
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
		
		[self setNeedsDisplay:YES];
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
    // De-queue any pending tile refreshes based on the previous original image and tiles.
    [tilesNeedDisplayLock lock];
        [tilesNeedingDisplay removeAllObjects];
    [tilesNeedDisplayLock unlock];
    
    [self resetMainAndBackgroundImages];
	
		// TBD: main thread?
	[self setNeedsDisplay:YES];
}


- (void)imageSourcesDidChange:(NSNotification *)notification
{
	if ([[mosaic imageSources] count] == 0)
	{
		// Don't bother erasing every tile, just nuke the whole thing.
		
		[tileRefreshLock lock];
			[tilesToRefresh removeAllObjects];
			[tileMatchTypesToRefresh removeAllObjects];
		[tileRefreshLock unlock];
		
		[self resetMainAndBackgroundImages];
		
			// TBD: main thread?
		[self setNeedsDisplay:YES];
	}
}


#pragma mark -
#pragma mark New image placement


- (void)imageWasPlacedInMosaic:(NSNotification *)notification
{
	[imagePlacementLock lock];
	
	NSTimeInterval	timeSinceLastPlacement = -[imagePlacementLastTime timeIntervalSinceNow];
	BOOL			imageWasHandPicked = [[[notification userInfo] objectForKey:@"Handpicked"] boolValue],
					placeThisImage = (imageWasHandPicked || (![mosaic isPausing] && ((!imagePlacementStartTime && timeSinceLastPlacement > [mosaic delayBetweenImagePlacements]) || [mosaic animateAllImagePlacements])));
	
	[imagePlacementLock unlock];
	
	if (placeThisImage)
	{
		MacOSaiXSourceImage	*sourceImage = [[notification userInfo] objectForKey:@"Source Image"];
		if (sourceImage)
		{
			NSImageRep			*imageRep = [sourceImage imageRepAtSize:NSZeroSize];
			
			if ([mosaic animateAllImagePlacements])
			{
					// Wait for the current placement to complete.  This intentionally blocks the "calculate matches" thread.
				while (![mosaic isPausing] && (imagePlacementStartTime || timeSinceLastPlacement < [mosaic delayBetweenImagePlacements]))
				{
					[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
					[imagePlacementLock lock];
						timeSinceLastPlacement = -[imagePlacementLastTime timeIntervalSinceNow];
					[imagePlacementLock unlock];
				}
			}
			
			if (imageWasHandPicked || (![mosaic isPausing] && ![mosaic isPaused]))
			{
					// Grab the description before locking in case the plug-in messages the main thread.
				NSString	*description = [sourceImage description];
				if (!description)
				{
					NSBundle	*plugInBundle = [NSBundle bundleForClass:[[sourceImage source] class]];
					NSString	*imageSourceClassName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
					description = [[NSString stringWithFormat:NSLocalizedString(@"%@ Image", @"<image source type> Image"), imageSourceClassName] retain];
				}
				NSImage		*imageSourceImage = [[sourceImage source] image];
				
				[imagePlacementLock lock];
					[imagePlacementTiles release];
					imagePlacementTiles = [[[notification userInfo] objectForKey:@"Tiles"] retain];
					if ([imagePlacementTiles count] > 16)
						[imagePlacementTiles removeObjectsInRange:NSMakeRange(16, [imagePlacementTiles count] - 16)];
					[imagePlacementImage release];
					imagePlacementImage = [[NSImage alloc] initWithSize:NSMakeSize([imageRep pixelsWide], [imageRep pixelsHigh])];
					[imagePlacementImage addRepresentation:imageRep];
					imagePlacementDescription = [description copy];
					if ([mosaic includeSourceImageWithImagePlacementMessage])
						imagePlacementSourceImage = [imageSourceImage retain];
					imagePlacementStartTime = [[NSDate date] retain];
				[imagePlacementLock unlock];
				
				[self performSelectorOnMainThread:@selector(animateImagePlacement) withObject:nil waitUntilDone:NO];
			}
		}
	}
}


- (void)animateImagePlacement
{
	[self setNeedsDisplay:YES];
}


#pragma mark -
#pragma mark Tile image changes


- (void)mosaicDidExtractTileBitmaps:(NSNotification *)notification
{
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
		unsigned long	index= [tilesToRefresh indexOfObject:tile];
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
	
		// Don't allow non-thread safe QuickTime component access on this thread.
	CSSetComponentsThreadMode(kCSAcceptThreadSafeComponentsOnlyMode);
	
	do
	{
		NSAutoreleasePool	*innerPool = [[NSAutoreleasePool alloc] init];
		
		// Don't update the main image while an image is being placed to make the animation smoother.
		BOOL				placingImage = NO;
		do
		{
			[imagePlacementLock lock];
				placingImage = (imagePlacementStartTime != nil);
			[imagePlacementLock unlock];
			
			if (placingImage)
				[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		} while (placingImage);
		
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
					
					mainImageRep = [[mainImageMatch sourceImage] imageRepAtSize:[clipPath bounds].size];
				}
				
					// If no image will be displayed for the tile in the main layer then 
					// the background layer may need to be redrawn.
				if (redrawMain && !mainImageMatch)
					redrawBackground = YES;
				
					// TODO: background should not be redrawn if all tiles have a unique match.
				if (backgroundMode == bestMatchMode && redrawBackground && backgroundImageMatch)
					backgroundImageRep = [[backgroundImageMatch sourceImage] imageRepAtSize:[clipPath bounds].size];
				
				[tileRefreshLock lock];
					if (redrawMain)
					{
						[tilesToRedraw addObject:[NSDictionary dictionaryWithObjectsAndKeys:
														@"Main", @"Layer", 
														tileToRefresh, @"Tile", 
														[mainImageMatch sourceImage], @"Source Image", 
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
						#if REDRAW_ON_MAIN_THREAD
							[self performSelectorOnMainThread:@selector(redrawTiles:) 
												   withObject:[NSArray arrayWithArray:tilesToRedraw] 
												waitUntilDone:NO];
						#else
							[self performSelector:@selector(redrawTiles:) withObject:tilesToRedraw];
						#endif
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
		{
			#if REDRAW_ON_MAIN_THREAD
				[self performSelectorOnMainThread:@selector(redrawTiles:) 
									   withObject:[NSArray arrayWithArray:tilesToRedraw] 
									waitUntilDone:NO];
			#else
				[self performSelector:@selector(redrawTiles:) withObject:tilesToRedraw];
			#endif
		}
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
						#ifdef DEBUG
							NSLog(@"Could not lock focus on mosaic image");
						#endif
					NS_ENDHANDLER
				}
			[mainImageLock unlock];
				
			// TODO: -[QTMovie addImage:forDuration:withAttributes] (or maybe add it to a track)
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
			
			// TODO: -[QTMovie addImage:forDuration:withAttributes] (or maybe add it to a track)
		}
		
		[tilesNeedDisplayLock lock];
			[tilesNeedingDisplay addObject:tile];
		[tilesNeedDisplayLock unlock];
	}
	
	[self performSelectorOnMainThread:@selector(startNeedsDisplayTimer) withObject:nil waitUntilDone:NO];
}


- (void)startNeedsDisplayTimer
{
		// Don't force a refresh every time we update the mosaic but make sure it gets refreshed at least 2 times a second.
//	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(setTilesNeedDisplay) object:nil];
	[self performSelector:@selector(setTilesNeedDisplay) withObject:nil afterDelay:0.5];
}


- (void)setTilesNeedDisplay
{
	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(setTilesNeedDisplay) object:nil];
	
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
	[tilesNeedDisplayLock unlock];
}


#pragma mark -


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


- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint						mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	MacOSaiXWindowController	*controller = [[self window] delegate];
	
	if ([controller isKindOfClass:[MacOSaiXWindowController class]] && [self mouse:mouseLoc inRect:[self bounds]])
		[controller selectTileAtPoint:mouseLoc];
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
	if (!mosaic)
		return;
	
	float	originalFade = 1.0;
	if (originalFadeStartTime)
	{
		originalFade = ([[NSDate date] timeIntervalSinceDate:originalFadeStartTime] / originalFadeTime);
		if (originalFade > 1.0)
			originalFade = 1.0;
	
		if (originalFade == 1.0)
		{
			[previousOriginalImage release];
			previousOriginalImage = [[mosaic originalImage] retain];
			[originalFadeStartTime release];
			originalFadeStartTime = nil;
		}
	}
	
	BOOL	drawLoRes = ([self inLiveResize] || inLiveRedraw || originalFade < 1.0);
//	[imagePlacementLock lock];
//		if (imagePlacementStartTime && -[imagePlacementStartTime timeIntervalSinceNow] > [mosaic imagePlacementFullSizedDuration])
//			drawLoRes = YES;
//	[imagePlacementLock unlock];
	[[NSGraphicsContext currentContext] setImageInterpolation:drawLoRes ? NSImageInterpolationNone : NSImageInterpolationHigh];
	
		// Get the list of rectangles that need to be redrawn.
		// Especially when !drawLoRes the image rendering is expensive so the less done the better.
	NSRect			fallbackDrawRects[1] = { theRect };
	const NSRect	*drawRects = nil;
	long			drawRectCount = 0;
	if ([self respondsToSelector:@selector(getRectsBeingDrawn:count:)])
	{
		[self getRectsBeingDrawn:&drawRects count:&drawRectCount];
		// unlimited -> 48.7%	51.3%
		//        32 -> 21.4%	21.3%
		//        16 -> 21.3%	
		//         8 -> 21.4%	21.4/17.7%
		//         4 -> 21.5%
		//         1 -> 21.4%	21.3/17.9%
		if (drawRectCount > 16)
		{
			drawRects = fallbackDrawRects;
			drawRectCount = 1;
		}
	}
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
								 fraction:1.0];
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
						 fraction:1.0];
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
	if (highlightedImageSourcesOutline && !tilesWithSubOptimalUniqueMatchesOutline)		//&& !drawLoRes)
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
	
	if (tilesWithSubOptimalUniqueMatchesOutline)
	{
		NSSize				boundsSize = mosaicBounds.size;
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform translateXBy:0.5 yBy:0.5];
		[transform scaleXBy:boundsSize.width yBy:boundsSize.height];
		NSBezierPath		*transformedOutline = [transform transformBezierPath:tilesWithSubOptimalUniqueMatchesOutline];
		
			// Lighten the tiles that have optimal unique matches.
		NSBezierPath		*lightenOutline = [NSBezierPath bezierPath];
		[lightenOutline moveToPoint:NSMakePoint(0, 0)];
		[lightenOutline lineToPoint:NSMakePoint(0, boundsSize.height)];
		[lightenOutline lineToPoint:NSMakePoint(boundsSize.width, boundsSize.height)];
		[lightenOutline lineToPoint:NSMakePoint(boundsSize.width, 0)];
		[lightenOutline closePath];
		[lightenOutline appendBezierPath:transformedOutline];
		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
		[lightenOutline fill];
		
			// Darken the outline of the tiles with sub-optimal matches.
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
		[transformedOutline stroke];
	}
	
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
		[bezierPath setLineDash:dashes count:2 phase:(float)phase];
		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
		[bezierPath stroke];
		
		[bezierPath setLineDash:dashes count:2 phase:((int)phase + 5) % 10];
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
	
		// Zoom any images into place
	[imagePlacementLock lock];
		if (imagePlacementStartTime)
		{
			NSTimeInterval		timeSincePlacementStarted = -[imagePlacementStartTime timeIntervalSinceNow];
			float				imageWidth = [imagePlacementImage size].width, 
								imageHeight = [imagePlacementImage size].height;
			
				// Calculate the bounds of the image when displayed full size.
			NSRect				fullSizeFrame;
			if ((imageWidth / NSWidth(mosaicBounds)) < (imageHeight / NSHeight(mosaicBounds)))
			{
				float	scaledHeight = imageHeight * NSWidth(mosaicBounds) / imageWidth;
				fullSizeFrame = NSMakeRect(NSMinX(mosaicBounds), NSMinY(mosaicBounds) + (NSHeight(mosaicBounds) - scaledHeight) / 2.0, NSWidth(mosaicBounds), scaledHeight);
			}
			else
			{
				float	scaledWidth = imageWidth * NSHeight(mosaicBounds) / imageHeight;
				fullSizeFrame = NSMakeRect(NSMinX(mosaicBounds) + (NSWidth(mosaicBounds) - scaledWidth) / 2.0, NSMinY(mosaicBounds), scaledWidth, NSHeight(mosaicBounds));
			}
			
				// Cancel any pending calls to update the animation.
			[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(animateImagePlacement) object:nil];
			
			if (timeSincePlacementStarted < [mosaic imagePlacementFullSizedDuration])
			{
					// Draw the image to be placed at full size.
				[imagePlacementImage drawInRect:fullSizeFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
				
					// Overlay any message.
				NSString	*imagePlacementFormat = [mosaic imagePlacementMessage];
				if ([imagePlacementFormat length] > 0)
				{
					NSMutableString	*imagePlacementMessage = [NSMutableString stringWithString:imagePlacementFormat];
					if ([imagePlacementDescription length] > 0)
						[imagePlacementMessage replaceOccurrencesOfString:[MacOSaiXAnimationSettingsController imageDescriptionPlaceholder] withString:imagePlacementDescription options:0 range:NSMakeRange(0, [imagePlacementMessage length])];
					
					float			fontHeight = floor(NSHeight(mosaicBounds) / 16.0);
					if (fontHeight < 9.0)
						fontHeight = 9.0;
					
					NSMutableParagraphStyle	*paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
					[paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
					NSMutableDictionary		*attributes = [NSMutableDictionary dictionaryWithObject:paraStyle forKey:NSParagraphStyleAttributeName];
					NSSize					messageSize;
					float					widthDiff;
					NSRect					messageFrame;
					do
					{
						[attributes setObject:[NSFont boldSystemFontOfSize:fontHeight] forKey:NSFontAttributeName];
						messageSize = [imagePlacementMessage sizeWithAttributes:attributes];
						widthDiff = NSWidth(mosaicBounds) - messageSize.width - 30.0;
						messageFrame = NSMakeRect(NSMinX(mosaicBounds) + 5.0 + widthDiff / 2.0, NSMinY(mosaicBounds) + 5.0, messageSize.width + 20.0, messageSize.height + 10.0);
						
						if (imagePlacementSourceImage)
						{
							widthDiff -= messageSize.height + 10.0;
							messageFrame.origin.x -= (messageSize.height + 10.0) / 2.0;
							messageFrame.size.width += messageSize.height + 10.0;
						}
						
						if (widthDiff < 0.0)
							fontHeight -= 1.0;
					} while (widthDiff < 0.0 && fontHeight > 9.0);
					
					if (widthDiff < 0.0)
					{
						messageFrame.origin.x -= widthDiff / 2.0;
						messageFrame.size.width += widthDiff;
					}
					
					NSBezierPath			*messagePath = [NSBezierPath bezierPathWithRoundedRect:messageFrame radius:10.0];
					[[NSColor colorWithDeviceWhite:1.0 alpha:0.75] set];
					[messagePath fill];
					[[NSColor colorWithDeviceWhite:0.0 alpha:0.25] set];
					[messagePath stroke];
					
					NSRect					textFrame = NSInsetRect(messageFrame, 10.0, 5.0);
					if (imagePlacementSourceImage)
					{
						textFrame.origin.x += messageSize.height + 10.0;
						textFrame.size.width -= messageSize.height + 10.0;
					}
					[[NSColor blackColor] set];
					[imagePlacementMessage drawInRect:textFrame withAttributes:attributes];
					
					if (imagePlacementSourceImage)
					{
						NSImage	*scaledImage = [imagePlacementSourceImage copyWithLargestDimension:messageSize.height];
						[imagePlacementSourceImage drawInRect:NSMakeRect(NSMinX(messageFrame) + 10.0 + (messageSize.height - [scaledImage size].width) / 2.0, NSMinY(messageFrame) + 5.0 + (messageSize.height - [scaledImage size].height) / 2.0, [scaledImage size].width, [scaledImage size].height) 
													 fromRect:NSZeroRect 
													operation:NSCompositeSourceOver 
													 fraction:1.0];
						[scaledImage release];
					}
				}
				
				[self performSelector:@selector(animateImagePlacement) withObject:nil afterDelay:[mosaic imagePlacementFullSizedDuration] - timeSincePlacementStarted];
			}
			else if (timeSincePlacementStarted < [mosaic imagePlacementFullSizedDuration] + 1.0)
			{
				// Animate the image moving into the tile(s).
				
				NSAffineTransform	*transform = [NSAffineTransform transform];
				[transform translateXBy:NSMinX(mosaicBounds) yBy:NSMinY(mosaicBounds)];
				[transform scaleXBy:NSWidth(mosaicBounds) yBy:NSHeight(mosaicBounds)];
				
				NSEnumerator		*tileEnumerator = [imagePlacementTiles objectEnumerator];
				MacOSaiXTile		*tile = nil;
				
				while (tile = [tileEnumerator nextObject])
				{
						// Calculate the bounds of the image when displayed in the tile.
					NSRect	tileFrame = [[transform transformBezierPath:[tile outline]] bounds], 
							tileImageFrame;
					if ((imageWidth / NSWidth(tileFrame)) < (imageHeight / NSHeight(tileFrame)))
					{
						float	scaledHeight = imageHeight * NSWidth(tileFrame) / imageWidth;
						tileImageFrame = NSMakeRect(NSMinX(tileFrame), NSMinY(tileFrame) + (NSHeight(tileFrame) - scaledHeight) / 2.0, NSWidth(tileFrame), scaledHeight);
					}
					else
					{
						float	scaledWidth = imageWidth * NSHeight(tileFrame) / imageHeight;
						tileImageFrame = NSMakeRect(NSMinX(tileFrame) + (NSWidth(tileFrame) - scaledWidth) / 2.0, NSMinY(tileFrame), scaledWidth, NSHeight(tileFrame));
					}
					
						// Animate the image moving into place.
					float	animationPhase = (timeSincePlacementStarted - [mosaic imagePlacementFullSizedDuration]) / 1.0;
					NSRect	currentFrame = NSMakeRect(NSMinX(fullSizeFrame) + (NSMinX(tileImageFrame) - NSMinX(fullSizeFrame)) * animationPhase, 
													  NSMinY(fullSizeFrame) + (NSMinY(tileImageFrame) - NSMinY(fullSizeFrame)) * animationPhase, 
													  NSWidth(fullSizeFrame) + (NSWidth(tileImageFrame) - NSWidth(fullSizeFrame)) * animationPhase, 
													  NSHeight(fullSizeFrame) + (NSHeight(tileImageFrame) - NSHeight(fullSizeFrame)) * animationPhase);
					
					[imagePlacementImage drawInRect:currentFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 - animationPhase / 4.0];
				}
				
				[self performSelector:@selector(animateImagePlacement) withObject:nil afterDelay:0.04];	// max 25 fps
			}
			else
			{
				// The animation is finished.
				
				[imagePlacementTiles release];
				imagePlacementTiles = nil;
				[imagePlacementImage release];
				imagePlacementImage = nil;
				[imagePlacementDescription release];
				imagePlacementDescription = nil;
				[imagePlacementSourceImage release];
				imagePlacementSourceImage = nil;
				
				[imagePlacementLastTime release];
				imagePlacementLastTime = [[NSDate date] retain];
				
				[imagePlacementStartTime release];
				imagePlacementStartTime = nil;
				
					// Make sure the animation gets erased.
				[self performSelector:@selector(animateImagePlacement) withObject:nil afterDelay:0.0];
			}
		}
	[imagePlacementLock unlock];
	
	// Draw an indicator while the tile bitmaps are being extracted.
	if (![mosaic allTilesHaveExtractedBitmaps])
	{
		NSRect			viewBounds = [self bounds];
		float			maxWidth = NSWidth(viewBounds) / 2.0;
		NSRect			indicatorBounds = NSMakeRect(NSMinX(viewBounds) + maxWidth / 2.0, 
													 NSMidY(viewBounds) - 8.0, 
													 maxWidth, 
													 16.0), 
						panelBounds = NSInsetRect(indicatorBounds, -8.0, -8.0), 
						progressBounds = indicatorBounds;

		panelBounds.size.height += 16.0;
		progressBounds.size.width = maxWidth * [mosaic tileBitmapExtractionFractionComplete];

		NSBezierPath	*panelPath = [NSBezierPath bezierPathWithRoundedRect:panelBounds radius:8.0], 
						*indicatorPath = [NSBezierPath bezierPathWithRoundedRect:indicatorBounds radius:8.0];
		
		[[NSColor colorWithDeviceWhite:0.0 alpha:0.25] set];
		[panelPath fill];
		
		[NSLocalizedString(@"Extracting tile images...", @"") drawInRect:NSOffsetRect(indicatorBounds, 8.0, 20.0) 
														  withAttributes:[NSDictionary dictionaryWithObject:[NSColor colorWithDeviceWhite:1.0 alpha:0.75] forKey:NSForegroundColorAttributeName]];
		
		[[NSColor colorWithDeviceWhite:1.0 alpha:0.75] set];
		[indicatorPath setLineWidth:2.0];
		[indicatorPath stroke];
		
		[indicatorPath setClip];
		NSRectFill(progressBounds);
	}
}


- (void)setInLiveRedraw:(NSNumber *)flag
{
	if (!inLiveRedraw && [flag boolValue])
	{
		inLiveRedraw = YES;
		[[self class] cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:[NSNumber numberWithBool:NO]];
		[self performSelector:_cmd withObject:[NSNumber numberWithBool:NO] afterDelay:0.0];
	}
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


#pragma mark -
#pragma mark Highlight methods


- (void)highlightTile:(MacOSaiXTile *)tile
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
	
	highlightedTile = tile;
	
    if (highlightedTile)
    {
			// Mark the newly highlighted area for re-display.
		NSBezierPath		*bezierPath = [transform transformBezierPath:[highlightedTile outline]];
		[self setNeedsDisplayInRect:NSInsetRect([bezierPath bounds], -2.0, -2.0)];
	}
}


- (void)createHighlightedImageSourcesOutline
{
	NSEnumerator	*tileEnumerator = [[mosaic tiles] objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
	{
		id<MacOSaiXImageSource>	displayedSource = [[[tile userChosenImageMatch] sourceImage] source];
		if (!displayedSource)
			displayedSource = [[[tile uniqueImageMatch] sourceImage] source];
		if (!displayedSource && backgroundMode == bestMatchMode)
			displayedSource = [[[tile bestImageMatch] sourceImage] source];
		
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


- (void)animateHighlight
{
    phase = ++phase % 10;
	
	NSRect				mosaicBounds = [self boundsForOriginalImage:[mosaic originalImage]];
    NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:NSMinX(mosaicBounds) yBy:NSMinY(mosaicBounds)];
	[transform scaleXBy:NSWidth(mosaicBounds) yBy:NSHeight(mosaicBounds)];
    NSBezierPath		*bezierPath = [transform transformBezierPath:[highlightedTile outline]];

    [self setNeedsDisplayInRect:NSInsetRect([bezierPath bounds], -2.0, -2.0)];
}


// TBD: anybody using this?
//- (NSImage *)image
//{
//	return mainImage;
//}


- (void)setTilesWithSubOptimalUniqueMatchesHighlighted:(BOOL)flag
{
	if (flag != tilesWithSubOptimalUniqueMatchesAreHighlighted)
	{
		tilesWithSubOptimalUniqueMatchesAreHighlighted = flag;
		
		if (tilesWithSubOptimalUniqueMatchesAreHighlighted)
		{
			NSEnumerator	*tileEnumerator = [[mosaic tilesWithSubOptimalUniqueMatches] objectEnumerator];
			MacOSaiXTile	*tile = nil;
			
			tilesWithSubOptimalUniqueMatchesOutline = [[NSBezierPath bezierPath] retain];
			while (tile = [tileEnumerator nextObject])
				[tilesWithSubOptimalUniqueMatchesOutline appendBezierPath:[tile outline]];
		}
		else
		{
			[tilesWithSubOptimalUniqueMatchesOutline release];
			tilesWithSubOptimalUniqueMatchesOutline = nil;
		}
		
		[self setNeedsDisplay:YES];
	}
}


#pragma mark -


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[self class] cancelPreviousPerformRequestsWithTarget:self];
	
	[mainImage release];
	[mainImageLock release];
	[mainImageTransform release];
	[backgroundImage release];
	[backgroundImageLock release];
	[tileOutlinesImage release];
	[highlightedImageSources release];
	[highlightedImageSourcesLock release];
	[highlightedImageSourcesOutline release];
	[tilesWithSubOptimalUniqueMatchesOutline release];
	[tilesNeedingDisplay release];
	[tilesNeedDisplayLock release];
	[tilesToRefresh release];
	[tileMatchTypesToRefresh release];
	[tileRefreshLock release];
	[previousOriginalImage release];
	[originalFadeStartTime release];
	
	[imagePlacementTiles release];
	[imagePlacementImage release];
	[imagePlacementDescription release];
	[imagePlacementSourceImage release];
	[imagePlacementLock release];
	[imagePlacementLastTime release];
	[imagePlacementStartTime release];
	
	[super dealloc];
}


@end

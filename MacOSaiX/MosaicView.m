//
//  MosaicView.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001-2005 Frank M. Midgley.  All rights reserved.
//

#import "MosaicView.h"

#import "MacOSaiXEditor.h"
#import "MacOSaiXFullScreenWindow.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageOrientations.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXTextFieldCell.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXWindowController.h"
#import "NSImage+MacOSaiX.h"
#import "Tiles.h"

#import <Carbon/Carbon.h>
#import <pthread.h>


NSString	*MacOSaiXMosaicViewDidChangeBusyStateNotification = @"MacOSaiXMosaicViewDidChangeBusyStateNotification";

@interface MosaicView (PrivateMethods)
- (void)targetImageDidChange:(NSNotification *)notification;
- (void)tileShapesDidChange:(NSNotification *)notification;
- (void)createHighlightedImageSourcesOutline;
- (NSRect)boundsForTargetImage:(NSImage *)targetImage;
@end


@implementation MosaicView


- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect])
	{
		tilesToRefresh = [[NSMutableArray alloc] init];
		tileRefreshLock = [[NSLock alloc] init];
	}
	
	return self;
}


- (void)awakeFromNib
{
	mainImageLock = [[NSLock alloc] init];
	tilesNeedingDisplay = [[NSMutableArray alloc] init];
	tilesNeedDisplayLock = [[NSLock alloc] init];
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
													 selector:@selector(targetImageDidChange:) 
														 name:MacOSaiXTargetImageDidChangeNotification
													   object:mosaic];
			[[NSNotificationCenter defaultCenter] addObserver:self 
													 selector:@selector(tileShapesDidChange:) 
														 name:MacOSaiXTileShapesDidChangeStateNotification 
													   object:mosaic];
			[[NSNotificationCenter defaultCenter] addObserver:self 
													 selector:@selector(tileImageDidChange:) 
														 name:MacOSaiXTileContentsDidChangeNotification 
													   object:mosaic];
		}
		
		[self targetImageDidChange:nil];
		[self tileShapesDidChange:nil];
	}
}


- (MacOSaiXMosaic *)mosaic
{
	return mosaic;
}


- (BOOL)isOpaque
{
	return NO;
}


- (void)targetImageDidChange:(NSNotification *)notification
{
	previousTargetImage = [[[notification userInfo] objectForKey:@"Previous Image"] retain];
	
	if (previousTargetImage)
	{
			// Phase out the previous image.
		[targetFadeStartTime release];
		targetFadeStartTime = [[NSDate alloc] init];
		if ([targetFadeTimer isValid])
			[targetFadeTimer invalidate];
		[targetFadeTimer release];
		targetFadeTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01 
															  target:self 
															selector:@selector(fadeToNewTargetImage:) 
															userInfo:nil 
															 repeats:YES] retain];
		
			// De-queue any pending tile refreshes for the previous target image.
		[tilesNeedDisplayLock lock];
			[tilesNeedingDisplay removeAllObjects];
		[tilesNeedDisplayLock unlock];
	}
	
		// Phase in the new image.
		// Pick a size for the main image.  (somewhat arbitrary but large enough for decent zooming)
	float	bitmapSize = 10.0 * 1024.0 * 1024.0;
	mainImageSize.width = floorf(sqrtf([mosaic aspectRatio] * bitmapSize));
	mainImageSize.height = floorf(bitmapSize / mainImageSize.width);
	
	[mainImageLock lock];
			// Release the current main image.  A new one will be created later off the main thread.
		[mainImage autorelease];
		mainImage = nil;
		
			// Set up a transform so we can scale tiles to the mosaic image's size (tile shapes are defined the target image's space)
		NSSize	targetImageSize = [[[self mosaic] targetImage] size];
		[mainImageTransform autorelease];
		mainImageTransform = [[NSAffineTransform alloc] init];
		[mainImageTransform scaleXBy:mainImageSize.width / targetImageSize.width 
								 yBy:mainImageSize.height / targetImageSize.height];
	[mainImageLock unlock];
}


- (void)setTargetFadeTime:(float)seconds
{
	targetFadeTime = seconds;
}


- (void)fadeToNewTargetImage:(NSTimer *)timer
{
	if (!targetFadeStartTime || [[NSDate date] timeIntervalSinceDate:targetFadeStartTime] > targetFadeTime)
	{
		[timer invalidate];
		
		if (timer == targetFadeTimer)
		{
			[targetFadeTimer release];
			targetFadeTimer = nil;
			
			[self setNeedsDisplay:YES];
		}
	}
	else if (timer == targetFadeTimer)
		[self setNeedsDisplay:YES];
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


- (void)tileShapesDidChange:(NSNotification *)notification
{
	[tileRefreshLock lock];
		[tilesToRefresh removeAllObjects];
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
	
		// TODO: main thread?
	[self setNeedsDisplay:YES];
}


- (void)refreshTile:(NSDictionary *)tileDict
{
		// Add the tile to the queue of tiles to be refreshed and start the refresh thread if it isn't already running.
		// TODO: handle new fill types
	MacOSaiXTile		*tile = [tileDict objectForKey:@"Tile"];
//	MacOSaiXImageMatch	*previousMatch = [tileDict objectForKey:@"Previous Match"];
	
	[tileRefreshLock lock];
		unsigned	index= [tilesToRefresh indexOfObject:tile];
		if (index != NSNotFound)
		{
				// Move the tile to the head of the refresh queue.
			[tilesToRefresh removeObjectAtIndex:index];
			[tilesToRefresh addObject:tile];
		}
		else
		{
				// Add the tile to the head of the refresh queue.
			[tilesToRefresh addObject:tile];
		}
		
		if (!refreshingTiles)
		{
			refreshingTiles = YES;
			[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicViewDidChangeBusyStateNotification 
																object:self];
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
			}
		[tileRefreshLock unlock];
		
		if (tileToRefresh)
		{
			NSBezierPath		*rotatedOutline = [tileToRefresh rotatedOutline];
			
			if (rotatedOutline)
			{
				NSAffineTransform	*transform = [NSAffineTransform transform];
				[transform translateXBy:NSMidX([rotatedOutline bounds]) yBy:NSMidY([rotatedOutline bounds])];
				[transform scaleBy:mainImageSize.width / [[mosaic targetImage] size].width];
				[transform translateXBy:-NSMidX([rotatedOutline bounds]) yBy:-NSMidY([rotatedOutline bounds])];
				NSBezierPath		*mainOutline = [transform transformBezierPath:rotatedOutline];
				
					// Get the image rep, if any, to draw for this tile.
					// These steps are the primary reason we're in a separate thread because the cache may have to get the images from the sources which might have to hit the network, etc.
				MacOSaiXImageMatch	*imageMatch = nil;
				if ([tileToRefresh fillStyle] == fillWithUniqueMatch)
					imageMatch = [tileToRefresh uniqueImageMatch];
				else if ([tileToRefresh fillStyle] == fillWithHandPicked)
					imageMatch = [tileToRefresh userChosenImageMatch];
				
				NSImageRep			*imageRep = nil;
				if (imageMatch)
					imageRep = [imageCache imageRepAtSize:NSIntegralRect([mainOutline bounds]).size
											forIdentifier:[imageMatch imageIdentifier] 
											   fromSource:[imageMatch imageSource]];
				
				[tileRefreshLock lock];
					[tilesToRedraw addObject:[NSDictionary dictionaryWithObjectsAndKeys:
													tileToRefresh, @"Tile", 
													imageRep, @"Image Rep", // could be nil so last
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
					
					if ([tilesToRedraw count] > 0 && [lastRedraw timeIntervalSinceNow] < -0.2)
					{
						[self performSelector:@selector(redrawTiles:) withObject:[NSArray arrayWithArray:tilesToRedraw]];
//						[self performSelectorOnMainThread:@selector(redrawTiles:) 
//											   withObject:[NSArray arrayWithArray:tilesToRedraw] 
//											waitUntilDone:NO];
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
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicViewDidChangeBusyStateNotification 
															object:self];
		[tileRefreshLock unlock];
	
	[pool release];
	
}


- (void)redrawTiles:(NSArray *)tilesToRedraw
{
	NSEnumerator	*tileDictEnumerator = [tilesToRedraw objectEnumerator];
	NSDictionary	*tileDict = nil;
	
	while (mosaic && (tileDict = [tileDictEnumerator nextObject]))
	{
		MacOSaiXTile		*tile = [tileDict objectForKey:@"Tile"];
		NSImageRep			*imageRep = [tileDict objectForKey:@"Image Rep"];
		NSBezierPath		*clipPath = [mainImageTransform transformBezierPath:[tile outline]], 
							*targetOutline = [tile outline];
		NSRect				targetBounds = [targetOutline bounds];
		
			// Rotate the outline to offset the tile's image orientation.
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform translateXBy:NSMidX([clipPath bounds]) yBy:NSMidY([clipPath bounds])];
		[transform scaleBy:mainImageSize.width / [[mosaic targetImage] size].width];
		[transform rotateByDegrees:-[tile imageOrientation]];
		[transform translateXBy:-NSMidX(targetBounds) yBy:-NSMidY(targetBounds)];
		NSBezierPath		*rotatedOutline = [transform transformBezierPath:targetOutline];
		NSRect				rotatedBounds = [rotatedOutline bounds];
		
		BOOL				widthLimited = (([imageRep size].width / NSWidth(rotatedBounds)) < 
											([imageRep size].height / NSHeight(rotatedBounds)));
		
		transform = [NSAffineTransform transform];
		[transform translateXBy:NSMidX([clipPath bounds]) yBy:NSMidY([clipPath bounds])];
		if (widthLimited)
			[transform scaleBy:NSWidth(rotatedBounds) / [imageRep size].width];
		else	// height limited
			[transform scaleBy:NSHeight(rotatedBounds) / [imageRep size].height];
		[transform rotateByDegrees:[tile imageOrientation]];
		[transform translateXBy:-[imageRep size].width / 2.0 yBy:-[imageRep size].height / 2.0];
		
		[mainImageLock lock];
			if (mainImage)
			{
				NS_DURING
					[mainImage lockFocus];
						[clipPath setClip];
						
						switch ([tile fillStyle])
						{
							case fillWithUniqueMatch:
							case fillWithHandPicked:
								if (imageRep)
								{
									[transform concat];
									[imageRep drawAtPoint:NSZeroPoint];
								}
								break;
							case fillWithTargetImage:
								[[[self mosaic] targetImage] drawInRect:NSMakeRect(0.0, 0.0, [mainImage size].width, [mainImage size].height)
															   fromRect:NSZeroRect 
															  operation:NSCompositeSourceOver 
															   fraction:1.0];
								break;
							case fillWithSolidColor:
								[[tile fillColor] set];
								NSRectFillUsingOperation([clipPath bounds], NSCompositeSourceOver);
								break;
						}
					[mainImage unlockFocus];
				NS_HANDLER
					#ifdef DEBUG
						NSLog(@"Could not lock focus on mosaic image");
					#endif
				NS_ENDHANDLER
			}
		[mainImageLock unlock];
		
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


- (BOOL)isBusy
{
	return refreshingTiles;
}


- (NSString *)busyStatus
{
	NSString	*status = nil;
	
	if (refreshingTiles)
		status = NSLocalizedString(@"Refreshing tiles...", @"");
	
	return status;
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
	NSRect				mosaicBounds = [self boundsForTargetImage:[mosaic targetImage]];
	NSSize				targetImageSize = [[[self mosaic] targetImage] size];
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:NSMinX(mosaicBounds) yBy:NSMinY(mosaicBounds)];
	[transform scaleXBy:NSWidth(mosaicBounds) / targetImageSize.width 
					yBy:NSHeight(mosaicBounds) / targetImageSize.height];
	
	[tilesNeedDisplayLock lock];
		if ([self targetImageFraction] < 1.0)
		{
			NSEnumerator	*tileEnumerator = [tilesNeedingDisplay objectEnumerator];
			MacOSaiXTile	*tileNeedingDisplay = nil;
			while (tileNeedingDisplay = [tileEnumerator nextObject])
				[self setNeedsDisplayInRect:NSInsetRect([[transform transformBezierPath:[tileNeedingDisplay outline]] bounds], -1.0, -1.0)];
		}
		
		[tilesNeedingDisplay removeAllObjects];
		
		[tilesNeedDisplayTimer release];
		tilesNeedDisplayTimer = nil;
	[tilesNeedDisplayLock unlock];
}


- (void)setTargetImageFraction:(float)fraction
{
	if (targetImageFraction != fraction)
	{
		targetImageFraction = fraction;
		
		[self setNeedsDisplay:YES];
		
		[self setInLiveRedraw:[NSNumber numberWithBool:YES]];
	}
}


- (float)targetImageFraction
{
    return targetImageFraction;
}


- (MacOSaiXTile *)tileAtPoint:(NSPoint)thePoint
{
		// Convert the point to the units system that the tile outlines are in.
	NSRect	imageBounds = [self imageBounds];
	NSSize	targetImageSize = [[[self mosaic] targetImage] size];
    thePoint.x = (thePoint.x - NSMinX(imageBounds)) / NSWidth(imageBounds) * targetImageSize.width;
    thePoint.y = (thePoint.y - NSMinY(imageBounds)) / NSHeight(imageBounds) * targetImageSize.height;
    
		// TBD: this isn't terribly efficient...
	NSEnumerator	*tileEnumerator = [[mosaic tiles] objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
        if ([[tile outline] containsPoint:thePoint])
			break;
	
	return tile;
}


- (NSRect)boundsForTargetImage:(NSImage *)targetImage
{
	NSRect	viewBounds = [self bounds],
			mosaicBounds = viewBounds;
	NSSize	imageSize = [targetImage size];
	
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


- (NSRect)imageBounds
{
	return [self boundsForTargetImage:[mosaic targetImage]];
}


- (void)drawRect:(NSRect)theRect
{
	BOOL			targetImageIsChanging = (previousTargetImage != nil), 
					drawLoRes = ([self inLiveResize] || inLiveRedraw || targetImageIsChanging);
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
	
	float	previousTargetFraction = 0.0;
	if (targetFadeStartTime)
	{
		previousTargetFraction = 1.0 - ([[NSDate date] timeIntervalSinceDate:targetFadeStartTime] / targetFadeTime);
		if (previousTargetFraction < 0.0)
			previousTargetFraction = 0.0;
	}
	if (previousTargetFraction == 0.0)
	{
		[previousTargetImage release];
		previousTargetImage = nil;
		[targetFadeStartTime release];
		targetFadeStartTime = nil;
	}
					
		// Redraw the image layers within the rects to update.
	NSImage			*targetImage = [mosaic targetImage];
	NSRect			mosaicBounds = [self boundsForTargetImage:targetImage];
	int				index = 0;
	for (; index < drawRectCount; index++)
	{
		[[NSColor grayColor] set];
		NSRectFill(drawRects[index]);
		
		NSRect	drawRect = NSIntersectionRect(drawRects[index], mosaicBounds), 
				drawUnitRect = NSMakeRect((NSMinX(drawRect) - NSMinX(mosaicBounds)) / NSWidth(mosaicBounds), 
										   (NSMinY(drawRect) - NSMinY(mosaicBounds)) / NSHeight(mosaicBounds), 
										   NSWidth(drawRect) / NSWidth(mosaicBounds), 
										   NSHeight(drawRect) / NSHeight(mosaicBounds)), 
				targetRect = NSMakeRect(NSMinX(drawUnitRect) * [targetImage size].width, 
										NSMinY(drawUnitRect) * [targetImage size].height, 
										NSWidth(drawUnitRect) * [targetImage size].width,
										NSHeight(drawUnitRect) * [targetImage size].height), 
				mainImageRect = NSMakeRect(NSMinX(drawUnitRect) * mainImageSize.width, 
										   NSMinY(drawUnitRect) * mainImageSize.height, 
										   NSWidth(drawUnitRect) * mainImageSize.width,
										   NSHeight(drawUnitRect) * mainImageSize.height);
		
		if (targetImageFraction > 0.0)
		{
			if (targetImageIsChanging && previousTargetFraction > 0.0)
			{
					// Animate the previous target turning into the current target.
				NSRect	previousMosaicBounds = [self boundsForTargetImage:previousTargetImage],
						previousDrawRect = NSIntersectionRect(drawRects[index], previousMosaicBounds), 
						previousDrawUnitRect = NSMakeRect((NSMinX(previousDrawRect) - NSMinX(previousMosaicBounds)) / NSWidth(previousMosaicBounds), 
														  (NSMinY(previousDrawRect) - NSMinY(previousMosaicBounds)) / NSHeight(previousMosaicBounds), 
														  NSWidth(previousDrawRect) / NSWidth(previousMosaicBounds), 
														  NSHeight(previousDrawRect) / NSHeight(previousMosaicBounds)), 
						previousTargetRect = NSMakeRect(NSMinX(previousDrawUnitRect) * [previousTargetImage size].width, 
														  NSMinY(previousDrawUnitRect) * [previousTargetImage size].height, 
														  NSWidth(previousDrawUnitRect) * [previousTargetImage size].width,
														  NSHeight(previousDrawUnitRect) * [previousTargetImage size].height);
				
				[previousTargetImage drawInRect:previousDrawRect 
										 fromRect:previousTargetRect 
										operation:NSCompositeSourceOver 
										 fraction:previousTargetFraction];
				
				[[mosaic targetImage] drawInRect:drawRect 
										  fromRect:targetRect 
										 operation:NSCompositeSourceOver 
										  fraction:1.0 - previousTargetFraction];
			}
			else if ([mosaic targetImage])
			{
					// Draw just the current target image.
				[[mosaic targetImage] drawInRect:drawRect 
										  fromRect:targetRect 
										 operation:NSCompositeSourceOver 
										  fraction:targetImageFraction];
			}
			else
			{
				NSString		*noTargetMessage = NSLocalizedString(@"No target image has been selected.", @"");
				NSDictionary	*attributes = [NSDictionary dictionaryWithObject:[NSColor blackColor] 
																		  forKey:NSFontColorAttribute];
				NSSize			stringSize = [noTargetMessage sizeWithAttributes:attributes];
					
				[noTargetMessage drawAtPoint:NSMakePoint(NSMidX([self bounds]) - stringSize.width / 2.0, 
														 NSMidY([self bounds]) - stringSize.height / 2.0) 
							  withAttributes:attributes];
			}
		}
		
		[mainImageLock lock];
			[mainImage drawInRect:drawRect 
						 fromRect:mainImageRect 
						operation:NSCompositeSourceOver 
						 fraction:1.0 - targetImageFraction];
		[mainImageLock unlock];
		
		[activeEditor embellishMosaicViewInRect:drawRect];
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
	[tooltipWindow setLevel:NSFloatingWindowLevel];
	[nibWindow release];
	
	[imageSourceTextField setCell:[[[MacOSaiXTextFieldCell alloc] initTextCell:@""] autorelease]];
}


#pragma mark -
#pragma mark Active Editor


- (void)setActiveEditor:(MacOSaiXEditor *)editor
{
	if (editor != activeEditor)
	{
		[activeEditor release];
		activeEditor = [editor retain];
		
		[self setNeedsDisplay:YES];
	}
}


- (MacOSaiXEditor *)activeEditor
{
	return activeEditor;
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


- (void)setTooltipsEnabled:(BOOL)enabled animateHiding:(BOOL)animateHiding
{
	if (enabled && !tooltipTimer && [[NSUserDefaults standardUserDefaults] boolForKey:@"Show Tile Tooltips"])
	{
		//NSLog(@"Enabling tooltips");
		tooltipTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1 
														 target:self 
													   selector:@selector(updateTooltip:) 
													   userInfo:nil 
														repeats:YES] retain];
	}
	else if (!enabled && tooltipTile)
	{
		//NSLog(@"Disabling tooltips");
		
		[tooltipTimer invalidate];
		[tooltipTimer release];
		tooltipTimer = nil;
		
		if (animateHiding)
			[self hideTooltip];
		else
		{
			if ([tooltipHideTimer isValid])
				[tooltipHideTimer invalidate];
			[tooltipHideTimer release];
			tooltipHideTimer = nil;
			[tooltipWindow orderOut:self];
		}
		
		tooltipTile = nil;
	}
}


- (void)updateTooltip:(NSTimer *)timer
{
	if (![[self window] isMainWindow] || [[self window] attachedSheet] || [self activeEditor])
		[self setTooltipsEnabled:NO animateHiding:YES];
	else if (tooltipTile || GetCurrentEventTime() > [[[self window] currentEvent] timestamp] + 1)
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
			if (!imageMatch && showNonUniqueMatches)
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
				
				id						sourceDescription = [imageSource briefDescription];
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
				[tileImageTextField setStringValue:NSLocalizedString(@"Fetching...", @"")];
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
			
			if ([image isValid])
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


- (NSImage *)image
{
	return mainImage;
}


- (void)mouseEntered:(NSEvent *)event
{
	if ([[self window] isKeyWindow] && ![[self window] attachedSheet] && ![self activeEditor])
		[self setTooltipsEnabled:YES animateHiding:YES];
}


- (void)mouseDown:(NSEvent *)event
{
	if (tooltipTile)
	{
		[self hideTooltip];
		tooltipTile = nil;
	}
	
	[activeEditor handleEventInMosaicView:event];
}


- (void)mouseDragged:(NSEvent *)event
{
	[activeEditor handleEventInMosaicView:event];
}


- (void)mouseUp:(NSEvent *)event
{
	[activeEditor handleEventInMosaicView:event];
}


- (void)mouseExited:(NSEvent *)event
{
	[self setTooltipsEnabled:NO animateHiding:YES];
}


- (void)viewDidMoveToWindow
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeMainNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignMainNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignKeyNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillBeginSheetNotification object:nil];
	
	if ([self window])
	{
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(windowDidBecomeMainOrKey:)
													 name:NSWindowDidBecomeMainNotification 
												   object:[self window]];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(windowDidBecomeMainOrKey:)
													 name:NSWindowDidBecomeKeyNotification 
												   object:[self window]];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(windowDidResignMainOrKey:)
													 name:NSWindowDidResignMainNotification 
												   object:[self window]];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(windowDidResignMainOrKey:)
													 name:NSWindowDidResignKeyNotification 
												   object:[self window]];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(windowDidResignMainOrKey:)
													 name:NSWindowWillBeginSheetNotification 
												   object:[self window]];
	}
}


- (void)windowDidBecomeMainOrKey:(NSNotification *)notification
{
	if ([notification object] == [self window])
	{
			// Enable tooltips if the cursor is over the mosaic.
		NSPoint	windowPoint = [[self window] convertScreenToBase:[NSEvent mouseLocation]];
		
		if (NSPointInRect([self convertPoint:windowPoint fromView:nil], [self bounds]))
			[self setTooltipsEnabled:YES animateHiding:NO];
	}
}


- (void)windowDidResignMainOrKey:(NSNotification *)notification
{
	if ([notification object] == [self window])
		[self setTooltipsEnabled:NO animateHiding:NO];
}


- (NSMenu *)menuForEvent:(NSEvent *)event;
{
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
	
	if ([targetFadeTimer isValid])
		[targetFadeTimer invalidate];
	[targetFadeTimer release];
	if ([tilesNeedDisplayTimer isValid])
		[tilesNeedDisplayTimer invalidate];
	[tilesNeedDisplayTimer release];
	
	[self setTooltipsEnabled:NO animateHiding:NO];
	
	[activeEditor release];
	
	[mainImage release];
	[mainImageLock release];
	[mainImageTransform release];
	[contextualMenu release];
	if ([tilesNeedDisplayTimer isValid])
		[tilesNeedDisplayTimer invalidate];
	[tilesNeedDisplayTimer release];
	[tilesNeedingDisplay release];
	[tilesToRefresh release];
	[previousTargetImage release];
	
	[mosaic release];
	mosaic = nil;

	[super dealloc];
}


@end

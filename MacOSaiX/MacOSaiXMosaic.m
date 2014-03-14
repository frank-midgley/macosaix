//
//  MacOSaiXMosaic.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/4/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXMosaic.h"

#import "MacOSaiX.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageMatchCache.h"
#import "MacOSaiXImageMatcher.h"
#import "MacOSaiXSourceImage.h"

#import <sys/sysctl.h>

//#ifdef DEBUG
	#import <Foundation/NSDebug.h>
//#endif


	// The maximum size of the image URL queue.
#define MAXIMAGEURLS 16

	// The maximum number of images to keep in the scrap heap.	Somewhat arbitrary, but enough to not have to re-enumerate a mosaic with four Google searches.
#define SCRAP_LIMIT 4 * 1024


static NSComparisonResult compareTiles(MacOSaiXTile *tile1, MacOSaiXTile *tile2, void *context)
{
	if (tile1 == tile2)
		return NSOrderedSame;
	else if (tile1 < tile2)
		return NSOrderedAscending;
	else
		return NSOrderedDescending;
}


	// Notifications
NSString		*MacOSaiXImageWasPlacedInMosaicNotification = @"MacOSaiXImageWasPlacedInMosaicNotification";
NSString		*MacOSaiXMosaicDidChangeStateNotification = @"MacOSaiXMosaicDidChangeStateNotification";
NSString		*MacOSaiXMosaicDidChangeBusyStateNotification = @"MacOSaiXMosaicDidChangeBusyStateNotification";
NSString		*MacOSaiXOriginalImageDidChangeNotification = @"MacOSaiXOriginalImageDidChangeNotification";
NSString		*MacOSaiXTileImageDidChangeNotification = @"MacOSaiXTileImageDidChangeNotification";
NSString		*MacOSaiXTileShapesDidChangeStateNotification = @"MacOSaiXTileShapesDidChangeStateNotification";
NSString		*MacOSaiXMosaicDidChangeImageSourcesNotification = @"MacOSaiXMosaicDidChangeImageSourcesNotification";
NSString		*MacOSaiXMosaicImageSourcesNeedReenumerationNotification = @"MacOSaiXMosaicImageSourcesNeedReenumerationNotification";
NSString		*MacOSaiXMosaicDidExtractTileBitmapsNotification = @"MacOSaiXMosaicDidExtractTileBitmapsNotification";


@interface MacOSaiXMosaic (PrivateMethods)
- (void)addTile:(MacOSaiXTile *)tile;
- (void)lockWhilePaused;
- (void)setImageCount:(unsigned long)imageCount forImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)setNextImageError:(NSError *)error forImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)placeImages;
@end


@implementation MacOSaiXMosaic


- (id)init
{
    if ((self = [super init]))
    {
		paused = YES;
		
		imageSources = [[NSMutableArray alloc] init];
		imageSourcesLock = [[NSLock alloc] init];
		tilesWithoutBitmapsLock = [[NSLock alloc] init];
		tilesWithoutBitmaps = [[NSMutableArray alloc] init];
		diskCacheSubPaths = [[NSMutableDictionary alloc] init];
		
			// This queue is populated by the enumeration threads and accessed by the matching thread.
		newImageQueue = [[NSMutableArray alloc] init];
		revisitImageQueue = [[NSMutableArray alloc] init];
		imageQueueLock = [[NSLock alloc] init];

		calculateImageMatchesThreadLock = [[NSLock alloc] init];
		sourceImagesInUse = [[NSMutableSet alloc] init];
		tilesUsingImageCacheLock = [[NSLock alloc] init];
		tilesUsingImageCache = [[NSMutableDictionary alloc] init];
		imageErrorQueue = [[NSMutableArray alloc] init];
		scrapLock = [[NSLock alloc] init];
		scrapHeap = [[NSMutableArray alloc] init];
		imagePlacementLock = [[NSLock alloc] init];
		
		enumerationThreadCountLock = [[NSLock alloc] init];
		enumerationCountsLock = [[NSLock alloc] init];
		enumerationCounts = [[NSMutableDictionary alloc] init];
		nextImageErrors = [[NSMutableDictionary alloc] init];
		
		fillerImageSources = [[NSMutableArray alloc] init];
		
		imageSourcesThatHaveLostImages = [[NSMutableSet alloc] init];
		imageSourcesThatHaveLostImagesLock = [[NSLock alloc] init];
		
		NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
		[self setImageUseCount:[[defaults objectForKey:@"Image Use Count"] intValue]];
		[self setImageReuseDistance:[[defaults objectForKey:@"Image Reuse Distance"] intValue]];
		[self setImageCropLimit:[[defaults objectForKey:@"Image Crop Limit"] intValue]];
		
		NSDictionary	*imagePlacementDefaults = [defaults objectForKey:@"Image Placement Settings"];
		[self setAnimateImagePlacements:[[imagePlacementDefaults objectForKey:@"Animate Placements"] boolValue]];
		[self setAnimateAllImagePlacements:[[imagePlacementDefaults objectForKey:@"Animate All Placements"] boolValue]];
		if ([imagePlacementDefaults objectForKey:@"Full Size Display Duration"])
			[self setImagePlacementFullSizedDuration:[[imagePlacementDefaults objectForKey:@"Full Size Display Duration"] intValue]];
		else
			[self setImagePlacementFullSizedDuration:[[imagePlacementDefaults objectForKey:@"Full Size Dislay Duration"] intValue]];
		[self setImagePlacementMessage:[imagePlacementDefaults objectForKey:@"Message"]];
		[self setIncludeSourceImageWithImagePlacementMessage:[[imagePlacementDefaults objectForKey:@"Include Source Image with Message"] boolValue]];
		[self setDelayBetweenImagePlacements:[[imagePlacementDefaults objectForKey:@"Delay Between Placements"] intValue]];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(tileImageDidChange:) 
													 name:MacOSaiXTileImageDidChangeNotification 
												   object:self];
	}
	
    return self;
}


- (void)reset
{
		// Stop any worker threads.
	[self pause];
	
    resetting = YES;
    
		// Reset all of the tiles.
	NSEnumerator			*tileEnumerator = [tiles objectEnumerator];
	MacOSaiXTile			*tile = nil;
	while ((tile = [tileEnumerator nextObject]))
		[tile reset];
	[tilesWithoutBitmaps setArray:tiles];
	
		// Reset all of the image sources.
	NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
	id<MacOSaiXImageSource>	imageSource;
	while (imageSource = [imageSourceEnumerator nextObject])
	{
		[imageSource reset];
		[self setImageCount:0 forImageSource:imageSource];
		[[MacOSaiXImageMatchCache sharedCache] removeMatchesFromSource:imageSource];
	}
	[imageSourcesThatHaveLostImages removeAllObjects];
	// TBD: clear nextImageErrors?
	
		// Clear the caches.
	[sourceImagesInUse removeAllObjects];
	[tilesUsingImageCache removeAllObjects];
	
		// Clear the queues.
	[newImageQueue removeAllObjects];
	[revisitImageQueue removeAllObjects];
	[imageErrorQueue removeAllObjects];
	newImageCount = revisitImageCount = imageErrorCount = 0;
	[scrapHeap removeAllObjects];
	
	mosaicStarted = NO;
    resetting = NO;
}


- (void)updateMinDistanceApart
{
	minDistanceApart = [self imageReuseDistance] * [self imageReuseDistance] *
					   ([self averageUnitTileSize].width * [self averageUnitTileSize].width +
					   [self averageUnitTileSize].height * [self averageUnitTileSize].height / 
					   originalImageAspectRatio / originalImageAspectRatio);
}


#pragma mark -
#pragma mark Original image management


- (void)setOriginalImage:(NSImage *)image
{
	if (image != originalImage)
	{
		[self reset];
		
		[originalImage release];
		originalImage = [image retain];

		[originalImage setCachedSeparately:YES];
		originalImageAspectRatio = [originalImage size].width / [originalImage size].height;

			// Ignore whatever DPI was set for the image.  We just care about the bitmap.
		NSImageRep	*originalRep = [[originalImage representations] objectAtIndex:0];
		[originalRep setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
		[originalImage setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
		
			// Make sure the correct size of NSCachedImageRep gets created.  Without this CMYK images can get cached at the toolbar icon size.  Not sure why it doesn't happen for RGB...
		[originalImage lockFocus];
		[originalImage unlockFocus];
		
		[self updateMinDistanceApart];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXOriginalImageDidChangeNotification object:self];
		
		if ([tiles count] > 0)
			[NSThread detachNewThreadSelector:@selector(extractTileBitmaps) toTarget:self withObject:nil];
	}
}


- (NSImage *)originalImage
{
	return [[originalImage retain] autorelease];
}


#pragma mark -
#pragma mark Tile management


- (void)addTile:(MacOSaiXTile *)tile
{
	if (!tiles)
		tiles = [[NSMutableArray array] retain];
	
	[tiles addObject:tile];
	[tilesWithoutBitmaps addObject:tile];
	
	overallMatch += ([tile uniqueImageMatch] ? [[tile uniqueImageMatch] matchValue] : 1.0f);
}


- (void)setTileShapes:(id<MacOSaiXTileShapes>)inTileShapes creatingTiles:(BOOL)createTiles
{
	[self reset];	// make sure any tile references are cleared before they get deallocated
	
	[tileShapes autorelease];
	tileShapes = [inTileShapes retain];
	
	if (createTiles)
	{
		NSArray	*tileOutlines = [tileShapes shapes];
		
			// Discard any tiles created from a previous set of outlines.
		if (!tiles)
			tiles = [[NSMutableArray arrayWithCapacity:[tileOutlines count]] retain];
		else
			[tiles removeAllObjects];
		
		overallMatch = 0.0f;
		
			// Create a new tile collection from the outlines.  Use a random order so we don't get artifacts in the mosaic if areas of the original image have the exact same color.
		NSMutableArray	*randomizedTileOutlines = [NSMutableArray arrayWithArray:tileOutlines];
		while ([randomizedTileOutlines count] > 0)
		{
			int	outlineIndex = random() % [randomizedTileOutlines count];
			
			[self addTile:[[[MacOSaiXTile alloc] initWithOutline:[randomizedTileOutlines objectAtIndex:outlineIndex] fromMosaic:self] autorelease]];
			
			[randomizedTileOutlines removeObjectAtIndex:outlineIndex];
		}
		
			// TBD: why is this needed?
		[tiles sortUsingFunction:compareTiles context:nil];
		
		if (originalImage)
			[NSThread detachNewThreadSelector:@selector(extractTileBitmaps) toTarget:self withObject:nil];
	}
	
		// Indicate that the average tile size needs to be recalculated.
	averageUnitTileSize = NSZeroSize;
	
		// Let anyone who cares know that our tile shapes (and thus our tiles array) have changed.
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileShapesDidChangeStateNotification 
														object:self 
													  userInfo:nil];
}


- (id<MacOSaiXTileShapes>)tileShapes
{
	return tileShapes;
}


- (NSSize)averageUnitTileSize
{
	if (NSEqualSizes(averageUnitTileSize, NSZeroSize) && [tiles count] > 0)
	{
			// Calculate the average size of the tiles.
		NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
		MacOSaiXTile	*tile = nil;
		while (tile = [tileEnumerator nextObject])
		{
			averageUnitTileSize.width += NSWidth([[tile outline] bounds]);
			averageUnitTileSize.height += NSHeight([[tile outline] bounds]);
		}
		averageUnitTileSize.width /= [tiles count];
		averageUnitTileSize.height /= [tiles count];
	}
	
	return averageUnitTileSize;
}


- (int)imageUseCount
{
	return imageUseCount;
}


- (void)setImageUseCount:(int)count
{
	if (imageUseCount != count)
	{
		imageUseCount = count;
		[[NSUserDefaults standardUserDefaults] setInteger:imageUseCount forKey:@"Image Use Count"];
		
		if ([self wasStarted])
		{
			[self reset];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileShapesDidChangeStateNotification 
																object:self 
															  userInfo:nil];
		}
	}
}


- (int)imageReuseDistance
{
	return imageReuseDistance;
}


- (void)setImageReuseDistance:(int)distance
{
	if (imageReuseDistance != distance)
	{
		imageReuseDistance = distance;
		[[NSUserDefaults standardUserDefaults] setInteger:imageReuseDistance forKey:@"Image Reuse Distance"];
		
		[self updateMinDistanceApart];
		
		if ([self wasStarted])
		{
			[self reset];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileShapesDidChangeStateNotification 
																object:self 
															  userInfo:nil];
		}
	}
}


- (int)imageCropLimit
{
	return imageCropLimit;
}


- (void)setImageCropLimit:(int)cropLimit
{
	if (imageCropLimit != cropLimit)
	{
		imageCropLimit = cropLimit;
		[[NSUserDefaults standardUserDefaults] setInteger:imageCropLimit forKey:@"Image Crop Limit"];
		
		if ([self wasStarted])
		{
			[self reset];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileShapesDidChangeStateNotification 
																object:self 
															  userInfo:nil];
		}
	}
}


- (NSArray *)tiles
{
	return tiles;
}


- (NSArray *)tilesWithSubOptimalUniqueMatches
{
	NSMutableArray	*subOptimalTiles = [NSMutableArray array];
	NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
		if (![tile uniqueImageMatchIsOptimal])
			[subOptimalTiles addObject:tile];
	
	return subOptimalTiles;
}


- (void)clearTilesWithSubOptimalUniqueMatches
{
	BOOL	wasRunning = ![self isPaused];
	
	if (wasRunning)
		[self pause];
	
	NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
		[tile setUniqueImageMatchIsOptimal:YES];
	
	reenumerationNotificationWasSent = NO;
	
	if (wasRunning)
		[self resume];
}


- (void)extractTileBitmaps
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	[tilesWithoutBitmapsLock lock];
	
	if (!tileBitmapExtractionThreadAlive)
	{
		NSEnumerator		*tileEnumerator = [[NSArray arrayWithArray:tilesWithoutBitmaps] objectEnumerator];
		MacOSaiXTile		*tile = nil;
		
		tileBitmapExtractionThreadAlive = YES;
		[tilesWithoutBitmapsLock unlock];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
															object:self];
		
		while (!documentIsClosing && (tile = [tileEnumerator nextObject]))
			[tile bitmapRep];
	}
	else
		[tilesWithoutBitmapsLock unlock];
	
	[pool release];
	
	tileBitmapExtractionThreadAlive = NO;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
														object:self];
	
//	NSZombieEnabled = YES;
}


- (void)tileDidExtractBitmap:(MacOSaiXTile *)tile
{
	long	tilesLeftCount;
	
	[tilesWithoutBitmapsLock lock];
		[tilesWithoutBitmaps removeObjectIdenticalTo:tile];
		tilesLeftCount = [tilesWithoutBitmaps count];
	[tilesWithoutBitmapsLock unlock];
	
	if (tilesLeftCount % 10 == 0)
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidExtractTileBitmapsNotification 
															object:self];
	
	if ([self allTilesHaveExtractedBitmaps])
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification 
															object:self];
}


- (BOOL)allTilesHaveExtractedBitmaps
{
	[tilesWithoutBitmapsLock lock];
	BOOL	doneExtracting = ([self tileShapes] && [tilesWithoutBitmaps count] == 0);
	[tilesWithoutBitmapsLock unlock];
	
	return doneExtracting;
}


- (float)tileBitmapExtractionFractionComplete
{
	float	fractionComplete = 0.0;
	
	if ([self tileShapes])
	{
		[tilesWithoutBitmapsLock lock];
		fractionComplete = 1.0 - (float)[tilesWithoutBitmaps count] / [[self tiles] count];
		[tilesWithoutBitmapsLock unlock];
	}
	
	return fractionComplete;
}


- (void)tileImageDidChange:(NSNotification *)notification
{
    if (resetting)
        return;
    
	// Update the overall match value for the mosaic.
	// TODO: take the size of each tile into consideration.
	
	BOOL	valueChanged = NO;
	
	if (overallMatch < 0.0f || overallMatch > [tiles count])
	{
			// Oops.
		NSEnumerator		*tileEnumerator = [tiles objectEnumerator];
		MacOSaiXTile		*tile = nil;
		
		overallMatch = 0.0f;
		while (tile = [tileEnumerator nextObject])
		{
			MacOSaiXImageMatch	*currentMatch = [tile displayedImageMatch];
			overallMatch += (currentMatch ? [currentMatch matchValue] : 1.0f);
		}
		
		valueChanged = YES;
	}
	else
	{
		NSDictionary		*tileDict = [notification userInfo];
		MacOSaiXTile		*tile = [tileDict objectForKey:@"Tile"];
		NSString			*matchType = [tileDict objectForKey:@"Match Type"];
		MacOSaiXImageMatch	*previousMatch = [tileDict objectForKey:@"Previous Match"], 
							*currentMatch = ([tile userChosenImageMatch] ? [tile userChosenImageMatch] : [tile uniqueImageMatch]);
		
		if ([matchType isEqualToString:@"User Chosen"] || ([matchType isEqualToString:@"Unique"] && ![tile userChosenImageMatch]))
		{
			float	previousMatchValue = (previousMatch ? [previousMatch matchValue] : 1.0f), 
					currentMatchValue = (currentMatch ? [currentMatch matchValue] : 1.0f);
			
			if (previousMatchValue != currentMatchValue)
			{
				overallMatch += currentMatchValue - previousMatchValue;
				
				valueChanged = YES;
			}
		}
	}
	
	if (valueChanged)
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
}


#pragma mark -
#pragma mark Images source management


- (NSArray *)imageSources
{
	NSArray	*threadSafeCopy = nil;
	
	[imageSourcesLock lock];
		threadSafeCopy = [NSArray arrayWithArray:imageSources];
	[imageSourcesLock unlock];
		
	return threadSafeCopy;
}


- (void)addImageSource:(id<MacOSaiXImageSource>)imageSource isFiller:(BOOL)isFiller
{
	[imageSourcesLock lock];
		[imageSources addObject:imageSource];
		
		if (isFiller && ![fillerImageSources containsObject:imageSource])
		{
			[fillerImageSources addObject:imageSource];
			fillerImagesChanged = YES;
		}
		
		if (![imageSource canRefetchImages])
		{
			NSString	*sourceCachePath = [[self diskCachePath] stringByAppendingPathComponent:
													[self diskCacheSubPathForImageSource:imageSource]];
			[[MacOSaiXImageCache sharedImageCache] setCacheDirectory:sourceCachePath forSource:imageSource];
		}
	[imageSourcesLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeImageSourcesNotification object:self];
	
	if ([self isPaused])
	{
			// Auto start the mosaic if possible and the user wants to.
		if ([self originalImage] && [self tileShapes] && [tiles count] > 0 && [imageSources count] == 1 && [[NSUserDefaults standardUserDefaults] boolForKey:@"Automatically Start Mosaics"])
			[self resume];
	}
	else
		[NSApplication detachDrawingThread:@selector(enumerateImageSourceInNewThread:) 
								  toTarget:self 
								withObject:imageSource];
}


- (void)removeImageSource:(id<MacOSaiXImageSource>)imageSource
{
	BOOL	wasPaused = [self isPaused];
	if (!wasPaused)
		[self pause];
	
	[imageSource retain];
	
	BOOL	sourceRemoved = NO;
	int		sourceCount = 0;
	[imageSourcesLock lock];
		if ([imageSources containsObject:imageSource])
		{
			[imageSources removeObject:imageSource];
			[self setImageCount:0 forImageSource:imageSource];
			[self setNextImageError:nil forImageSource:imageSource];
			
			sourceRemoved = YES;
		}
		if ([fillerImageSources containsObject:imageSource])
		{
			[fillerImageSources removeObject:imageSource];
			fillerImagesChanged = YES;
		}
		
		sourceCount = [imageSources count];
	[imageSourcesLock unlock];
	
	if (sourceRemoved)
	{
			// Remove any images from this source that are waiting to be matched or are on the scrap.
		[imageQueueLock lock];
			NSEnumerator		*imageEnumerator = [[NSArray arrayWithArray:newImageQueue] objectEnumerator];
			MacOSaiXSourceImage	*queuedImage = nil;
			while ((queuedImage = [imageEnumerator nextObject]))
				if ([queuedImage source] == imageSource)
					[newImageQueue removeObjectIdenticalTo:queuedImage];
			imageEnumerator = [[NSArray arrayWithArray:revisitImageQueue] objectEnumerator];
			while ((queuedImage = [imageEnumerator nextObject]))
				if ([queuedImage source] == imageSource)
					[revisitImageQueue removeObjectIdenticalTo:queuedImage];
			imageEnumerator = [[NSArray arrayWithArray:imageErrorQueue] objectEnumerator];
			while ((queuedImage = [imageEnumerator nextObject]))
				if ([queuedImage source] == imageSource)
					[imageErrorQueue removeObjectIdenticalTo:queuedImage];
			newImageCount = [newImageQueue count];
			revisitImageCount = [revisitImageQueue count];
			imageErrorCount = [imageErrorQueue count];
			
			[scrapLock lock];
				imageEnumerator = [[NSArray arrayWithArray:scrapHeap] objectEnumerator];
				while ((queuedImage = [imageEnumerator nextObject]))
					if ([queuedImage source] == imageSource)
						[scrapHeap removeObjectIdenticalTo:queuedImage];
			[scrapLock unlock];
		[imageQueueLock unlock];
		
			// Remove any images from this source from the tiles.
		NSEnumerator		*tileEnumerator = [tiles objectEnumerator];
		MacOSaiXTile		*tile = nil;
		while ((tile = [tileEnumerator nextObject]))
		{
			[tile imageSourceWasRemoved:imageSource];
			
			if (sourceCount == 0)
				[tile setUniqueImageMatchIsOptimal:YES];
		}
		
		NSEnumerator		*sourceImageEnumerator = [[sourceImagesInUse allObjects] objectEnumerator];
		MacOSaiXSourceImage	*sourceImage = nil;
		while ((sourceImage = [sourceImageEnumerator nextObject]))
			if ([sourceImage source] == imageSource)
			{
				[sourceImagesInUse removeObject:sourceImage];
				[tilesUsingImageCache removeObjectForKey:[sourceImage key]];
			}
		
		if (![imageSource canRefetchImages])
		{
			NSString	*sourceCachePath = [[self diskCachePath] stringByAppendingPathComponent:
													[self diskCacheSubPathForImageSource:imageSource]];
			[[NSFileManager defaultManager] removeFileAtPath:sourceCachePath handler:nil];
		}
		
			// Remove the image count for this source
		[self setImageCount:0 forImageSource:imageSource];
		
			// Remove images from the source from the caches.
		[[MacOSaiXImageCache sharedImageCache] removeCachedImagesFromSource:imageSource];
		[[MacOSaiXImageMatchCache sharedCache] removeMatchesFromSource:imageSource];
		
		[imageSourcesThatHaveLostImagesLock lock];
			[imageSourcesThatHaveLostImages removeObject:imageSource];
		[imageSourcesThatHaveLostImagesLock unlock];
	}
	
	if (!wasPaused)
		[self resume];
	
	if (sourceRemoved)
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeImageSourcesNotification object:self];
	
	[imageSource release];
}


- (NSArray *)imagesQueuedForSource:(id<MacOSaiXImageSource>)imageSource
{
	NSMutableArray	*queuedImages = [NSMutableArray array];
	
	[imageSourcesLock lock];
		NSArray				*mergedQueue = [[newImageQueue arrayByAddingObjectsFromArray:revisitImageQueue] arrayByAddingObjectsFromArray:imageErrorQueue];
		NSEnumerator		*queuedImageEnumerator = [mergedQueue objectEnumerator];
		MacOSaiXSourceImage	*queuedImage = nil;
		while ((queuedImage = [queuedImageEnumerator nextObject]))
			if ([queuedImage source] == imageSource)
				[queuedImages addObject:[queuedImage identifier]];
	[imageSourcesLock unlock];
	
	return queuedImages;
}


- (NSArray *)scrapImagesForSource:(id<MacOSaiXImageSource>)imageSource
{
	NSMutableArray	*scrapImages = [NSMutableArray array];
	
	[scrapLock lock];
		NSEnumerator		*scrapImageEnumerator = [scrapHeap objectEnumerator];
		MacOSaiXSourceImage	*scrapImage = nil;
		while ((scrapImage = [scrapImageEnumerator nextObject]))
			if ([scrapImage source] == imageSource)
				[scrapImages addObject:[scrapImage identifier]];
	[scrapLock unlock];
	
	return scrapImages;
}


- (void)addSourceImageToScrap:(MacOSaiXSourceImage *)sourceImage
{
	[scrapLock lock];
		if (![scrapHeap containsObject:sourceImage])
			[scrapHeap addObject:sourceImage];
	[scrapLock unlock];
}


- (MacOSaiXHandPickedImageSource *)handPickedImageSource
{
	NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
	id<MacOSaiXImageSource>	imageSource = nil;
	while ((imageSource = [imageSourceEnumerator nextObject]))
		if ([imageSource isKindOfClass:[MacOSaiXHandPickedImageSource class]])
			break;
	
	if (!imageSource)
	{
		imageSource = [[[MacOSaiXHandPickedImageSource alloc] init] autorelease];
		[self addImageSource:imageSource isFiller:NO];
	}
	
	return (MacOSaiXHandPickedImageSource *)imageSource;
}


- (void)setHandPickedImageAtPath:(NSString *)path withMatchValue:(float)matchValue forTile:(MacOSaiXTile *)tile
{
	MacOSaiXHandPickedImageSource	*handPickedSource = [self handPickedImageSource];
	
	if (![tile userChosenImageMatch])
	{
			// Increase the image count for the hand picked source.
		[enumerationCountsLock lock];
			unsigned long	currentCount = [[enumerationCounts objectForKey:[NSValue valueWithPointer:handPickedSource]] unsignedLongValue];
			[enumerationCounts setObject:[NSNumber numberWithUnsignedLong:currentCount + 1] 
								  forKey:[NSValue valueWithPointer:handPickedSource]];
			imagesFoundCount += 1;
		[enumerationCountsLock unlock];
	}
	
	MacOSaiXSourceImage	*sourceImage = [MacOSaiXSourceImage sourceImageWithImage:nil 
																	  identifier:path 
																		  source:handPickedSource];
	NSDictionary		*userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSArray arrayWithObject:tile], @"Tiles", 
										sourceImage, @"Source Image", 
										[NSNumber numberWithBool:YES], @"Handpicked", 
										nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXImageWasPlacedInMosaicNotification object:self userInfo:userInfo];
	
	[tile setUserChosenImageMatch:[MacOSaiXImageMatch imageMatchWithValue:matchValue 
															  sourceImage:sourceImage 
																	 tile:tile]];
}


- (void)removeHandPickedImageForTile:(MacOSaiXTile *)tile
{
	if ([tile userChosenImageMatch])
	{
			// Decrease the image count for the hand picked source.
		MacOSaiXHandPickedImageSource	*handPickedSource = [self handPickedImageSource];
		[enumerationCountsLock lock];
			unsigned long	currentCount = [[enumerationCounts objectForKey:[NSValue valueWithPointer:handPickedSource]] unsignedLongValue];
			[enumerationCounts setObject:[NSNumber numberWithUnsignedLong:currentCount - 1] 
								  forKey:[NSValue valueWithPointer:handPickedSource]];
			imagesFoundCount -= 1;
		[enumerationCountsLock unlock];
		
		[tile setUserChosenImageMatch:nil];
	}
}


- (NSError *)nextImageErrorForImageSource:(id<MacOSaiXImageSource>)imageSource
{
	NSError *nextImageError = nil;
	
	[enumerationCountsLock lock];
		nextImageError = [nextImageErrors objectForKey:[NSValue valueWithPointer:imageSource]];
	[enumerationCountsLock unlock];
	
	return nextImageError;
}


- (void)setNextImageError:(NSError *)error forImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[enumerationCountsLock lock];
		if (error)
			[nextImageErrors setObject:error forKey:[NSValue valueWithPointer:imageSource]];
		else
			[nextImageErrors removeObjectForKey:[NSValue valueWithPointer:imageSource]];
	[enumerationCountsLock unlock];
}


- (NSString *)diskCacheSubPathForImageSource:(id<MacOSaiXImageSource>)imageSource
{
	NSValue		*sourceKey = [NSValue valueWithPointer:imageSource];
	NSString	*subPath = [diskCacheSubPaths objectForKey:sourceKey];
	
	if (!subPath)
	{
		int			index = 1;
		NSString	*sourceCachePath = nil;
		do
		{
			subPath = [NSString stringWithFormat:@"Images From Source %d", index++];
			sourceCachePath = [[self diskCachePath] stringByAppendingPathComponent:subPath];
		}
		while ([[NSFileManager defaultManager] fileExistsAtPath:sourceCachePath]);
		
		[[NSFileManager defaultManager] createDirectoryAtPath:sourceCachePath attributes:nil];
		
		[diskCacheSubPaths setObject:subPath forKey:sourceKey];
	}
	
	return subPath;
}


- (void)setDiskCacheSubPath:(NSString *)subPath forImageSource:(id<MacOSaiXImageSource>)imageSource
{
		// Make sure the directory exists.
	NSString	*fullPath = [[self diskCachePath] stringByAppendingPathComponent:subPath];
	[[NSFileManager defaultManager] createDirectoryAtPath:fullPath attributes:nil];
	
	[diskCacheSubPaths setObject:subPath forKey:[NSValue valueWithPointer:imageSource]];
}


- (NSString *)diskCachePath
{
	return diskCachePath;
}


- (void)setDiskCachePath:(NSString *)path
{
	[diskCachePath autorelease];
	diskCachePath = [path copy];
	
	NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
	id<MacOSaiXImageSource>	imageSource = nil;
	while ((imageSource = [imageSourceEnumerator nextObject]))
		if (![imageSource canRefetchImages])
		{
			NSString	*sourceCachePath = [diskCachePath stringByAppendingPathComponent:
												[self diskCacheSubPathForImageSource:imageSource]];
			[[MacOSaiXImageCache sharedImageCache] setCacheDirectory:sourceCachePath forSource:imageSource];
		}
}


- (BOOL)imageSourcesExhausted
{
	BOOL					exhausted = YES;
	
	NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
	id<MacOSaiXImageSource>	imageSource = nil;
	while ((imageSource = [imageSourceEnumerator nextObject]))
		if ([imageSource hasMoreImages])
			exhausted = NO;
	
	return exhausted;
}


- (void)setImageSource:(id<MacOSaiXImageSource>)imageSource isFiller:(BOOL)isFiller
{
	[imageSourcesLock lock];
		if (isFiller && ![fillerImageSources containsObject:imageSource])
		{
			[fillerImageSources addObject:imageSource];
			fillerImagesChanged = YES;
		}
		else if (!isFiller && [fillerImageSources containsObject:imageSource])
		{
			[fillerImageSources removeObject:imageSource];
			fillerImagesChanged = YES;
		}
	[imageSourcesLock unlock];
}


- (BOOL)imageSourceIsFiller:(id<MacOSaiXImageSource>)imageSource
{
	if (fillerImagesChanged)
	{
		[imageSourcesLock lock];
			if (fillerImagesChanged)
			{
				[fillerImageSourcesCopy release];
				fillerImageSourcesCopy = [[NSArray arrayWithArray:fillerImageSources] retain];
				fillerImagesChanged = NO;
			}
			// else another thread made the copy
		[imageSourcesLock unlock];
	}
	
	return [fillerImageSourcesCopy containsObject:imageSource];
}


#pragma mark -
#pragma mark Image source enumeration


- (void)spawnImageSourceThreads
{
	NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
	id<MacOSaiXImageSource>	imageSource;
	
	while ((imageSource = [imageSourceEnumerator nextObject]))
		if ([imageSource hasMoreImages])
			[NSApplication detachDrawingThread:@selector(enumerateImageSourceInNewThread:) toTarget:self withObject:imageSource];
		
}


- (void)enumerateImageSourceInNewThread:(id<MacOSaiXImageSource>)imageSource
{
	[enumerationThreadCountLock lock];
		enumerationThreadCount++;
	[enumerationThreadCountLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
														object:self];
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
		// Don't allow non-thread safe QuickTime component access on this thread.
	CSSetComponentsThreadMode(kCSAcceptThreadSafeComponentsOnlyMode);
	
		// Clear out any previous error for the source.
	[self setNextImageError:nil forImageSource:imageSource];
	
		// Check if the source has any images left.
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	BOOL				sourceHasMoreImages = [[self imageSources] containsObject:imageSource] && [imageSource hasMoreImages];
	NSError				*nextImageError = nil;
	
	[pool release];
	
	while (!pausing && !paused && sourceHasMoreImages && !nextImageError)
	{
		NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
		NSImage				*image = nil;
		NSString			*imageIdentifier = nil;
		BOOL				imageIsValid = NO;
		
		NS_DURING
				// Get the next image from the source (and identifier if there is one)
			nextImageError = [imageSource nextImage:&image andIdentifier:&imageIdentifier];
			
			if (nextImageError)
				[self setNextImageError:nextImageError forImageSource:imageSource];
			else if (image)
				imageIsValid = [image isValid];
		NS_HANDLER
			#ifdef DEBUG
				NSLog(@"Exception raised while getting the next image (%@)", localException);
			#endif
		NS_ENDHANDLER
			
		if (image && imageIsValid)
		{
				// Ignore whatever DPI was set for the image.  We just care about the bitmap.
			NSImageRep	*originalRep = [[image representations] objectAtIndex:0];
			[originalRep setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
			[image setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
			
				// Only use images that are at least 16 pixels in each dimension.
			if ([image size].width > 16 && [image size].height > 16)
			{
				while (!pausing && !paused && newImageCount >= MAXIMAGEURLS && [[self imageSources] containsObject:imageSource])
					[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
				
				if ([[self imageSources] containsObject:imageSource])
				{
					[imageQueueLock lock];
						[newImageQueue addObject:[MacOSaiXSourceImage sourceImageWithImage:image 
																				identifier:imageIdentifier 
																					source:imageSource]];
						newImageCount++;
					[imageQueueLock unlock];
					
					[enumerationCountsLock lock];
						unsigned long	currentCount = [[enumerationCounts objectForKey:[NSValue valueWithPointer:imageSource]] unsignedLongValue];
						[enumerationCounts setObject:[NSNumber numberWithUnsignedLong:currentCount + 1] 
											  forKey:[NSValue valueWithPointer:imageSource]];
						imagesFoundCount += 1;
					[enumerationCountsLock unlock];
					
					if (!pausing && !paused && placeImageThreadCount == 0)
						[self placeImages];
					
					[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
				}
			}
		}
		sourceHasMoreImages = [[self imageSources] containsObject:imageSource] && [imageSource hasMoreImages];
		
		if (!image && sourceHasMoreImages)
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
			
		[pool release];
	}
	
	[enumerationThreadCountLock lock];
		enumerationThreadCount--;
	[enumerationThreadCountLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification object:self];
	
		// Send the re-enumeration notification if appropriate.
	[enumerationThreadCountLock lock];
		if (!reenumerationNotificationWasSent && [self imageUseCount] != 1 && !sourceHasMoreImages && [imageSource canReenumerateImages])
		{
				// Check if all re-enumerable image sources are exhausted.
			BOOL					reenumerableImageSourcesAreExhausted = YES;
			NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
			id<MacOSaiXImageSource>	imageSource = nil;
			while ((imageSource = [imageSourceEnumerator nextObject]))
				if ([imageSource canReenumerateImages] && [imageSource hasMoreImages])
					reenumerableImageSourcesAreExhausted = NO;
			
				// If they are and any tiles have sub-optimal matches then send the notification.
			if (reenumerableImageSourcesAreExhausted && [[self tilesWithSubOptimalUniqueMatches] count] > 0)
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicImageSourcesNeedReenumerationNotification object:self];
				reenumerationNotificationWasSent = YES;
			}
		}
	[enumerationThreadCountLock unlock];
}


- (void)setImageCount:(unsigned long)imageCount forImageSource:(id<MacOSaiXImageSource>)imageSource
{
	NSValue	*sourceKey = [NSValue valueWithPointer:imageSource];
	
	[enumerationCountsLock lock];
		NSNumber	*sourceCount = [enumerationCounts objectForKey:sourceKey];
		if (sourceCount)
			imagesFoundCount -= [sourceCount unsignedLongValue];
		
		if (imageCount > 0)
			[enumerationCounts setObject:[NSNumber numberWithUnsignedLong:imageCount]
								  forKey:sourceKey];
		else
			[enumerationCounts removeObjectForKey:sourceKey];
		
		imagesFoundCount += imageCount;
	[enumerationCountsLock unlock];
}


- (unsigned long)countOfImagesFromSource:(id<MacOSaiXImageSource>)imageSource
{
	unsigned long	enumerationCount = 0;
	
	[enumerationCountsLock lock];
		enumerationCount = [[enumerationCounts objectForKey:[NSValue valueWithPointer:imageSource]] unsignedLongValue];
	[enumerationCountsLock unlock];
	
	return enumerationCount;
}


- (unsigned long)imagesFound
{
	unsigned long	totalCount = 0;
	
	[enumerationCountsLock lock];
		totalCount = imagesFoundCount;
	[enumerationCountsLock unlock];
	
	return totalCount;
}


- (void)setImageSource:(id<MacOSaiXImageSource>)imageSource hasLostImages:(BOOL)hasLostImages
{
	[imageSourcesThatHaveLostImagesLock lock];
		if (hasLostImages)
			[imageSourcesThatHaveLostImages addObject:imageSource];
		else
			[imageSourcesThatHaveLostImages removeObject:imageSource];
	[imageSourcesThatHaveLostImagesLock unlock];
}


- (BOOL)imageSourceHasLostImages:(id<MacOSaiXImageSource>)imageSource
{
	BOOL imageSourceHasLostImages;
	
	[imageSourcesThatHaveLostImagesLock lock];
		imageSourceHasLostImages = [imageSourcesThatHaveLostImages containsObject:imageSource];
	[imageSourcesThatHaveLostImagesLock unlock];
	
	return imageSourceHasLostImages;
}


- (BOOL)allImagesCanBeRevisited
{
	BOOL allImagesCanBeRevisited;
	
	[imageSourcesThatHaveLostImagesLock lock];
		allImagesCanBeRevisited = ([imageSourcesThatHaveLostImages count] == 0);
	[imageSourcesThatHaveLostImagesLock unlock];
	
	return allImagesCanBeRevisited;
}


- (void)reenumerateImageSources
{
	BOOL	wasRunning = ![self isPaused];
	
	if (wasRunning)
		[self pause];
	
		// Reset the sub-optimal state of all tiles.
	NSEnumerator		*tileEnumerator = [tiles objectEnumerator];
	MacOSaiXTile		*tile = nil;
	while ((tile = [tileEnumerator nextObject]))
		[tile setUniqueImageMatchIsOptimal:YES];
	
		// Restart all image sources that are capable of it.
	NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
	id<MacOSaiXImageSource>	imageSource = nil;
	while ((imageSource = [imageSourceEnumerator nextObject]))
		if ([imageSource canReenumerateImages])
		{
			[imageSource reset];
			[self setImageCount:0 forImageSource:imageSource];
		}
	
	reenumerationNotificationWasSent = NO;
	
	if (wasRunning)
		[self resume];
}


#pragma mark -
#pragma mark Image matching


	// TBD: can -calculateImageMatches also use this?
- (void)setImageMatchIsInUse:(MacOSaiXImageMatch *)match
{
	NSMutableArray	*tilesUsingThisImage = [tilesUsingImageCache objectForKey:[[match sourceImage] key]];
	if (!tilesUsingThisImage)
	{
		tilesUsingThisImage = [NSMutableArray array];
		[tilesUsingImageCache setObject:tilesUsingThisImage forKey:[[match sourceImage] key]];
	}
	
	if ([tilesUsingThisImage indexOfObjectIdenticalTo:[match tile]] == NSNotFound)
	{
		[tilesUsingThisImage addObject:[match tile]];
		[sourceImagesInUse addObject:[match sourceImage]];
	}
}


- (BOOL)sourceImage:(MacOSaiXSourceImage *)sourceImage matchesBetterThanMatch:(MacOSaiXImageMatch *)currentMatch forTile:(MacOSaiXTile *)tile betterMatch:(MacOSaiXImageMatch **)match
{
	BOOL	matchesBetter = NO, 
			sourceImageIsFiller = [self imageSourceIsFiller:[sourceImage source]], 
			currentImageIsFiller = (currentMatch && [self imageSourceIsFiller:[[currentMatch sourceImage] source]]);
	
	// TODO: if current image is filler and the new image is not then it is always a better match.
	//  TBD: do we need to know the match value in that case?
	//	if (???)
	//		;
	
		// Don't bother matching if this image is filler and the tile already has a non-filler image.
	if (!currentMatch || !(!currentImageIsFiller && sourceImageIsFiller))
	{
		NSBitmapImageRep	*tileBitmap = [[[tile bitmapRep] retain] autorelease];
		NSSize				imageSize = [sourceImage size], 
							tileSize = [tileBitmap size];
		float				croppedPercentage;
		
			// See if the image will be cropped too much.
		if ((imageSize.width / tileSize.width) < (imageSize.height / tileSize.height))
			croppedPercentage = (imageSize.width * (imageSize.height - imageSize.width * tileSize.height / tileSize.width)) / 
				(imageSize.width * imageSize.height) * 100.0f;
		else
			croppedPercentage = ((imageSize.width - imageSize.height * tileSize.width / tileSize.height) * imageSize.height) / 
				(imageSize.width * imageSize.height) * 100.0f;
		
		if (croppedPercentage <= [self imageCropLimit])
		{
				// Get a rep for the image scaled to the tile's bitmap size.
			NSBitmapImageRep	*imageRep = [sourceImage imageRepAtSize:tileSize];
			
			if (imageRep)
			{
					// Calculate how well this image matches this tile.
				float		previousBest = (!currentMatch || (currentImageIsFiller && !sourceImageIsFiller) ? 1.0f : [currentMatch matchValue]);
				NSNumber	*matchValueNumber = [[MacOSaiXImageMatcher sharedMatcher] compareImageRep:tileBitmap 
																							 withMask:[tile maskRep] 
																						   toImageRep:imageRep
																						 previousBest:previousBest];
				
				if (matchValueNumber)
				{
					// The image matches the tile the same as or better than the current unique match.
					
					float				matchValue = [matchValueNumber floatValue];
					
					if (*match)
						[*match setMatchValue:matchValue];
					else
						*match = [MacOSaiXImageMatch imageMatchWithValue:matchValue 
															 sourceImage:sourceImage
																	tile:tile];
					
					BOOL	matchClearsThreshold = YES;	// TODO: only use images that match better than a user specified threshold: matchValue < pow((100.0f - threshold) / 100.0f, 2.0f)	// where threshold = 0<->100%
					
						// If this image matches better than the tile's current best or
						//    this image is the same as the tile's current best
						// then add it to the list of tile's that might get this image.
					if (matchClearsThreshold && (matchValue < previousBest || (currentImageIsFiller && !sourceImageIsFiller) || [[currentMatch sourceImage] isEqualTo:sourceImage]))
						matchesBetter = YES;	//betterMatch = newMatch;
					
						// Set the tile's best match if appropriate.
						// TBD: move to betterMatchesForSourceImage:?
					MacOSaiXImageMatch	*bestMatch = [tile bestImageMatch];
					if (!bestMatch || matchValue < [bestMatch matchValue])
						[tile setBestImageMatch:*match];
				}
				else if (NO)	// set to YES to cache partial matches
				{
					if (*match)
					{
						if (-previousBest > -[*match matchValue])
							[*match setMatchValue:-previousBest];
					}
					else
						*match = [MacOSaiXImageMatch imageMatchWithValue:-previousBest sourceImage:sourceImage tile:tile];
				}
			}
			else
				;	// Couldn't get a rep for the source image.  How to signal error?
		}
	}
	
	return matchesBetter;
}


- (NSMutableArray *)betterMatchesForSourceImage:(MacOSaiXSourceImage *)sourceImage 
{
	NSMutableArray			*betterMatches = [NSMutableArray array];
	
	NSAutoreleasePool		*methodPool = [[NSAutoreleasePool alloc] init];
	NSArray					*cachedMatches = [[MacOSaiXImageMatchCache sharedCache] matchesForSourceImage:sourceImage];
	BOOL					sourceImageIsFiller = [self imageSourceIsFiller:[sourceImage source]];
	
		// Get the list of cached matched tiles for easy lookup and check which cached matches are better than what is currently in the tiles.
	NSMutableArray			*cachedMatchesTiles = [NSMutableArray array], 
							*cachedPartialMatches = [NSMutableArray array];
	NSEnumerator			*cachedMatchesEnumerator = [cachedMatches objectEnumerator];
	MacOSaiXImageMatch		*cachedMatch = nil;
	while ((cachedMatch = [cachedMatchesEnumerator nextObject]))
	{
		MacOSaiXImageMatch	*currentMatch = [[cachedMatch tile] uniqueImageMatch];
		
		if ([cachedMatch matchValue] >= 0.0)
		{
				// Include any cached match that is better than the match currently in place.
			BOOL				currentImageIsFiller = (currentMatch && [self imageSourceIsFiller:[[currentMatch sourceImage] source]]);
			if (!currentMatch ||
				([cachedMatch matchValue] < [currentMatch matchValue] || (currentImageIsFiller && !sourceImageIsFiller)) || [[currentMatch sourceImage] isEqual:sourceImage])
				[betterMatches addObject:cachedMatch];
			
			[cachedMatchesTiles addObject:[cachedMatch tile]];
		}
		else
		{
				// If this image still doesn't match the tile any better then don't bother matching it.
			if (currentMatch && -[cachedMatch matchValue] >= [currentMatch matchValue])
				[cachedMatchesTiles addObject:[cachedMatch tile]];	
			else
				[cachedPartialMatches addObject:cachedMatch];
//				[[MacOSaiXImageMatchCache sharedCache] removeImageMatch:cachedMatch];
		}
	}
	
	[cachedMatchesTiles sortUsingFunction:compareTiles context:nil];
	
		// Calculate the match value for the tiles that were not in the cache.
	if ([cachedMatchesTiles count] < [tiles count])
	{
		NSSize					imageSize = [sourceImage size];
		
		if (NSEqualSizes(imageSize, NSZeroSize))
		{
			// We can't calculate the matches without knowing the size of the source image.  This typically will happen when an image is from a Google or flickr source and the network connection is currently down.
			betterMatches = nil;
		}
		else
		{
				// Loop through all of the tiles without cached matches and calculate how well this image matches them.
			NSMutableArray			*newMatches = [NSMutableArray array];
			int						tileCount = [tiles count], 
									tileIndex = 0, 
									cachedTileCount = [cachedMatchesTiles count], 
									cachedTileIndex = 0;
			MacOSaiXTile			*tileObjects[tileCount], 
									*cachedTileObjects[cachedTileCount];
			[tiles getObjects:(id *)&tileObjects];
			[cachedMatchesTiles getObjects:(id *)&cachedTileObjects];
			while (tileIndex < tileCount)
			{
				MacOSaiXTile			*tile = tileObjects[tileIndex];
				
				while (cachedTileIndex < cachedTileCount && cachedTileObjects[cachedTileIndex] < tile)
					cachedTileIndex += 1;
				
				if (cachedTileIndex == cachedTileCount || tile != cachedTileObjects[cachedTileIndex])
				{
					NSAutoreleasePool	*tilePool = [[NSAutoreleasePool alloc] init];
//					NSEnumerator		*partialMatchesEnumerator = [cachedPartialMatches objectEnumerator];
					MacOSaiXImageMatch	*betterMatch = nil;
					
//						// Check if there is a partial match for this tile.
//					while (betterMatch = [partialMatchesEnumerator nextObject])
//						if ([betterMatch tile] == tile)
//							break;
					
					BOOL				betterMatchIsNew = (betterMatch == nil);
					
					if ([self sourceImage:sourceImage matchesBetterThanMatch:[tile uniqueImageMatch] forTile:tile betterMatch:&betterMatch])
					{
						if (betterMatch)
							[betterMatches addObject:betterMatch];
					}
					
					if (betterMatchIsNew && betterMatch)
						[newMatches addObject:betterMatch];
					
					[tilePool release];
				}
				
				tileIndex += 1;
			}
			
			if ([newMatches count] > 0)
				[[MacOSaiXImageMatchCache sharedCache] addImageMatches:newMatches forSourceImage:sourceImage];
		}
	}
	
	// Sort the array with the best matches first.
	[betterMatches sortUsingSelector:@selector(compareByMatchThenTile:)];
	
	[methodPool release];
	
	return betterMatches;
}


- (void)checkCache
{
	NSEnumerator	*keyEnumerator = [[tilesUsingImageCache allKeys] objectEnumerator];
	NSString		*key;
	while ((key = [keyEnumerator nextObject]))
	{
		NSArray	*array = [tilesUsingImageCache objectForKey:key];
		[NSMutableArray arrayWithArray:array];
	}
}


- (NSArray *)betterMatchesForTile:(MacOSaiXTile *)tile
{
//	NSZombieEnabled = YES;
	
	NSMutableArray		*betterMatches = [NSMutableArray array];
	
		// Get the matches cached for this tile.
	NSArray				*cachedMatches = [[MacOSaiXImageMatchCache sharedCache] matchesForTile:tile];
	NSMutableArray		*cachedMatchesSourceImages = [NSMutableArray array], 
						*cachedPartialMatches = [NSMutableArray array];
	NSEnumerator		*cachedMatchesEnumerator = [cachedMatches objectEnumerator];
	MacOSaiXImageMatch	*cachedMatch = nil;
	while ((cachedMatch = [cachedMatchesEnumerator nextObject]))
	{
		MacOSaiXImageMatch	*currentMatch = [[cachedMatch tile] uniqueImageMatch];
		
		if ([cachedMatch matchValue] >= 0.0)
		{
				// Include any cached match that is better than the match currently in place.
			if (!currentMatch || [cachedMatch matchValue] < [currentMatch matchValue] || [[currentMatch sourceImage] isEqual:[cachedMatch sourceImage]] || 
				([self imageSourceIsFiller:[[cachedMatch sourceImage] source]] && (!currentMatch || ![self imageSourceIsFiller:[[currentMatch sourceImage] source]])))
				[betterMatches addObject:cachedMatch];
			
			[cachedMatchesSourceImages addObject:[cachedMatch sourceImage]];
		}
		else
		{
				// If this image still doesn't match the tile any better then don't bother matching it.
			if (currentMatch && -[cachedMatch matchValue] >= [currentMatch matchValue])
				[cachedMatchesSourceImages addObject:[cachedMatch sourceImage]];	
			else
				[cachedPartialMatches addObject:cachedMatch];
//				[[MacOSaiXImageMatchCache sharedCache] removeImageMatch:cachedMatch];
		}
	}
	
		// Find any known source images that aren't in the cache that match better.
	[tilesUsingImageCacheLock lock];
	NSMutableSet		*sourceImages = [NSMutableSet setWithSet:sourceImagesInUse];
	[tilesUsingImageCacheLock unlock];
	[scrapLock lock];
		[sourceImages addObjectsFromArray:scrapHeap];
	[scrapLock unlock];
	[sourceImages minusSet:[NSSet setWithArray:cachedMatchesSourceImages]];
	NSMutableArray		*newMatches = [NSMutableArray array];
	NSEnumerator		*sourceImageEnumerator = [sourceImages objectEnumerator];
	MacOSaiXSourceImage	*sourceImage = nil;
	while ((sourceImage = [sourceImageEnumerator nextObject]))
	{
		NSAutoreleasePool	*imagePool = [[NSAutoreleasePool alloc] init];
		NSEnumerator		*partialMatchesEnumerator = [cachedPartialMatches objectEnumerator];
		MacOSaiXImageMatch	*betterMatch = nil;
		
			// Check if there is a partial match for this tile.
		while ((betterMatch = [partialMatchesEnumerator nextObject]))
			if ([betterMatch tile] == tile)
				break;
		
		BOOL				betterMatchIsNew = (betterMatch == nil);
		
		if ([self sourceImage:sourceImage matchesBetterThanMatch:[tile uniqueImageMatch] forTile:tile betterMatch:&betterMatch])
		{
			if (betterMatch)
				[betterMatches addObject:betterMatch];
		}
		
		if (betterMatchIsNew && betterMatch)
			[newMatches addObject:betterMatch];
		
		[imagePool release];
	}
	
	if ([newMatches count] > 0)
		[[MacOSaiXImageMatchCache sharedCache] addImageMatches:newMatches forTile:tile];
	
	[betterMatches sortUsingSelector:@selector(compareByMatchThenSourceImage:)];
	
	return betterMatches;
}


- (void)revisitSourceImage:(MacOSaiXSourceImage *)sourceImage
{
	[imageQueueLock lock];
		if ([revisitImageQueue indexOfObjectIdenticalTo:sourceImage] == NSNotFound && ![revisitImageQueue containsObject:sourceImage])
		{
			[revisitImageQueue addObject:sourceImage];
			revisitImageCount = [revisitImageQueue count];
		}
	[imageQueueLock unlock];
}


- (void)removeUniqueMatchFromTile:(MacOSaiXTile *)tileToClear
{
	// The indicated tile can no longer use its current unique match without violating the image usage rules.  Try to find another image to use or else clear out the unique match.
	
		// Remove the tile/image pair from the tilesUsingImageCache.
	[tilesUsingImageCacheLock lock];
//		[self checkCache];
		NSString			*currentImageKey = [[[tileToClear uniqueImageMatch] sourceImage] key];
		NSMutableArray		*tilesUsingCurrentImage = [tilesUsingImageCache objectForKey:currentImageKey];
		if (tilesUsingCurrentImage)	// TODO: should always be true...  not after load!
		{
			[tilesUsingCurrentImage removeObjectIdenticalTo:tileToClear];
			if ([tilesUsingCurrentImage count] == 0)
			{
				[sourceImagesInUse removeObject:[[tileToClear uniqueImageMatch] sourceImage]];
				[tilesUsingImageCache removeObjectForKey:currentImageKey];
			}
		}
	[tilesUsingImageCacheLock unlock];
	
		// Figure out if we can use one of the previous unique image matches without violating the image usage rules.
		// TBD: use sourceImagesInUse instead of -recentUniqueImageMatches?
	float				tileMidX = NSMidX([[tileToClear outline] bounds]), 
						tileMidY = NSMidY([[tileToClear outline] bounds]);
	NSEnumerator		*previousMatchEnumerator = [[[tileToClear recentUniqueImageMatches] sortedArrayUsingSelector:@selector(compareByMatchThenSourceImage:)] objectEnumerator];
	MacOSaiXImageMatch	*previousMatch = nil, 
						*newMatch = nil;
	while (!newMatch && (previousMatch = [previousMatchEnumerator nextObject]))
	{
		NSArray	*tilesUsingPreviousImage;
		
		[tilesUsingImageCacheLock lock];
//			[self checkCache];
			tilesUsingPreviousImage = [NSArray arrayWithArray:[tilesUsingImageCache objectForKey:[[previousMatch sourceImage] key]]];
		[tilesUsingImageCacheLock unlock];
		
		if ([self imageUseCount] == 0 || [tilesUsingPreviousImage count] < [self imageUseCount])
		{
			NSEnumerator	*tileEnumerator = [tilesUsingPreviousImage objectEnumerator];
			MacOSaiXTile	*tileUsingPreviousImage = nil;
			float			closestDistance = INFINITY;
			while (tileUsingPreviousImage = [tileEnumerator nextObject])
			{
				NSRect	tileUsingPreviousImageBounds = [[tileUsingPreviousImage outline] bounds];
				float	widthDiff = tileMidX - NSMidX(tileUsingPreviousImageBounds), 
						heightDiff = (tileMidY - NSMidY(tileUsingPreviousImageBounds)) / originalImageAspectRatio, 
						distanceSquared = widthDiff * widthDiff + heightDiff * heightDiff;
				
				closestDistance = MIN(closestDistance, distanceSquared);
			}
			
			if (closestDistance >= minDistanceApart)
			{
					// The previously used image can be used without violating the rules.
				newMatch = previousMatch;
				
				#ifdef DEBUG
					//NSLog(@"Using previous unique match");
				#endif
			}
			else
			{
					// The previously used image might be usable if the mosaic would be improved by moving the image to this tile from another tile or tiles.
				[self revisitSourceImage:[previousMatch sourceImage]];
			}
		}
	}
	
		// Look in the scrap heap if a previous match could not be used.
	if (!newMatch)
	{
		[scrapLock lock];
		
		if ([scrapHeap count] > 0)
		{
				// Get the best match from the scrap.
//			MacOSaiXImageMatchCache	*matchCache = [MacOSaiXImageMatchCache sharedCache];
			NSEnumerator			*scrapEnumerator = [scrapHeap objectEnumerator];
			MacOSaiXSourceImage		*scrapImage = nil;
			while (scrapImage = [scrapEnumerator nextObject])
			{
				// TODO: check the cache
				NSAutoreleasePool	*imagePool = [[NSAutoreleasePool alloc] init];
				MacOSaiXImageMatch	*betterMatch = nil;
				if ([self sourceImage:scrapImage matchesBetterThanMatch:newMatch forTile:tileToClear betterMatch:&betterMatch])
				{
					[newMatch release];
					newMatch = [betterMatch retain];
				}
				
				[imagePool release];
			}
			[newMatch autorelease];
			
			if (newMatch)
				[scrapHeap removeObject:[newMatch sourceImage]];
		}
		
		[scrapLock unlock];
	}
	
		// Set the tile's new unique match.
	[imagePlacementLock lock];
		[tileToClear setUniqueImageMatch:newMatch];
	[imagePlacementLock unlock];
	
	if (newMatch)
	{
			// Update the tilesUsingImageCache.
		[tilesUsingImageCacheLock lock];
//			[self checkCache];
			NSString		*newMatchKey = [[newMatch sourceImage] key];
			NSMutableArray	*tilesUsingNewMatch = [tilesUsingImageCache objectForKey:newMatchKey];
			if (!tilesUsingNewMatch)
			{
				[sourceImagesInUse addObject:[newMatch sourceImage]];
				tilesUsingNewMatch = [NSMutableArray array];
				[tilesUsingImageCache setObject:tilesUsingNewMatch forKey:newMatchKey];
			}
			if ([tilesUsingNewMatch indexOfObjectIdenticalTo:tileToClear] == NSNotFound)
				[tilesUsingNewMatch addObject:tileToClear];
//			[self checkCache];
		[tilesUsingImageCacheLock unlock];
	}
	else
	{
		#ifdef DEBUG
//			NSLog(@"Damn, have to clear %@", tileToClear);
		#endif
	}
	
		// Revisit all images known to match this tile better than the new match.
		// This is not necessarily complete.  Some better matches may have been purged.  So the sources may still need to be re-enumerated.
		// TBD: are there any conditions that would allow some of these images not to be revisited?
		// TBD: can the list be pruned based on whether this tile's match is worse than the worst already in use for the source image?
		//		e.g. if each image can be used 10 times and the match for this tile is worse than the 10 matches currently in use then can we skip revisiting the image?
	NSArray				*betterMatches = [self betterMatchesForTile:tileToClear];
	int					skippedCount = 0;
	NSEnumerator		*betterMatchesEnumerator = [betterMatches objectEnumerator];
	MacOSaiXImageMatch	*betterMatch = nil;
	while (betterMatch = [betterMatchesEnumerator nextObject])
	{
		BOOL			revisitBetterMatchImage = YES;
		NSMutableArray	*tilesUsingBetterImage = nil;
		
		[tilesUsingImageCacheLock lock];
//			[self checkCache];
//			NSArray	*array = [tilesUsingImageCache objectForKey:[[betterMatch sourceImage] key]];
//			int		count = [array count];
//			id		buffer[count];
//			[array getObjects:buffer];
//			tilesUsingBetterImage = [[[NSMutableArray alloc] initWithObjects:buffer count:count] autorelease];
			tilesUsingBetterImage = [NSMutableArray arrayWithArray:[tilesUsingImageCache objectForKey:[[betterMatch sourceImage] key]]];
		[tilesUsingImageCacheLock unlock];
		[tilesUsingBetterImage sortUsingSelector:@selector(compareUniqueImageMatchValue:)];
		float			worstCurrentMatchValue = [[[tilesUsingBetterImage lastObject] uniqueImageMatch] matchValue];
		
		if ([betterMatch matchValue] >= worstCurrentMatchValue || [tilesUsingBetterImage count] < [self imageUseCount])
		{
				// Check if this match would be too close to any existing match.
			float			betterTileMidX = NSMidX([[[betterMatch tile] outline] bounds]), 
							betterTileMidY = NSMidY([[[betterMatch tile] outline] bounds]);
			NSEnumerator	*tileEnumerator = [tilesUsingBetterImage objectEnumerator];
			MacOSaiXTile	*tileUsingBetterImage = nil;
			while (revisitBetterMatchImage && (tileUsingBetterImage = [tileEnumerator nextObject]))
			{
				NSRect	tileUsingBetterImageBounds = [[tileUsingBetterImage outline] bounds];
				float	widthDiff = betterTileMidX - NSMidX(tileUsingBetterImageBounds), 
						heightDiff = (betterTileMidY - NSMidY(tileUsingBetterImageBounds)) / originalImageAspectRatio, 
						distanceSquared = widthDiff * widthDiff + heightDiff * heightDiff;
				
				if (distanceSquared < minDistanceApart)
					revisitBetterMatchImage = NO;
			}
		}
		
		if (revisitBetterMatchImage)
			[self revisitSourceImage:[betterMatch sourceImage]];
		else
			skippedCount += 1;
	}
	
	//NSLog(@"Avoided %d revisits", skippedCount);
}


- (NSArray *)validMatchesForImageUsageSettings:(NSArray *)possibleMatches
{
	NSMutableArray		*validMatches = [NSMutableArray array];
	
	NSAutoreleasePool	*methodPool = [[NSAutoreleasePool alloc] init];
	int					matchLimit = [self imageUseCount];
	if (matchLimit == 0)	// zero means no limit on the number of times this image can be used.
		matchLimit = [possibleMatches count];
	
		// Loop through the list of better matches and pick the first items (up to the limit) that aren't too close together.
	NSEnumerator		*possibleMatchEnumerator = [possibleMatches objectEnumerator];
	MacOSaiXImageMatch	*possibleMatch = nil, 
						*validMatchesObjects[[possibleMatches count]];
	
	while ([validMatches count] < matchLimit && (possibleMatch = [possibleMatchEnumerator nextObject]))
	{
			// Find the closest match already picked.
		MacOSaiXTile		*possibleMatchTile = [possibleMatch tile];
		float				closestDistance = INFINITY;
		unsigned			validMatchIndex = 0,
							validMatchCount = [validMatches count];
		
		[validMatches getObjects:(id *)validMatchesObjects];
		
		for (; validMatchIndex < validMatchCount && closestDistance >= minDistanceApart; validMatchIndex++)
		{
			MacOSaiXImageMatch	*validMatch = validMatchesObjects[validMatchIndex];
			NSPoint				possibleMidPoint = [possibleMatchTile outlineMidPoint], 
								validMidPoint = [[validMatch tile] outlineMidPoint];
			float				widthDiff = possibleMidPoint.x - validMidPoint.x, 
								heightDiff = (possibleMidPoint.y - validMidPoint.y) / originalImageAspectRatio, 
								distanceSquared = widthDiff * widthDiff + heightDiff * heightDiff;
			
			closestDistance = MIN(closestDistance, distanceSquared);
		}
		
			// If this match isn't too close to any of the already picked matches then use it.
		if (closestDistance >= minDistanceApart)
			[validMatches addObject:possibleMatch];
	}
	
	[methodPool release];
	
	return validMatches;
}


// TBD: attempted to factor this out but there are many dependencies...
//
//- (NSArray *)placeValidImageMatches:(NSArray *)validMatches 
//				   animatePlacement:(BOOL)animatePlacement
//{
//	NSMutableArray		*placedMatches = [NSMutableArray array];
//	
//	NSAutoreleasePool	*methodPool = [[NSAutoreleasePool alloc] init];
//	MacOSaiXSourceImage	*imageToPlace = [[validMatches objectAtIndex:0] sourceImage];
//	
//	[imagePlacementLock lock];
//	
//		// Figure out which matches are still better in case another placement thread slipped in and updated any of the tiles with a better match.
//	NSMutableArray		*stillValidMatches = [NSMutableArray array], 
//						*updatedTiles = [NSMutableArray array];
//	BOOL				revisitImage = NO;
//	NSEnumerator		*validMatchesEnumerator = [validMatches objectEnumerator];
//	MacOSaiXImageMatch	*validMatch = nil;
//	while (validMatch = [validMatchesEnumerator nextObject])
//	{
//		MacOSaiXImageMatch	*currentMatch = [[validMatch tile] uniqueImageMatch];
//		BOOL				validImageIsFiller = [self imageSourceIsFiller:[[validMatch sourceImage] source]], 
//												currentImageIsFiller = (currentMatch && [self imageSourceIsFiller:[[currentMatch sourceImage] source]]);
//		
//		if (!currentMatch || (currentImageIsFiller && !validImageIsFiller) || [validMatch matchValue] <= [currentMatch matchValue])
//		{
//			[stillValidMatches addObject:validMatch];
//			[updatedTiles addObject:[validMatch tile]];
//		}
//		else
//			revisitImage = YES;
//	}
//	
//	if (animatePlacement)
//	{
//			// Let anyone who cares (currently the mosaic view) know that a new image was placed in one or more tiles.  The mosaic view will block until it can animate the placement of the image if the user has chosen to animate all placements.
//		NSDictionary	*userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//			updatedTiles, @"Tiles", 
//			imageToPlace, @"Source Image", 
//			nil];
//		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXImageWasPlacedInMosaicNotification object:self userInfo:userInfo];
//	}
//	
//		// Update the winning tiles.
//	NSEnumerator		*matchesToUpdateEnumerator = [stillValidMatches objectEnumerator];
//	MacOSaiXImageMatch	*matchToUpdate = nil;
//	while (!pausing && (matchToUpdate = [matchesToUpdateEnumerator nextObject]))
//	{
//		MacOSaiXTile		*tile = [matchToUpdate tile];
//		
//		MacOSaiXImageMatch	*currentMatch = [tile uniqueImageMatch];
//		if (!currentMatch || ![[currentMatch sourceImage] isEqual:imageToPlace])
//		{
//			if (currentMatch)
//			{
//				// Add the tile's current image back to the queue so it can potentially get re-used by other tiles.
//				
//					// Remove this tile from the list of tiles that the current image is used by.
//				[tilesUsingImageCacheLock lock];
//				NSString		*currentImageKey = [[currentMatch sourceImage] key];
//				NSMutableArray	*tilesUsingCurrentImage = [tilesUsingImageCache objectForKey:currentImageKey];
//				[tilesUsingCurrentImage removeObjectIdenticalTo:tile];
//				if ([tilesUsingCurrentImage count] == 0)
//				{
//					[sourceImagesInUse removeObject:[currentMatch sourceImage]];
//					[tilesUsingImageCache removeObjectForKey:currentImageKey];
//				}
//				[tilesUsingImageCacheLock unlock];
//				
//				[self revisitSourceImage:[currentMatch sourceImage]];
//			}
//			
//				// Update the tile with the new match.
//			[tile setUniqueImageMatch:matchToUpdate];
//			
//			[placedMatches addObject:matchToUpdate];
//		}
//		
//			// This tile does not need to be cleared.
//		if ([tilesToClear containsObject:tile])
//			[tilesToClear removeObject:tile];
//	}
//	
//	if (!matchToUpdate)
//	{
//		updateCompleted = YES;
//		
//		[tilesUsingImageCacheLock lock];
//			[tilesUsingImageCache setObject:tilesUsingThisImage forKey:[imageToPlace key]];
//			[sourceImagesInUse addObject:imageToPlace];
//		[tilesUsingImageCacheLock unlock];
//	}
//	
//	[imagePlacementLock unlock];
//	
//	if (revisitImage)
//		[self revisitSourceImage:imageToPlace];
//	
//	[methodPool release];
//	
//	return placedMatches;
//}


- (void)placeImages
{
	int			cpuCount = 2;
	size_t		intSize = sizeof(cpuCount);
	if (sysctlbyname("hw.ncpu", &cpuCount, &intSize, NULL, 0) != 0)
		cpuCount = 2;
	
	[calculateImageMatchesThreadLock lock];
		if (placeImageThreadCount < cpuCount)
		{
			while (placeImageThreadCount < cpuCount)
			{
				placeImageThreadCount++;
				[NSApplication detachDrawingThread:@selector(placeNextImage) toTarget:self withObject:nil];
			}
			
			NS_DURING
				[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification object:self];
			NS_HANDLER
				#ifdef DEBUG
					[localException raise];
				#endif
			NS_ENDHANDLER
		}
	[calculateImageMatchesThreadLock unlock];
}


- (void)placeNextImage
{
//	NSZombieEnabled = YES;
	
    NSAutoreleasePool		*threadPool = [[NSAutoreleasePool alloc] init];

		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
		// Don't allow non-thread safe QuickTime component access on this thread.
	if (CSSetComponentsThreadMode)
		CSSetComponentsThreadMode(kCSAcceptThreadSafeComponentsOnlyMode);
	
	MacOSaiXImageCache		*imageCache = [MacOSaiXImageCache sharedImageCache];
	
	NS_DURING
		[imageQueueLock lock];
		
		if ([newImageQueue count] == 0 && [revisitImageQueue count] == 0)
			[imageQueueLock unlock];
		else
		{
			MacOSaiXSourceImage		*imageToPlace = nil;
			BOOL					imageToPlaceIsNew = NO;
			
				// Decide whether to place a new image or revisit a previously placed one.
			if ([newImageQueue count] > 0 && (revisitImageCount == 0 || revisitImageCount < (random() % ([tiles count] * [tiles count]))))
			{
					// Use the first image on the new queue.
				imageToPlace = [[[newImageQueue objectAtIndex:0] retain] autorelease];
				[newImageQueue removeObjectAtIndex:0];
				newImageCount--;
				imageToPlaceIsNew = YES;
			}
			else
			{
					// Use the first image on the revisit queue.
				imageToPlace = [[[revisitImageQueue objectAtIndex:0] retain] autorelease];
				[revisitImageQueue removeObjectAtIndex:0];
				revisitImageCount--;
				
				//NSLog(@"Revisiting %@", [imageToPlace identifier]);
			}
			
			[imageQueueLock unlock];
			
			if ([imageToPlace image])
			{
					// Add this image to the in-memory cache.  If the image source does not support refetching images then the image will be also be saved into this mosaic's document.
				[imageCache cacheSourceImage:imageToPlace];
			}
			
			BOOL			updateCompleted = NO;
			NSMutableArray	*tilesToClear = nil;
			
				// Get the list of tiles that would be improved by using this image.
			NSArray			*betterMatches = [self betterMatchesForSourceImage:imageToPlace];
			if (!betterMatches)
			{
				// The better matches for this image could not be determined for some reason.
				[imageQueueLock lock];
					[imageErrorQueue addObject:imageToPlace];
					imageErrorCount++;
				[imageQueueLock unlock];
			}
			else if ([betterMatches count] == 0)
			{
				// This image would not improve any of the tiles.
				
				[scrapLock lock];
					if (![scrapHeap containsObject:imageToPlace])
					{
							// Keep a reference to the image in a scrap heap in case we need to fill a blank tile later.
						[scrapHeap insertObject:imageToPlace atIndex:0];
						if ([scrapHeap count] > SCRAP_LIMIT)
						{
							id<MacOSaiXImageSource>	lastSource = [(MacOSaiXSourceImage *)[scrapHeap lastObject] source];
							
							[imageSourcesThatHaveLostImagesLock lock];
								[imageSourcesThatHaveLostImages addObject:lastSource];
							[imageSourcesThatHaveLostImagesLock unlock];
							
							[scrapHeap removeLastObject];
						}
					}
				[scrapLock unlock];
				
				updateCompleted = YES;
			}
			else if (!pausing)
			{
				// Figure out which tiles should be set to use the image based on the user's settings.
				
				NSArray	*validMatches = [self validMatchesForImageUsageSettings:betterMatches];
				
				if ([validMatches count] == 0)
					updateCompleted = YES;
				else
				{
					// This image can be used in one or more tiles.
					
					NSAutoreleasePool	*placementPool = [[NSAutoreleasePool alloc] init];
					BOOL				revisitImage = NO;
					
						// Get the list of tiles currently using this image.
					NSMutableArray	*tilesUsingThisImage = nil;
					[tilesUsingImageCacheLock lock];
//						[self checkCache];
						tilesUsingThisImage = [NSMutableArray arrayWithArray:[tilesUsingImageCache objectForKey:[imageToPlace key]]];
					[tilesUsingImageCacheLock unlock];
					
						// Make a copy of the list of tiles using this image to keep track of which tiles should be cleared at the end.
					tilesToClear = [[NSMutableArray alloc] initWithArray:tilesUsingThisImage];
					
					[imagePlacementLock lock];
					{
							// Figure out which matches are still better in case another placement thread slipped in and updated any of the tiles with a better match.
						NSMutableArray		*stillValidMatches = [NSMutableArray array], 
											*updatedTiles = [NSMutableArray array];
						NSEnumerator		*validMatchesEnumerator = [validMatches objectEnumerator];
						MacOSaiXImageMatch	*validMatch = nil;
						while (validMatch = [validMatchesEnumerator nextObject])
						{
							MacOSaiXImageMatch	*currentMatch = [[validMatch tile] uniqueImageMatch];
							BOOL				validImageIsFiller = [self imageSourceIsFiller:[[validMatch sourceImage] source]], 
												currentImageIsFiller = (currentMatch && [self imageSourceIsFiller:[[currentMatch sourceImage] source]]);
							
							if (!currentMatch || (currentImageIsFiller && !validImageIsFiller) || [validMatch matchValue] <= [currentMatch matchValue])
							{
								[stillValidMatches addObject:validMatch];
								[updatedTiles addObject:[validMatch tile]];
							}
							else
								revisitImage = YES;
						}
						
						if (imageToPlaceIsNew && !pausing && [self animateImagePlacements])
						{
							// Let anyone who cares (currently the mosaic view) know that a new image was placed in one or more tiles.  The mosaic view will block until it can animate the placement of the image if the user has chosen to animate all placements.
							NSDictionary	*userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
															updatedTiles, @"Tiles", 
															imageToPlace, @"Source Image", 
															nil];
							[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXImageWasPlacedInMosaicNotification object:self userInfo:userInfo];
						}
						
							// Update the winning tiles.
						NSEnumerator		*matchesToUpdateEnumerator = [stillValidMatches objectEnumerator];
						MacOSaiXImageMatch	*matchToUpdate = nil;
						while (!pausing && (matchToUpdate = [matchesToUpdateEnumerator nextObject]))
						{
							MacOSaiXTile		*tile = [matchToUpdate tile];
							
							MacOSaiXImageMatch	*currentMatch = [tile uniqueImageMatch];
							if (!currentMatch || ![[currentMatch sourceImage] isEqual:imageToPlace])
							{
								if (currentMatch)
								{
									// Add the tile's current image back to the queue so it can potentially get re-used by other tiles.
									
										// Remove this tile from the list of tiles that the current image is used by.
									[tilesUsingImageCacheLock lock];
//										[self checkCache];
										NSString		*currentImageKey = [[currentMatch sourceImage] key];
										NSMutableArray	*tilesUsingCurrentImage = [tilesUsingImageCache objectForKey:currentImageKey];
										[tilesUsingCurrentImage removeObjectIdenticalTo:tile];
										if ([tilesUsingCurrentImage count] == 0)
										{
											[sourceImagesInUse removeObject:[currentMatch sourceImage]];
											[tilesUsingImageCache removeObjectForKey:currentImageKey];
										}
//										[self checkCache];
									[tilesUsingImageCacheLock unlock];
									
									[self revisitSourceImage:[currentMatch sourceImage]];
								}
								
									// Update the tile with the new match.
								[tile setUniqueImageMatch:matchToUpdate];
								
									// Remember that this tile is using this image.
								if ([tilesUsingThisImage indexOfObjectIdenticalTo:tile] == NSNotFound)
									[tilesUsingThisImage addObject:tile];
							}
							
								// This tile does not need to be cleared.
							if ([tilesToClear containsObject:tile])
								[tilesToClear removeObject:tile];
						}
						
						if (!matchToUpdate)
						{
							updateCompleted = YES;
							
							#ifdef DEBUG
								NSMutableArray	*test = [NSMutableArray arrayWithArray:tilesUsingThisImage];
								if ([test count] < 0)
									NSLog(@"huh?");
							#endif
							[tilesUsingImageCacheLock lock];
//								[self checkCache];
								[tilesUsingImageCache setObject:tilesUsingThisImage forKey:[imageToPlace key]];
								[sourceImagesInUse addObject:imageToPlace];
//								[self checkCache];
							[tilesUsingImageCacheLock unlock];
						}
					}
					[imagePlacementLock unlock];
					
					[placementPool release];
					
					[tilesToClear autorelease];
					
					if (revisitImage)
						[self revisitSourceImage:imageToPlace];
				}
			}
			
			if (updateCompleted)
			{
					// Remove this image from any tiles that can no longer use it.
				NSEnumerator		*tilesToClearEnumerator = [tilesToClear objectEnumerator];
				MacOSaiXTile		*tileToClear = nil;
				while (tileToClear = [tilesToClearEnumerator nextObject])
				{
					MacOSaiXSourceImage	*currentImage = nil;
					[imagePlacementLock lock];
						currentImage = [[tileToClear uniqueImageMatch] sourceImage];
					[imagePlacementLock unlock];
					if ([currentImage isEqual:imageToPlace])
						[self removeUniqueMatchFromTile:tileToClear];
					#ifdef DEBUG
					else
						NSLog(@"Avoided a clear");
					#endif
				}
				
				BOOL				imageIsInUse = NO;
				[tilesUsingImageCacheLock lock];
//					[self checkCache];
					imageIsInUse = ([[tilesUsingImageCache objectForKey:[imageToPlace key]] count] > 0);
				[tilesUsingImageCacheLock unlock];
				
				[scrapLock lock];
					if (!imageIsInUse && ![scrapHeap containsObject:imageToPlace])
					{
						[scrapHeap insertObject:imageToPlace atIndex:0];
						if ([scrapHeap count] > SCRAP_LIMIT)
							[scrapHeap removeLastObject];
					}
				[scrapLock unlock];
				
					// If this image isn't any tile's unique match and it can't be refetched then make sure it isn't a tile's best match.
				if (!imageIsInUse && ![[imageToPlace source] canRefetchImages])
				{
					NSEnumerator			*tileEnumerator = [tiles objectEnumerator];
					MacOSaiXTile			*tile = nil;
					while (!imageIsInUse && (tile = [tileEnumerator nextObject]))
						if ([[[tile bestImageMatch] sourceImage] isEqual:imageToPlace])
						{
							imageIsInUse = YES;
							break;
						}
				}
					
					// If this image isn't used by any tile and it can't be refetched then remove it from the disk cache.
				if (!imageIsInUse && ![[imageToPlace source] canRefetchImages])
					[imageCache removeSourceImage:imageToPlace];
			}
			else
				[self revisitSourceImage:imageToPlace];
		}
		
	NS_HANDLER
		if (!lastExceptionLogDate || [lastExceptionLogDate timeIntervalSinceNow] < -30.0)
		{
			NSLog(@"Failed to calculate image matches: %@", [localException reason]);
			
			[lastExceptionLogDate release];
			lastExceptionLogDate = [[NSDate date] retain];
		}
	NS_ENDHANDLER
	
	[calculateImageMatchesThreadLock lock];
		placeImageThreadCount--;
	[calculateImageMatchesThreadLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification object:self];
	
		// Queue up additional threads if there are more images to place.
	if (!pausing && !paused && (newImageCount > 0 || revisitImageCount > 0))
		[self placeImages];
	
		// clean up and shutdown this thread
    [threadPool release];
}


- (float)averageMatchValue
{
	return overallMatch / [tiles count];
}


#pragma mark -
#pragma mark Status


- (BOOL)isBusy
{
	return (tileBitmapExtractionThreadAlive || enumerationThreadCount > 0 || placeImageThreadCount > 0);
}


- (NSString *)statusAndTooltip:(NSMutableString *)tooltip
{
	NSString	*statusKey = nil;
	int			nextImageErrorCount = 0;
	
	[tooltip setString:@""];
	
	[enumerationCountsLock lock];
		nextImageErrorCount = [nextImageErrors count];
	[enumerationCountsLock unlock];
	
	if (![self originalImage])
		statusKey = @"You have not chosen the original image";
	else if ([[self tiles] count] == 0)
		statusKey = @"You have not set the tile shapes";
	else if ([[self imageSources] count] == 0)
		statusKey = @"You have not added any image sources";
	else if (![self wasStarted] && ![self imageSourcesExhausted])
		statusKey = @"Click the Start Mosaic button in the toolbar.";
	else if ([self isPausing])
		statusKey = @"Pausing...";
	else if ([self isPaused])
		statusKey = @"Paused";
	else if (tileBitmapExtractionThreadAlive)
		statusKey = @"Extracting tiles from original image...";	// TODO: include the % complete
	else if (placeImageThreadCount > 0)
	{
		if (newImageCount > 0)
			statusKey = @"Placing images...";
		else
		{
			#ifdef DEBUG
				statusKey = [NSString stringWithFormat:@"Re-placing %d images...", revisitImageCount];
			#else
				statusKey = @"Optimizing image placement...";
			#endif
		}
		
		[tooltip setString:[NSString stringWithFormat:@"Optimizing placement of %d images", revisitImageCount]];
	}
	else if (enumerationThreadCount > 0)
		statusKey = @"Looking for new images...";
	else if (nextImageErrorCount == 1)
		statusKey = @"An image source had a problem looking for new images";
	else if (nextImageErrorCount > 1)
		statusKey = @"Image sources had problems looking for new images";
	else if (imageErrorCount > 0)
	{
		statusKey = @"Some images could not be placed.";
		[tooltip setString:@"Make sure you are connected to the Internet then pause and resume the mosaic."];
	}
	else
		statusKey = @"Done";
	
	return [[NSBundle mainBundle] localizedStringForKey:statusKey value:@"" table:nil];
}


- (void)setWasStarted:(BOOL)wasStarted
{
	if (wasStarted != mosaicStarted)
	{
		mosaicStarted = wasStarted;
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
	}
}


- (BOOL)wasStarted
{
	return mosaicStarted;
}


#pragma mark -
#pragma mark Pausing/resuming


- (BOOL)isPaused
{
	return paused;
}


- (BOOL)isPausing
{
	return pausing;
}


- (void)pause
{
	if (!paused)
	{
			// Tell the worker threads to exit.
		pausing = YES;
		
			// Wait for any queued images to get processed.
			// TBD: can we condition lock here instead of poll?
			// TBD: this could block the main thread
		while ([self isBusy])
		{
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		}
		
		paused = YES;
		pausing = NO;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
															object:self];
	}
}


- (void)resume
{
	if (paused && originalImage)
	{
		mosaicStarted = YES;
		
		pausing = NO;
		
		[self updateMinDistanceApart];
		
			// Finish extracting any tile bitmaps.
		if ([tilesWithoutBitmaps count] > 0)
			[NSThread detachNewThreadSelector:@selector(extractTileBitmaps) toTarget:self withObject:nil];
		
		[imageQueueLock lock];
			[revisitImageQueue addObjectsFromArray:imageErrorQueue];
			[imageErrorQueue removeAllObjects];
			revisitImageCount = [revisitImageQueue count];
			imageErrorCount = 0;
		[imageQueueLock unlock];
		
		if ((newImageCount > 0 || revisitImageCount > 0) && placeImageThreadCount == 0)
			[self placeImages];
			
			// Start or restart the image sources
		[self spawnImageSourceThreads];
		
		paused = NO;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
															object:self];
	}
}


- (void)documentIsClosing
{
	documentIsClosing = YES;
	
	[self pause];
}


#pragma mark -
#pragma mark Image placement animation


- (void)setAnimateImagePlacements:(BOOL)flag
{
	animateImagePlacements = flag;
}


- (BOOL)animateImagePlacements
{
	return animateImagePlacements;
}


- (void)setAnimateAllImagePlacements:(BOOL)flag
{
	animateAllImagePlacements = flag;
}


- (BOOL)animateAllImagePlacements
{
	return animateAllImagePlacements;
}


- (void)setImagePlacementFullSizedDuration:(int)duration
{
	imagePlacementFullSizedDuration = duration;
}


- (int)imagePlacementFullSizedDuration
{
	return imagePlacementFullSizedDuration;
}


- (void)setDelayBetweenImagePlacements:(int)delay
{
	delayBetweenImagePlacements = delay;
}


- (int)delayBetweenImagePlacements
{
	return delayBetweenImagePlacements;
}


- (void)setImagePlacementMessage:(NSString *)message
{
	[imagePlacementMessage release];
	imagePlacementMessage = [message copy];
}


- (NSString *)imagePlacementMessage
{
	return imagePlacementMessage;
}


- (void)setIncludeSourceImageWithImagePlacementMessage:(BOOL)flag
{
	includeSourceImageWithImagePlacementMessage = flag;
}


- (BOOL)includeSourceImageWithImagePlacementMessage
{
	return includeSourceImageWithImagePlacementMessage;
}


#pragma mark -


- (void)dealloc
{
	if (![[NSApp delegate] isQuitting])
	{
		NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
		id<MacOSaiXImageSource>	imageSource = nil;
		while (imageSource = [imageSourceEnumerator nextObject])
		{
			[[MacOSaiXImageCache sharedImageCache] removeCachedImagesFromSource:imageSource];
			[[MacOSaiXImageMatchCache sharedCache] removeMatchesFromSource:imageSource];
		}
	}
	
	[imageSources release];
	[fillerImageSources release];
	[fillerImageSourcesCopy release];
	[imageSourcesLock release];
	
	[diskCachePath release];
	[diskCacheSubPaths release];
	
    [originalImage release];
    [imageQueueLock release];
	[enumerationThreadCountLock release];
	[enumerationCountsLock release];
	[enumerationCounts release];
	[nextImageErrors release];
	[sourceImagesInUse release];
	[tilesUsingImageCacheLock release];
	[tilesUsingImageCache release];
	[imageErrorQueue release];
	[scrapLock release];
	[scrapHeap release];
	[calculateImageMatchesThreadLock release];
	[lastExceptionLogDate release];
    [tiles release];
	[tilesWithoutBitmapsLock release];
	[tilesWithoutBitmaps release];
	[imageSourcesThatHaveLostImages release];
	[imageSourcesThatHaveLostImagesLock release];
	
    [tileShapes release];
	[newImageQueue release];
    [revisitImageQueue release];
	[imagePlacementMessage release];
	
    [super dealloc];
}


@end

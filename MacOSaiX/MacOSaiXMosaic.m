//
//  MacOSaiXMosaic.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/4/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXMosaic.h"

#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageMatcher.h"


	// The maximum size of the image URL queue
#define MAXIMAGEURLS 4


	// Notifications
NSString	*MacOSaiXMosaicDidChangeStateNotification = @"MacOSaiXMosaicDidChangeStateNotification";
NSString	*MacOSaiXMosaicDidChangeBusyStateNotification = @"MacOSaiXMosaicDidChangeBusyStateNotification";
NSString	*MacOSaiXOriginalImageDidChangeNotification = @"MacOSaiXOriginalImageDidChangeNotification";
NSString	*MacOSaiXTileImageDidChangeNotification = @"MacOSaiXTileImageDidChangeNotification";
NSString	*MacOSaiXTileShapesDidChangeStateNotification = @"MacOSaiXTileShapesDidChangeStateNotification";


@interface MacOSaiXMosaic (PrivateMethods)
- (void)addTile:(MacOSaiXTile *)tile;
- (void)lockWhilePaused;
- (void)setImageCount:(unsigned long)imageCount forImageSource:(id<MacOSaiXImageSource>)imageSource;
@end


@implementation MacOSaiXMosaic


- (id)init
{
    if (self = [super init])
    {
		paused = YES;
		
		originalImageAspectRatio = 1.0;	// avoid any divide-by-zero errors
		
		imageSources = [[NSMutableArray alloc] init];
		imageSourcesLock = [[NSLock alloc] init];
		tilesWithoutBitmaps = [[NSMutableArray alloc] init];
		diskCacheSubPaths = [[NSMutableDictionary alloc] init];
		
			// This queue is populated by the enumeration threads and accessed by the matching thread.
		imageQueue = [[NSMutableArray alloc] init];
		imageQueueLock = [[NSLock alloc] init];
		revisitQueue = [[NSMutableArray alloc] init];
		
		calculateImageMatchesThreadLock = [[NSLock alloc] init];
		betterMatchesCache = [[NSMutableDictionary alloc] init];
		
		enumerationThreadCountLock = [[NSLock alloc] init];
		enumerationCountsLock = [[NSLock alloc] init];
		enumerationCounts = [[NSMutableDictionary alloc] init];
		
		NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
		[self setImageUseCount:[[defaults objectForKey:@"Image Use Count"] intValue]];
		[self setImageReuseDistance:[[defaults objectForKey:@"Image Reuse Distance"] intValue]];
		[self setImageCropLimit:[[defaults objectForKey:@"Image Crop Limit"] intValue]];
	}
	
    return self;
}


- (void)reset
{
		// Stop any worker threads.
	[self pause];
	
		// Reset all of the image sources.
	NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
	id<MacOSaiXImageSource>	imageSource;
	while (imageSource = [imageSourceEnumerator nextObject])
	{
		[imageSource reset];
		[self setImageCount:0 forImageSource:imageSource];
	}
	
		// Reset all of the tiles.
	NSEnumerator			*tileEnumerator = [tiles objectEnumerator];
	MacOSaiXTile			*tile = nil;
	while (tile = [tileEnumerator nextObject])
	{
		[tile resetBitmapRepAndMask];
		[tile setBestImageMatch:nil];
		[tile setUniqueImageMatch:nil];
	}
	[tilesWithoutBitmaps removeAllObjects];
	[tilesWithoutBitmaps addObjectsFromArray:tiles];
	
		// Clear the cache of better matches
	[betterMatchesCache removeAllObjects];
	
	mosaicStarted = NO;
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
		[self setAspectRatio:[originalImage size].width / [originalImage size].height];

			// Ignore whatever DPI was set for the image.  We just care about the bitmap.
		NSImageRep	*originalRep = [[originalImage representations] objectAtIndex:0];
		[originalRep setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
		[originalImage setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXOriginalImageDidChangeNotification 
															object:self];
	}
}


- (NSImage *)originalImage
{
	return [[originalImage retain] autorelease];
}


- (void)setAspectRatio:(float)ratio
{
	originalImageAspectRatio = ratio;
	
	if (!originalImage)
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXOriginalImageDidChangeNotification
															object:self];
}


- (float)aspectRatio
{
	return originalImageAspectRatio;
}


#pragma mark -
#pragma mark Tile management


- (void)addTile:(MacOSaiXTile *)tile
{
	if (!tiles)
		tiles = [[NSMutableArray array] retain];
	
	[tiles addObject:tile];
}


- (void)setTileShapes:(id<MacOSaiXTileShapes>)inTileShapes creatingTiles:(BOOL)createTiles
{
	[self pause];
	
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

			// Create a new tile collection from the outlines.
		NSEnumerator	*tileOutlineEnumerator = [tileOutlines objectEnumerator];
		NSBezierPath	*tileOutline = nil;
		while (tileOutline = [tileOutlineEnumerator nextObject])
			[self addTile:[[[MacOSaiXTile alloc] initWithOutline:tileOutline fromMosaic:self] autorelease]];
		
			// Indicate that the average tile size needs to be recalculated.
		averageUnitTileSize = NSZeroSize;
		
		[self reset];
	}
	
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


- (void)tileDidExtractBitmap:(MacOSaiXTile *)tile
{
	[tilesWithoutBitmaps removeObjectIdenticalTo:tile];
	
	if ([tilesWithoutBitmaps count] == 0)
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification 
															object:self];
}


- (BOOL)allTilesHaveExtractedBitmaps
{
	return ([self wasStarted] && [tilesWithoutBitmaps count] == 0);
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


- (void)addImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[imageSourcesLock lock];
		[imageSources addObject:imageSource];
		
		if (![imageSource canRefetchImages])
		{
			NSString	*sourceCachePath = [[self diskCachePath] stringByAppendingPathComponent:
													[self diskCacheSubPathForImageSource:imageSource]];
			[[MacOSaiXImageCache sharedImageCache] setCacheDirectory:sourceCachePath forSource:imageSource];
		}
	[imageSourcesLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
	
	if (![self isPaused])
		[NSApplication detachDrawingThread:@selector(enumerateImageSourceInNewThread:) 
								  toTarget:self 
								withObject:imageSource];

		// Auto start the mosaic if possible and the user wants to.
	if ([self tileShapes] && [tiles count] > 0 && [[NSUserDefaults standardUserDefaults] boolForKey:@"Automatically Start Mosaics"])
		[self resume];
}


- (void)removeImageSource:(id<MacOSaiXImageSource>)imageSource
{
	BOOL	wasPaused = [self isPaused];
	if (!wasPaused)
		[self pause];
	
	[imageSource retain];
	
	BOOL	sourceRemoved = NO;
	[imageSourcesLock lock];
		if ([imageSources containsObject:imageSource])
		{
			[imageSources removeObject:imageSource];
			sourceRemoved = YES;
		}
	[imageSourcesLock unlock];
	
	if (sourceRemoved)
	{
			// Remove any images from this source that are waiting to be matched.
		[imageQueueLock lock];
			NSEnumerator		*imageQueueDictEnumerator = [[NSArray arrayWithArray:imageQueue] objectEnumerator];
			NSDictionary		*imageQueueDict = nil;
			while (imageQueueDict = [imageQueueDictEnumerator nextObject])
				if ([imageQueueDict objectForKey:@"Image Source"] == imageSource)
					[imageQueue removeObjectIdenticalTo:imageQueueDict];
		[imageQueueLock unlock];
		
			// Remove any images from this source from the tiles.
		NSEnumerator		*tileEnumerator = [tiles objectEnumerator];
		MacOSaiXTile		*tile = nil;
		while (tile = [tileEnumerator nextObject])
		{
			if ([[tile userChosenImageMatch] imageSource] == imageSource)
				[tile setUserChosenImageMatch:nil];
			if ([[tile uniqueImageMatch] imageSource] == imageSource)
				[tile setUniqueImageMatch:nil];
			if ([[tile bestImageMatch] imageSource] == imageSource)
				[tile setBestImageMatch:nil];
		}
		
		if (![imageSource canRefetchImages])
		{
			NSString	*sourceCachePath = [[self diskCachePath] stringByAppendingPathComponent:
													[self diskCacheSubPathForImageSource:imageSource]];
			[[NSFileManager defaultManager] removeFileAtPath:sourceCachePath handler:nil];
		}
		
			// Remove the image count for this source
		[self setImageCount:0 forImageSource:imageSource];
		
			// Remove any cached images for this source
		[[MacOSaiXImageCache sharedImageCache] removeCachedImagesFromSource:imageSource];
		
		if (!wasPaused)
			[self resume];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
	}
	
	[imageSource release];
}


- (MacOSaiXHandPickedImageSource *)handPickedImageSource
{
	NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
	id<MacOSaiXImageSource>	imageSource = nil;
	while (imageSource = [imageSourceEnumerator nextObject])
		if ([imageSource isKindOfClass:[MacOSaiXHandPickedImageSource class]])
			break;
	
	if (!imageSource)
	{
		imageSource = [[[MacOSaiXHandPickedImageSource alloc] init] autorelease];
		[self addImageSource:imageSource];
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
		[enumerationCountsLock unlock];
	}
	
	[tile setUserChosenImageMatch:[MacOSaiXImageMatch imageMatchWithValue:matchValue 
													   forImageIdentifier:path 
														  fromImageSource:handPickedSource 
																  forTile:tile]];
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
		[enumerationCountsLock unlock];
		
		[tile setUserChosenImageMatch:nil];
	}
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
	while (imageSource = [imageSourceEnumerator nextObject])
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
	while (imageSource = [imageSourceEnumerator nextObject])
		if ([imageSource hasMoreImages])
			exhausted = NO;
	
	return exhausted;
}


#pragma mark -
#pragma mark Image source enumeration


- (void)spawnImageSourceThreads
{
	NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
	id<MacOSaiXImageSource>	imageSource;
	
	while (imageSource = [imageSourceEnumerator nextObject])
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
	
		// Check if the source has any images left.
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	BOOL				sourceHasMoreImages = [[self imageSources] containsObject:imageSource] &&
											  [imageSource hasMoreImages];
	
	[pool release];
	
	while (!pausing && sourceHasMoreImages)
	{
		NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
		NSImage				*image = nil;
		NSString			*imageIdentifier = nil;
		BOOL				imageIsValid = NO;
		
		NS_DURING
				// Get the next image from the source (and identifier if there is one)
			image = [imageSource nextImageAndIdentifier:&imageIdentifier];
			
				// Set the caching behavior of the image.  We'll be adding bitmap representations of various
				// sizes to the image so it doesn't need to do any of its own caching.
			[image setCachedSeparately:YES];
			[image setCacheMode:NSImageCacheNever];
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
				[imageQueueLock lock];	// this will be locked if the queue is full
					while (!pausing && [imageQueue count] > MAXIMAGEURLS && [[self imageSources] containsObject:imageSource])
					{
						[imageQueueLock unlock];
						if (!calculateImageMatchesThreadAlive)
							[NSApplication detachDrawingThread:@selector(calculateImageMatches) toTarget:self withObject:nil];
						[imageQueueLock lock];
						
						[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
					}
					
					// TODO: are we losing an image if paused?
					
					[imageQueue addObject:[NSDictionary dictionaryWithObjectsAndKeys:
												image, @"Image",
												imageSource, @"Image Source", 
												imageIdentifier, @"Image Identifier", // last since it could be nil
												nil]];
					
					[enumerationCountsLock lock];
						unsigned long	currentCount = [[enumerationCounts objectForKey:[NSValue valueWithPointer:imageSource]] unsignedLongValue];
						[enumerationCounts setObject:[NSNumber numberWithUnsignedLong:currentCount + 1] 
											  forKey:[NSValue valueWithPointer:imageSource]];
					[enumerationCountsLock unlock];
				[imageQueueLock unlock];

				if (!pausing && !calculateImageMatchesThreadAlive)
					[NSApplication detachDrawingThread:@selector(calculateImageMatches) toTarget:self withObject:nil];
				
				[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification 
																	object:self];
			}
		}
		sourceHasMoreImages = [[self imageSources] containsObject:imageSource] && [imageSource hasMoreImages];
		
		[pool release];
	}
	
	[enumerationThreadCountLock lock];
		enumerationThreadCount--;
	[enumerationThreadCountLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
														object:self];
}


- (void)setImageCount:(unsigned long)imageCount forImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[enumerationCountsLock lock];
		if (imageCount > 0)
			[enumerationCounts setObject:[NSNumber numberWithUnsignedLong:imageCount]
								  forKey:[NSValue valueWithPointer:imageSource]];
		else
			[enumerationCounts removeObjectForKey:[NSValue valueWithPointer:imageSource]];
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
		NSEnumerator	*sourceEnumerator = [enumerationCounts keyEnumerator];
		NSString		*key = nil;
		while (key = [sourceEnumerator nextObject])
			totalCount += [[enumerationCounts objectForKey:key] unsignedLongValue];
	[enumerationCountsLock unlock];
	
	return totalCount;
}


#pragma mark -
#pragma mark Image matching


- (void)calculateImageMatches
{
		// This method is called in a new thread whenever a non-empty image queue is discovered.
		// It pulls images from the queue and matches them against each tile.  Once the queue
		// is empty the method will end and the thread is terminated.
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];

        // Make sure only one copy of this thread runs at any time.
	[calculateImageMatchesThreadLock lock];
		if (calculateImageMatchesThreadAlive)
		{
                // Another copy is running, just exit.
			[calculateImageMatchesThreadLock unlock];
			[pool release];
			return;
		}
		calculateImageMatchesThreadAlive = YES;
	[calculateImageMatchesThreadLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
														object:self];
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
	MacOSaiXImageCache	*imageCache = [MacOSaiXImageCache sharedImageCache];
	BOOL				revisit = NO;
	int					revisitStep = 0;
	
	[imageQueueLock lock];
	while (!pausing && ([imageQueue count] > 0 || [revisitQueue count] > 0))
	{
		while (!pausing && ([imageQueue count] > 0 || [revisitQueue count] > 0))
		{
				// As long as the image source threads are feeding images into the queue this loop
				// will continue running so create a pool just for this pass through the loop.
			NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
			BOOL				queueLocked = NO;
			
				// Pull the next image from one of the queues.
				// Look at newly found images before revisiting previously found ones.
			NSDictionary		*nextImageDict = nil;
			int					newCount = [imageQueue count], 
								revisitCount = [revisitQueue count];
			if (newCount == 0)
				revisit = YES;
			else if (revisitCount == 0)
				revisit = NO;
			else
				revisit = (revisitStep++ % 16 > 0);
			
//			NSLog(@"%d images queued to revisit", revisitCount);
			if (!revisit)	//newCount > 0 && revisitCount < MAXIMAGEURLS * 8)
			{
				nextImageDict = [[[imageQueue objectAtIndex:0] retain] autorelease];
				[imageQueue removeObjectAtIndex:0];
			}
			else
			{
				nextImageDict = [[[revisitQueue lastObject] retain] autorelease];
				[revisitQueue removeLastObject];
//				NSLog(@"                     revisiting %@", [nextImageDict objectForKey:@"Image Identifier"]);
			}
			
				// let the image source threads add more images if the queue is not full
			if (newCount < MAXIMAGEURLS)
				[imageQueueLock unlock];
			else
				queueLocked = YES;
			
			NSImage					*pixletImage = [nextImageDict objectForKey:@"Image"];
			id<MacOSaiXImageSource>	pixletImageSource = [nextImageDict objectForKey:@"Image Source"];
			NSString				*pixletImageIdentifier = [nextImageDict objectForKey:@"Image Identifier"];
			BOOL					pixletImageInUse = NO;
			
			if (pixletImage)
			{
					// Add this image to the in-memory cache.  If the image source does not support refetching 
					// images then the image will be also be saved into this mosaic's document.
				[imageCache cacheImage:pixletImage withIdentifier:pixletImageIdentifier fromSource:pixletImageSource];
			}
			
				// Find the tiles that match this image better than their current image.
			NSString		*pixletKey = [NSString stringWithFormat:@"%p %@", pixletImageSource, pixletImageIdentifier];
			NSMutableArray	*betterMatches = [betterMatchesCache objectForKey:pixletKey];
			if (betterMatches)
			{
					// The cache contains the list of tiles which could be improved by using this image.
					// Remove any tiles from the list that have gotten a better match since the list was cached.
					// Also remove any tiles that have the exact same match value but for a different image.  This 
					// avoids infinite loop conditions if you have multiple image that have the exact same match 
					// value (typically when there are multiple files containing the exact same image).
				NSEnumerator		*betterMatchEnumerator = [betterMatches objectEnumerator];
				MacOSaiXImageMatch	*betterMatch = nil;
				unsigned			currentIndex = 0,
									indicesToRemove[[betterMatches count]],
									countOfIndicesToRemove = 0;
				while ((betterMatch = [betterMatchEnumerator nextObject]) && !pausing)
				{
					MacOSaiXImageMatch	*currentMatch = [[betterMatch tile] uniqueImageMatch];
					if (currentMatch && ([currentMatch matchValue] < [betterMatch matchValue] || 
										 ([currentMatch matchValue] == [betterMatch matchValue] && 
											([currentMatch imageSource] != [betterMatch imageSource] || 
											 [currentMatch imageIdentifier] != [betterMatch imageIdentifier]))))
						indicesToRemove[countOfIndicesToRemove++] = currentIndex;
					currentIndex++;
				}
				[betterMatches removeObjectsFromIndices:indicesToRemove numIndices:countOfIndicesToRemove];
				
					// If only the dummy entry is left then we need to rematch.
				if ([betterMatches count] == 1 && ![(MacOSaiXImageMatch *)[betterMatches objectAtIndex:0] tile])
				{
	//				NSLog(@"Didn't cache enough matches...");
					betterMatches = nil;
				}
			}
			
			if (!betterMatches)
			{
					// The better matches for this pixlet are not in the cache so we must calculate them.
				betterMatches = [NSMutableArray array];
				
					// Get the size of the pixlet image.
				NSSize					pixletSize;
				if (pixletImage)
					pixletSize = [pixletImage size];
				else
				{
						// Get the size from the cache.
					pixletSize = [imageCache nativeSizeOfImageWithIdentifier:pixletImageIdentifier fromSource:pixletImageSource];
					
					if (NSEqualSizes(pixletSize, NSZeroSize))
					{
							// The image isn't in the cache.  Force it to load and then get its size.
						pixletSize = [[imageCache imageRepAtSize:NSZeroSize 
												   forIdentifier:pixletImageIdentifier 
													  fromSource:pixletImageSource] size];
					}
				}

					// Loop through all of the tiles and calculate how well this image matches.
				MacOSaiXImageMatcher	*matcher = [MacOSaiXImageMatcher sharedMatcher];
				NSEnumerator			*tileEnumerator = [tiles objectEnumerator];
				MacOSaiXTile			*tile = nil;
				while ((tile = [tileEnumerator nextObject]) && !pausing)
				{
					NSAutoreleasePool	*pool3 = [[NSAutoreleasePool alloc] init];
					NSBitmapImageRep	*tileBitmap = [tile bitmapRep];
					NSSize				tileSize = [tileBitmap size];
					float				croppedPercentage;
					
						// See if the image will be cropped too much.
					if ((pixletSize.width / tileSize.width) < (pixletSize.height / tileSize.height))
						croppedPercentage = (pixletSize.width * (pixletSize.height - pixletSize.width * tileSize.height / tileSize.width)) / 
											 (pixletSize.width * pixletSize.height) * 100.0;
					else
						croppedPercentage = ((pixletSize.width - pixletSize.height * tileSize.width / tileSize.height) * pixletSize.height) / 
											 (pixletSize.width * pixletSize.height) * 100.0;
					
					if (croppedPercentage <= [self imageCropLimit])
					{
							// Get a rep for the image scaled to the tile's bitmap size.
						NSBitmapImageRep	*imageRep = [imageCache imageRepAtSize:tileSize 
																	 forIdentifier:pixletImageIdentifier 
																	    fromSource:pixletImageSource];
				
						if (imageRep)
						{
								// Calculate how well this image matches this tile.
							float	previousBest = ([tile uniqueImageMatch] ? [[tile uniqueImageMatch] matchValue] : 1.0), 
									matchValue = [matcher compareImageRep:tileBitmap 
																 withMask:[tile maskRep] 
															   toImageRep:imageRep
															 previousBest:previousBest];
							
							MacOSaiXImageMatch	*newMatch = [MacOSaiXImageMatch imageMatchWithValue:matchValue 
																				 forImageIdentifier:pixletImageIdentifier 
																					fromImageSource:pixletImageSource
																							forTile:tile];
								// If this image matches better than the tile's current best or
								//    this image is the same as the tile's current best
								// then add it to the list of tile's that might get this image.
							if (matchValue < previousBest ||
								([[tile uniqueImageMatch] imageSource] == pixletImageSource && 
								 [[[tile uniqueImageMatch] imageIdentifier] isEqualToString:pixletImageIdentifier]))
							{
								[betterMatches addObject:newMatch];
							}
							
								// Set the tile's best match if appropriate.
								// TBD: check pref?
							if (![tile bestImageMatch] || matchValue < [[tile bestImageMatch] matchValue])
								[tile setBestImageMatch:newMatch];
						}
						else
							;	// anything to do or just lose the chance to match this pixlet to this tile?
					}
					
					[pool3 release];
				}
				
					// Sort the array with the best matches first.
				[betterMatches sortUsingSelector:@selector(compare:)];
			}
			
			if ([betterMatches count] == 0)
			{
//				NSLog(@"%@ from %@ is no longer needed", pixletImageIdentifier, pixletImageSource);
				[betterMatchesCache removeObjectForKey:pixletKey];
			}
			else
			{
				// Figure out which tiles should be set to use the image based on the user's settings.
				
					// A use count of zero means no limit on the number of times this image can be used.
				int					useCount = [self imageUseCount];
				if (useCount == 0)
					useCount = [betterMatches count];
				
					// Loop through the list of better matches and pick the first items (up to the use count) 
					// that aren't too close together.
				float				minDistanceApart = powf([self imageReuseDistance] * 0.95 / 100.0, 2.0);
				NSMutableArray		*matchesToUpdate = [NSMutableArray array];
				NSEnumerator		*betterMatchEnumerator = [betterMatches objectEnumerator];
				MacOSaiXImageMatch	*betterMatch = nil;
				while ((betterMatch = [betterMatchEnumerator nextObject]) && [matchesToUpdate count] < useCount)
				{
					MacOSaiXTile		*betterMatchTile = [betterMatch tile];
					NSEnumerator		*matchesToUpdateEnumerator = [matchesToUpdate objectEnumerator];
					MacOSaiXImageMatch	*matchToUpdate = nil;
					float				closestDistance = INFINITY;
					while (matchToUpdate = [matchesToUpdateEnumerator nextObject])
					{
						float	widthDiff = NSMidX([[betterMatchTile outline] bounds]) - 
											NSMidX([[[matchToUpdate tile] outline] bounds]), 
								heightDiff = (NSMidY([[betterMatchTile outline] bounds]) - 
											  NSMidY([[[matchToUpdate tile] outline] bounds])) / originalImageAspectRatio, 
								distanceSquared = widthDiff * widthDiff + heightDiff * heightDiff;
						
						closestDistance = MIN(closestDistance, distanceSquared);
					}
					
					if ([matchesToUpdate count] == 0 || closestDistance >= minDistanceApart)
						[matchesToUpdate addObject:betterMatch];
				}
				
				if ([matchesToUpdate count] == useCount || [(MacOSaiXImageMatch *)[betterMatches lastObject] tile])
				{
						// There were enough matches in betterMatches.  Update the winning tiles.
					NSEnumerator		*matchesToUpdateEnumerator = [matchesToUpdate objectEnumerator];
					MacOSaiXImageMatch	*matchToUpdate = nil;
					while (matchToUpdate = [matchesToUpdateEnumerator nextObject])
					{
							// Add the tile's current image back to the queue so it can potentially get re-used by other tiles.
						MacOSaiXImageMatch	*previousMatch = [[matchToUpdate tile] uniqueImageMatch];
						if (previousMatch && ([previousMatch imageSource] != pixletImageSource || 
							![[previousMatch imageIdentifier] isEqualToString:pixletImageIdentifier]))
						{
							if (!queueLocked)
							{
								[imageQueueLock lock];
								queueLocked = YES;
							}
							
							NSDictionary	*newQueueEntry = [NSDictionary dictionaryWithObjectsAndKeys:
																[previousMatch imageSource], @"Image Source", 
																[previousMatch imageIdentifier], @"Image Identifier",
																nil];
							[revisitQueue removeObject:newQueueEntry];
							[revisitQueue addObject:newQueueEntry];
						}
						
						[[matchToUpdate tile] setUniqueImageMatch:matchToUpdate];
					}
					
						// Only remember a reasonable number of the best matches.
						// TODO: cache this since it never changes
					int	roughUpperBound = 4 + ([tiles count] / 2.0 * (100.0 - [self imageReuseDistance]) / 100.0);
					if ([betterMatches count] > roughUpperBound)
					{
						[betterMatches removeObjectsInRange:NSMakeRange(roughUpperBound, [betterMatches count] - roughUpperBound)];
						
							// Add a dummy entry with a nil tile on the end so we know that entries were removed.
						[betterMatches addObject:[[[MacOSaiXImageMatch alloc] init] autorelease]];
					}
						
						// Remember this list so we don't have to do all of the matches again.
					[betterMatchesCache setObject:betterMatches forKey:pixletKey];
					
					pixletImageInUse = YES;
				}
				else
				{
						// There weren't enough matches in the cache to satisfy the user's prefs 
						// so we need to re-calculate the matches.
					[betterMatchesCache removeObjectForKey:pixletKey];
					betterMatches = nil;	// The betterMatchesCache had the last retain on the array.
					
					NSDictionary	*newQueueEntry = [NSDictionary dictionaryWithObjectsAndKeys:
														pixletImageSource, @"Image Source", 
														pixletImageIdentifier, @"Image Identifier",
														nil];
					[revisitQueue removeObject:newQueueEntry];
					[revisitQueue addObject:newQueueEntry];
					
					pixletImageInUse = YES;
				}
			}
			
			if (!pixletImageInUse && ![pixletImageSource canRefetchImages])
			{
					// Check if the image is the best match for any tile.
				NSEnumerator			*tileEnumerator = [tiles objectEnumerator];
				MacOSaiXTile			*tile = nil;
				while (!pixletImageInUse && (tile = [tileEnumerator nextObject]))
					if ([[tile bestImageMatch] imageSource] == pixletImageSource && 
						[[[tile bestImageMatch] imageIdentifier] isEqualToString:pixletImageIdentifier])
					{
						pixletImageInUse = YES;
						break;
					}
			}
				
			if (!pixletImageInUse && ![pixletImageSource canRefetchImages])
				[imageCache removeCachedImagesWithIdentifiers:[NSArray arrayWithObject:pixletImageIdentifier] 
												   fromSource:pixletImageSource];
			
			if (!queueLocked)
				[imageQueueLock lock];

			[pool2 release];
		}
		
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	}
	
	// TODO: put the image back on the queue if we were paused.
		
	[imageQueueLock unlock];
	
	[calculateImageMatchesThreadLock lock];
		calculateImageMatchesThreadAlive = NO;
	[calculateImageMatchesThreadLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
														object:self];

		// clean up and shutdown this thread
    [pool release];
}


#pragma mark -
#pragma mark Status


- (BOOL)isBusy
{
	return (enumerationThreadCount > 0 || calculateImageMatchesThreadAlive);
}


- (NSString *)busyStatus
{
	NSString	*status = nil;
	
	if ([tilesWithoutBitmaps count] > 0)
		status = NSLocalizedString(@"Extracting tiles from original...", @"");	// TODO: include the % complete (localized)
	else if (calculateImageMatchesThreadAlive)
		status = NSLocalizedString(@"Matching images...", @"");
	else if (enumerationThreadCount > 0)
		status = NSLocalizedString(@"Looking for new images...", @"");
	
	return status;
}


- (void)setWasStarted:(BOOL)wasStarted
{
	if (wasStarted != mosaicStarted)
	{
		mosaicStarted = wasStarted;
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification
															object:self];
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
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		
		paused = YES;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
															object:self];
	}
}


- (void)resume
{
	if (paused)
	{
		mosaicStarted = YES;
		
		pausing = NO;
		
			// Start or restart the image sources
		[self spawnImageSourceThreads];
		
		paused = NO;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
															object:self];
	}
}


#pragma mark -


- (void)dealloc
{
		// Purge all of this mosaic's images from the cache.
	NSEnumerator			*imageSourceEnumerator = [imageSources objectEnumerator];
	id<MacOSaiXImageSource>	imageSource = nil;
	while (imageSource = [imageSourceEnumerator nextObject])
		[[MacOSaiXImageCache sharedImageCache] removeCachedImagesFromSource:imageSource];

	[imageSources release];
	[imageSourcesLock release];
	[diskCacheSubPaths release];
	
    [originalImage release];
	[enumerationThreadCountLock release];
	[enumerationCountsLock release];
	[enumerationCounts release];
	[betterMatchesCache release];
	[calculateImageMatchesThreadLock release];
    [tiles release];
	[tilesWithoutBitmaps release];
    [tileShapes release];
    [imageQueue release];
    [imageQueueLock release];
	[revisitQueue release];
	
    [super dealloc];
}


@end

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
NSString	*MacOSaiXOriginalImageDidChangeNotification = @"MacOSaiXOriginalImageDidChangeNotification";
NSString	*MacOSaiXTileImageDidChangeNotification = @"MacOSaiXTileImageDidChangeNotification";
NSString	*MacOSaiXTileShapesDidChangeStateNotification = @"MacOSaiXTileShapesDidChangeStateNotification";


@interface MacOSaiXMosaic (PrivateMethods)
- (void)addTile:(MacOSaiXTile *)tile;
- (void)lockWhilePaused;
@end


@implementation MacOSaiXMosaic


- (id)init
{
    if (self = [super init])
    {
		NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
		
		paused = YES;
		
		imageSources = [[NSMutableArray arrayWithCapacity:0] retain];

		pauseLock = [[NSLock alloc] init];
		[pauseLock lock];
			
		// create the image URL queue and its lock
		imageQueue = [[NSMutableArray arrayWithCapacity:0] retain];
		imageQueueLock = [[NSLock alloc] init];

		calculateImageMatchesThreadLock = [[NSLock alloc] init];
		betterMatchesCache = [[NSMutableDictionary dictionary] retain];
		
		enumerationThreadCountLock = [[NSLock alloc] init];
		enumerationCountsLock = [[NSLock alloc] init];
		enumerationCounts = [[NSMutableDictionary dictionary] retain];
		
		[self setImageUseCount:[[defaults objectForKey:@"Image Use Count"] intValue]];
		[self setImageReuseDistance:[[defaults objectForKey:@"Image Reuse Distance"] intValue]];
		[self setImageCropLimit:[[defaults objectForKey:@"Image Crop Limit"] intValue]];
	}
	
    return self;
}


#pragma mark -
#pragma mark Original image management


- (void)setOriginalImagePath:(NSString *)path
{
	if (![path isEqualToString:originalImagePath])
	{
		[originalImagePath release];
		[originalImage release];
		
		originalImagePath = [[NSString stringWithString:path] retain];
		originalImage = [[NSImage alloc] initWithContentsOfFile:path];
		[originalImage setCachedSeparately:YES];
		originalImageAspectRatio = [originalImage size].width / [originalImage size].height;

			// Ignore whatever DPI was set for the image.  We just care about the bitmap.
		NSImageRep	*originalRep = [[originalImage representations] objectAtIndex:0];
		[originalRep setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
		[originalImage setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXOriginalImageDidChangeNotification object:self];
	}
}


- (NSString *)originalImagePath
{
	return originalImagePath;
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
}


- (void)setTileShapes:(id<MacOSaiXTileShapes>)inTileShapes creatingTiles:(BOOL)createTiles
{
	[inTileShapes retain];
	[tileShapes autorelease];
	tileShapes = inTileShapes;
	
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
			[self addTile:[[[MacOSaiXTile alloc] initWithOutline:tileOutline fromDocument:self] autorelease]];
		
			// Indicate that the average tile size needs to be recalculated.
		averageUnitTileSize = NSZeroSize;
	}
	
		// Let anyone who cares know that our tile shapes (and thus our tiles array) have changed.
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileShapesDidChangeStateNotification 
														object:self 
													  userInfo:nil];
		
	if ([imageSources count] > 0 && [tiles count] > 0 && 
		[[NSUserDefaults standardUserDefaults] boolForKey:@"Automatically Start Mosaics"])
		[self resume];
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
	}
}


- (int)imageReuseDistance
{
	return imageReuseDistance;
}


- (void)setImageReuseDistance:(int)distance
{
	imageReuseDistance = distance;
	[[NSUserDefaults standardUserDefaults] setInteger:imageReuseDistance forKey:@"Image Reuse Distance"];
}


- (int)imageCropLimit
{
	return imageCropLimit;
}


- (void)setImageCropLimit:(int)cropLimit
{
	imageCropLimit = cropLimit;
	[[NSUserDefaults standardUserDefaults] setInteger:imageCropLimit forKey:@"Image Crop Limit"];
}


- (NSArray *)tiles
{
	return tiles;
}


#pragma mark -
#pragma mark Images source management


- (NSArray *)imageSources
{
	return [NSArray arrayWithArray:imageSources];
}


- (void)addImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[imageSources addObject:imageSource];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
	
	[NSApplication detachDrawingThread:@selector(enumerateImageSourceInNewThread:) 
							  toTarget:self 
							withObject:imageSource];

		// Auto start the mosaic if possible and the user wants to.
	if ([self tileShapes] && [tiles count] > 0 && [[NSUserDefaults standardUserDefaults] boolForKey:@"Automatically Start Mosaics"])
		[self resume];
}


- (void)removeImageSource:(id<MacOSaiXImageSource>)imageSource
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
		if ([imageSource isKindOfClass:[MacOSaiXHandPickedImageSource class]])
			[tile setUserChosenImageMatch:nil];
		else
		{
			if ([[tile uniqueImageMatch] imageSource] == imageSource)
				[tile setUniqueImageMatch:nil];
		}
	}
	
	[imageSources removeObject:imageSource];
	[[MacOSaiXImageCache sharedImageCache] removeCachedImageRepsFromSource:imageSource];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
}


- (MacOSaiXHandPickedImageSource *)handPickedImageSource
{
	NSEnumerator			*imageSourceEnumerator = [imageSources objectEnumerator];
	id<MacOSaiXImageSource>	imageSource = nil;
	while (imageSource = [imageSourceEnumerator nextObject])
		if ([imageSource isKindOfClass:[MacOSaiXHandPickedImageSource class]])
			break;
	
	if (!imageSource)
	{
		imageSource = [[[MacOSaiXHandPickedImageSource alloc] init] autorelease];
		[imageSources addObject:imageSource];
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


#pragma mark -
#pragma mark Image source enumeration


- (void)spawnImageSourceThreads
{
	NSEnumerator			*imageSourceEnumerator = [imageSources objectEnumerator];
	id<MacOSaiXImageSource>	imageSource;
	
	while (imageSource = [imageSourceEnumerator nextObject])
		[NSApplication detachDrawingThread:@selector(enumerateImageSourceInNewThread:) toTarget:self withObject:imageSource];
}


- (void)enumerateImageSourceInNewThread:(id<MacOSaiXImageSource>)imageSource
{
	[enumerationThreadCountLock lock];
		enumerationThreadCount++;
	[enumerationThreadCountLock unlock];
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
		// Check if the source has any images left.
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	BOOL				sourceHasMoreImages = [imageSource hasMoreImages];
	[pool release];
	
	while (!stopped && sourceHasMoreImages)
	{
		NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
		NSImage				*image = nil;
		NSString			*imageIdentifier = nil;
		BOOL				imageIsValid = NO;
		
		[self lockWhilePaused];
		
		NS_DURING
				// Get the next image from the source (and identifier if there is one)
			image = [imageSource nextImageAndIdentifier:&imageIdentifier];
			
				// Set the caching behavior of the image.  We'll be adding bitmap representations of various
				// sizes to the image so it doesn't need to do any of its own caching.
			[image setCachedSeparately:YES];
			[image setCacheMode:NSImageCacheNever];
			imageIsValid = [image isValid];
		NS_HANDLER
			NSLog(@"Exception raised while checking image validity (%@)", localException);
		NS_ENDHANDLER
			
		if (image && imageIsValid)
		{
				// Ignore whatever DPI was set for the image.  We just care about the bitmap.
			NSImageRep	*originalRep = [[image representations] objectAtIndex:0];
			[originalRep setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
			[image setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
			
			if ([image size].width > 16 && [image size].height > 16)
			{
				[imageQueueLock lock];	// this will be locked if the queue is full
					while (!stopped && [imageQueue count] > MAXIMAGEURLS)
					{
						[imageQueueLock unlock];
						if (!calculateImageMatchesThreadAlive)
							[NSApplication detachDrawingThread:@selector(calculateImageMatches:) toTarget:self withObject:nil];
						[imageQueueLock lock];
					}
					
					// TODO: are we losing an image if stopped?
					
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

				if (!stopped && !calculateImageMatchesThreadAlive)
					[NSApplication detachDrawingThread:@selector(calculateImageMatches:) toTarget:self withObject:nil];
				
				[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
			}
		}
		sourceHasMoreImages = [imageSource hasMoreImages];
		
		[pool release];
	}
	
	[enumerationThreadCountLock lock];
		enumerationThreadCount--;
	[enumerationThreadCountLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
}


- (BOOL)isEnumeratingImageSources
{
	return (enumerationThreadCount > 0);
}


- (void)setImageCount:(unsigned long)imageCount forImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[enumerationCountsLock lock];
		[enumerationCounts setObject:[NSNumber numberWithUnsignedLong:imageCount]
							  forKey:[NSValue valueWithPointer:imageSource]];
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


- (unsigned long)imagesMatched
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


- (void)calculateImageMatches:(id)dummy
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
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
	MacOSaiXImageCache	*imageCache = [MacOSaiXImageCache sharedImageCache];
	
	[imageQueueLock lock];
	while (!stopped && [imageQueue count] > 0)
	{
		while (!stopped && [imageQueue count] > 0)
		{
				// As long as the image source threads are feeding images into the queue this loop
				// will continue running so create a pool just for this pass through the loop.
			NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
			BOOL				queueLocked = NO;
			
				// pull the next image from the queue
			NSDictionary		*nextImageDict = [[[imageQueue objectAtIndex:0] retain] autorelease];
			[imageQueue removeObjectAtIndex:0];
			
				// let the image source threads add more images if the queue is not full
			if ([imageQueue count] < MAXIMAGEURLS)
				[imageQueueLock unlock];
			else
				queueLocked = YES;
			
			NSImage					*pixletImage = [nextImageDict objectForKey:@"Image"];
			id<MacOSaiXImageSource>	pixletImageSource = [nextImageDict objectForKey:@"Image Source"];
			NSString				*pixletImageIdentifier = [nextImageDict objectForKey:@"Image Identifier"];
			
			if (pixletImage)
			{
					// Add this image to the cache.  If the identifier is nil or zero-length then 
					// a new identifier will be returned.
				pixletImageIdentifier = [imageCache cacheImage:pixletImage withIdentifier:pixletImageIdentifier fromSource:pixletImageSource];
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
				while ((betterMatch = [betterMatchEnumerator nextObject]) && !stopped)
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
				while ((tile = [tileEnumerator nextObject]) && !stopped)
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
							
								// If the tile does not already have a match or 
								//    this image matches better than the tile's current best or
								//    this image is the same as the tile's current best
								// then add it to the list of tile's that might get this image.
							if (![tile uniqueImageMatch] || 
								matchValue < [[tile uniqueImageMatch] matchValue] ||
								([[tile uniqueImageMatch] imageSource] == pixletImageSource && 
								 [[[tile uniqueImageMatch] imageIdentifier] isEqualToString:pixletImageIdentifier]))
								[betterMatches addObject:[[[MacOSaiXImageMatch alloc] initWithMatchValue:matchValue 
																					  forImageIdentifier:pixletImageIdentifier 
																						 fromImageSource:pixletImageSource
																								 forTile:tile] autorelease]];
						}
						else
							;	// anything to do or just lose the chance to match this pixlet to this tile?
					}
					
					[pool3 release];
				}
				
					// Sort the array with the best matches first.
				[betterMatches sortUsingSelector:@selector(compare:)];
			}
			
			if (betterMatches && [betterMatches count] == 0)
			{
	//			NSLog(@"%@ from %@ is no longer needed", pixletImageIdentifier, pixletImageSource);
				[betterMatchesCache removeObjectForKey:pixletKey];
				
				// TBD: Is this the right place to purge images from the disk cache?
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
				float				minDistanceApart = [self imageReuseDistance] * [self imageReuseDistance] *
													   ([self averageUnitTileSize].width * [self averageUnitTileSize].width +
														[self averageUnitTileSize].height * [self averageUnitTileSize].height / 
														originalImageAspectRatio / originalImageAspectRatio);
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
							![[previousMatch imageIdentifier] isEqualToString:pixletImageIdentifier]) &&
							[self imageUseCount] > 0)
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
							if (![imageQueue containsObject:newQueueEntry])
							{
		//						NSLog(@"Rechecking %@", [previousMatch imageIdentifier]);
								[imageQueue addObject:newQueueEntry];
							}
						}
						
						[[matchToUpdate tile] setUniqueImageMatch:matchToUpdate];
					}
					
						// Only remember a reasonable number of the best matches.
						// TODO: cache this since it never changes
					int	roughUpperBound = pow(sqrt([tiles count]) / imageReuseDistance, 2);
					if ([betterMatches count] > roughUpperBound)
					{
						[betterMatches removeObjectsInRange:NSMakeRange(roughUpperBound, [betterMatches count] - roughUpperBound)];
						
							// Add a dummy entry with a nil tile on the end so we know that entries were removed.
						[betterMatches addObject:[[[MacOSaiXImageMatch alloc] init] autorelease]];
					}
						
						// Remember this list so we don't have to do all of the matches again.
					[betterMatchesCache setObject:betterMatches forKey:pixletKey];
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
					if (![imageQueue containsObject:newQueueEntry])
						[imageQueue addObject:newQueueEntry];
				}
			}
			
			if (pixletImage)
				imagesMatched++;
			
			if (!queueLocked)
				[imageQueueLock lock];

			[pool2 release];
		}
		
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	}
	[imageQueueLock unlock];
	
	[calculateImageMatchesThreadLock lock];
		calculateImageMatchesThreadAlive = NO;
	[calculateImageMatchesThreadLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];

		// clean up and shutdown this thread
    [pool release];
}

- (BOOL)isCalculatingImageMatches
{
	return calculateImageMatchesThreadAlive;
}


#pragma mark -
#pragma mark Pausing/resuming


- (BOOL)wasStarted
{
	return mosaicStarted;
}


- (BOOL)isPaused
{
	return paused;
}


- (void)pause
{
	if (!paused)
	{
			// Wait for the one-shot startup thread to end.
//		while ([self isExtractingTileImagesFromOriginal])
//			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

			// Tell the enumeration threads to stop sending in any new images.
		[pauseLock lock];
		
			// Wait for any queued images to get processed.
			// TBD: can we condition lock here instead of poll?
			// TBD: this could block the main thread
		while ([self isCalculatingImageMatches])
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		
		paused = YES;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
	}
}


- (void)lockWhilePaused
{
	[pauseLock lock];
	[pauseLock unlock];
}


- (void)resume
{
	if (paused)
	{
//		if (![self wasStarted])
//		{
//				// Automatically start the mosaic.
//				// Show the mosaic image and start extracting the tile images.
//			[[self mainWindowController] setViewMosaic:self];
//			[NSApplication detachDrawingThread:@selector(extractTileImagesFromOriginalImage)
//									  toTarget:self
//									withObject:nil];
//		}
//		else
		{
			mosaicStarted = YES;
			
				// Start or restart the image sources
			[pauseLock unlock];
			
			paused = NO;
			
			[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeStateNotification object:self];
		}
	}
}


#pragma mark -

- (void)dealloc
{
	NSEnumerator			*imageSourceEnumerator = [imageSources objectEnumerator];
	id<MacOSaiXImageSource>	imageSource = nil;
	while (imageSource = [imageSourceEnumerator nextObject])
		[[MacOSaiXImageCache sharedImageCache] removeCachedImageRepsFromSource:imageSource];
	[imageSources release];
	
    [originalImagePath release];
    [originalImage release];
	[pauseLock release];
    [imageQueueLock release];
	[enumerationThreadCountLock release];
	[enumerationCountsLock release];
	[enumerationCounts release];
	[betterMatchesCache release];
	[calculateImageMatchesThreadLock release];
    [tiles release];
    [tileShapes release];
    [imageQueue release];
	
    [super dealloc];
}


@end

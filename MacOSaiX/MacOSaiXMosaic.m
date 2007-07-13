//
//  MacOSaiXMosaic.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/4/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXMosaic.h"

#import "MacOSaiX.h"
#import "MacOSaiXDisallowedImage.h"
#import "MacOSaiXExporter.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageMatcher.h"
#import "MacOSaiXImageOrientations.h"
#import "MacOSaiXImageQueue.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXImageSourceEnumerator.h"
#import "MacOSaiXHandPickedImageSource.h"
#import "MacOSaiXSourceImage.h"
#import "MacOSaiXTileShapes.h"
#import "Tiles.h"


	// Notifications
NSString	*MacOSaiXMosaicDidChangeImageSourcesNotification = @"MacOSaiXMosaicDidChangeImageSourcesNotification";
NSString	*MacOSaiXMosaicDidChangeBusyStateNotification = @"MacOSaiXMosaicDidChangeBusyStateNotification";
NSString	*MacOSaiXTargetImageWillChangeNotification = @"MacOSaiXTargetImageWillChangeNotification";
NSString	*MacOSaiXTargetImageDidChangeNotification = @"MacOSaiXTargetImageDidChangeNotification";
NSString	*MacOSaiXTileContentsDidChangeNotification = @"MacOSaiXTileContentsDidChangeNotification";
NSString	*MacOSaiXTileShapesDidChangeStateNotification = @"MacOSaiXTileShapesDidChangeStateNotification";
NSString	*MacOSaiXImageOrientationsDidChangeStateNotification = @"MacOSaiXImageOrientationsDidChangeStateNotification";


@interface MacOSaiXMosaic (PrivateMethods)
- (void)addTile:(MacOSaiXTile *)tile;
- (void)lockWhilePaused;
- (void)setNumberOfImagesFound:(unsigned long)imageCount forImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)enumerateImageSource:(id<MacOSaiXImageSource>)imageSource;
@end


@implementation MacOSaiXMosaic


- (id)init
{
    if (self = [super init])
    {
		paused = YES;
		
		targetImageAspectRatio = 1.0;	// avoid any divide-by-zero errors
		
		imageSourceEnumerators = [[NSMutableArray alloc] init];
		imageSourcesLock = [[NSLock alloc] init];
		tilesWithoutBitmapsLock = [[NSLock alloc] init];
		tilesWithoutBitmaps = [[NSMutableArray alloc] init];
		diskCacheSubPaths = [[NSMutableDictionary alloc] init];
		
			// This queue is populated by the enumeration threads and accessed by the matching thread.
		newImageQueue = [[MacOSaiXImageQueue alloc] init];
		[newImageQueue setMaximumCount:8];
		revisitImageQueue = [[MacOSaiXImageQueue alloc] init];
		
		calculateImageMatchesLock = [[NSLock alloc] init];
		betterMatchesCache = [[NSMutableDictionary alloc] init];
		imageIdentifiersInUse = [[NSMutableDictionary alloc] init];
		
		NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
		[self setImageUseCount:[[defaults objectForKey:@"Image Use Count"] intValue]];
		[self setImageReuseDistance:[[defaults objectForKey:@"Image Reuse Distance"] intValue]];
		[self setImageCropLimit:[[defaults objectForKey:@"Image Crop Limit"] intValue]];
		
		disallowedImages = [[NSMutableArray array] retain];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disallowedImagesDidChange:) name:MacOSaiXDisallowedImagesDidChangeNotification object:nil];
		
		paused = NO;
	}
	
    return self;
}


- (void)resetIncludingTiles:(BOOL)resetTiles
{
	BOOL					wasRunning = ![self isPaused];
	
	// Stop any worker threads.
	if (wasRunning)
		[self pause];
	
		// Reset all of the image sources.
	[imageSourceEnumerators makeObjectsPerformSelector:@selector(reset)];
	
		// Clear the cache of better matches
	[betterMatchesCache removeAllObjects];
	
	if (resetTiles)
	{
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
	}

	if (wasRunning)
		[self resume];
}


#pragma mark -
#pragma mark Target image management


- (void)setTargetImage:(NSImage *)image
{
	if (image != targetImage)
	{
		[self resetIncludingTiles:YES];
		
		NSDictionary	*userInfo = (targetImage ? [NSDictionary dictionaryWithObject:targetImage forKey:@"Previous Image"] : [NSDictionary dictionary]);
		
		[targetImage release];
		targetImage = [image retain];

		[targetImage setCachedSeparately:YES];
		[self setAspectRatio:[targetImage size].width / [targetImage size].height];

			// Ignore whatever DPI was set for the image.  We just care about the bitmap.
		NSImageRep		*targetRep = [[targetImage representations] objectAtIndex:0];
		[targetRep setSize:NSMakeSize([targetRep pixelsWide], [targetRep pixelsHigh])];
		[targetImage setSize:NSMakeSize([targetRep pixelsWide], [targetRep pixelsHigh])];
		
		[self setTileShapes:[self tileShapes] creatingTiles:YES];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTargetImageDidChangeNotification 
															object:self 
														  userInfo:userInfo];
	}
}


- (NSImage *)targetImage
{
	return [[targetImage retain] autorelease];
}


- (void)setTargetImagePath:(NSString *)path
{
	[targetImagePath autorelease];
	targetImagePath = [path copy];
}


- (NSString *)targetImagePath
{
	return [[targetImagePath retain] autorelease];
}


- (void)setTargetImageIdentifier:(NSString *)imageIdentifier source:(id<MacOSaiXImageSource>)imageSource
{
	[targetImageIdentifier autorelease];
	targetImageIdentifier = [imageIdentifier copy];
	[targetImageSource autorelease];
	targetImageSource = [imageSource retain];
	
	// TBD: all of the reset code in -setTargetImage: should be moved here...
}


- (NSString *)targetImageIdentifier
{
	return [[self targetImagePath] lastPathComponent];
//	return targetImageIdentifier;
}


- (id<MacOSaiXImageSource>)targetImageSource
{
	if (!targetImageSource)
	{
		targetImageSource = [[NSClassFromString(@"DirectoryImageSource") alloc] init];
	}
	[(id)targetImageSource setPath:[[self targetImagePath] stringByDeletingLastPathComponent]];
	
	return targetImageSource;
}


- (void)setAspectRatio:(float)ratio
{
	targetImageAspectRatio = ratio;
	
	if (!targetImage)
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTargetImageDidChangeNotification
															object:self];
}


- (float)aspectRatio
{
	return targetImageAspectRatio;
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
	BOOL	wasRunning = ![self isPaused];
	
	if (wasRunning)
		[self pause];
	
	[tileShapes autorelease];
	tileShapes = [inTileShapes retain];
	
	if (createTiles)
	{
		NSArray	*shapesArray = [tileShapes shapesForMosaicOfSize:[[self targetImage] size]];
		
			// Discard any tiles created from a previous set of outlines.
		if (!tiles)
			tiles = [[NSMutableArray arrayWithCapacity:[shapesArray count]] retain];
		else
			[tiles removeAllObjects];

			// Create a new tile collection from the outlines.
		NSEnumerator			*tileShapeEnumerator = [shapesArray objectEnumerator];
		id<MacOSaiXTileShape>	tileShape = nil;
		while (tileShape = [tileShapeEnumerator nextObject])
			[self addTile:[[[MacOSaiXTile alloc] initWithOutline:[tileShape outline] 
												imageOrientation:[tileShape imageOrientation]
														  mosaic:self] autorelease]];
		
			// Indicate that the average tile size needs to be recalculated.
		averageTileSize = NSZeroSize;
		
		[self resetIncludingTiles:YES];
	}
	
		// Let anyone who cares know that our tile shapes (and thus our tiles array) have changed.
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileShapesDidChangeStateNotification 
														object:self 
													  userInfo:nil];
	
	if (wasRunning)
		[self resume];
}


- (id<MacOSaiXTileShapes>)tileShapes
{
	return tileShapes;
}


- (NSSize)averageTileSize
{
	if (NSEqualSizes(averageTileSize, NSZeroSize) && [tiles count] > 0)
	{
			// Calculate the average size of the tiles.
		NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
		MacOSaiXTile	*tile = nil;
		while (tile = [tileEnumerator nextObject])
		{
			averageTileSize.width += NSWidth([[tile outline] bounds]);
			averageTileSize.height += NSHeight([[tile outline] bounds]);
		}
		averageTileSize.width /= [tiles count];
		averageTileSize.height /= [tiles count];
	}
	
	return averageTileSize;
}


- (NSArray *)tiles
{
	return tiles;
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
		
		while (!pausing && (tile = [tileEnumerator nextObject]))
			[tile bitmapRep];
	}
	else
		[tilesWithoutBitmapsLock unlock];
	
	[pool release];
	
	tileBitmapExtractionThreadAlive = NO;
}


- (void)tileDidExtractBitmap:(MacOSaiXTile *)tile
{
	[tilesWithoutBitmapsLock lock];
		[tilesWithoutBitmaps removeObjectIdenticalTo:tile];
	[tilesWithoutBitmapsLock unlock];
	
	if ([self allTilesHaveExtractedBitmaps])
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
															object:self];
}


- (BOOL)allTilesHaveExtractedBitmaps
{
	[tilesWithoutBitmapsLock lock];
	BOOL	doneExtracting = ([self tileShapes] && [tilesWithoutBitmaps count] == 0);
	[tilesWithoutBitmapsLock unlock];
	
	return doneExtracting;
}


#pragma mark -
#pragma mark Image usage


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
		
		// TBD: NO if < or > previous?
		[self resetIncludingTiles:YES];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileShapesDidChangeStateNotification 
															object:self 
														  userInfo:nil];
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
		
		// TBD: NO if < or > previous?
		[self resetIncludingTiles:YES];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileShapesDidChangeStateNotification 
															object:self 
														  userInfo:nil];
	}
}


- (float)targetImageMinimumReuseDistance
{
	float				scaledReuseDistance = [self imageReuseDistance] * 0.95 / 100.0;
	
	return (powf([targetImage size].width, 2.0) + powf([targetImage size].height, 2.0)) * powf(scaledReuseDistance, 2.0);
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
		
		// TBD: NO if < or > previous?
		[self resetIncludingTiles:YES];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileShapesDidChangeStateNotification 
															object:self 
														  userInfo:nil];
	}
}


#pragma mark -
#pragma mark Image orientations


- (void)setImageOrientations:(id<MacOSaiXImageOrientations>)inImageOrientations
{
	BOOL	wasRunning = ![self isPaused], 
			needToReset = (imageOrientations != nil);
	
	if (wasRunning)
		[self pause];
	
	[imageOrientations autorelease];
	imageOrientations = [inImageOrientations retain];
			
	if (needToReset)
		[self resetIncludingTiles:YES];
	
		// Let anyone who cares know that our image orientations have changed.
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXImageOrientationsDidChangeStateNotification 
														object:self 
													  userInfo:nil];
	
	if (wasRunning)
		[self resume];
}


- (id<MacOSaiXImageOrientations>)imageOrientations
{
	return imageOrientations;
}


#pragma mark -
#pragma mark Export settings


- (void)setExportSettings:(id<MacOSaiXExportSettings>)settings
{
	[exportSettings autorelease];
	exportSettings = [settings retain];
}


- (id<MacOSaiXExportSettings>)exportSettings;
{
	return exportSettings;
}


#pragma mark -
#pragma mark Images source management


- (NSArray *)imageSourceEnumerators
{
	NSArray	*threadSafeCopy = nil;
	
	[imageSourcesLock lock];
		threadSafeCopy = [NSArray arrayWithArray:imageSourceEnumerators];
	[imageSourcesLock unlock];
		
	return threadSafeCopy;
}


- (MacOSaiXImageSourceEnumerator *)addImageSource:(id<MacOSaiXImageSource>)imageSource
{
	MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = [[MacOSaiXImageSourceEnumerator alloc] initWithImageSource:imageSource forMosaic:self];
	
	[imageSourcesLock lock];
		[imageSourceEnumerators addObject:imageSourceEnumerator];
		
		if (![imageSource canRefetchImages])
		{
			NSString	*sourceCachePath = [[self diskCachePath] stringByAppendingPathComponent:
													[self diskCacheSubPathForImageSource:imageSource]];
			[[MacOSaiXImageCache sharedImageCache] setCacheDirectory:sourceCachePath forSource:imageSource];
		}
	[imageSourcesLock unlock];
		
		// The new source is "on probation" for a minute after it gets added.  Any images that are removed from tiles are remembered and are re-matched if this image source gets changed or removed before the probation ends.  Otherwise the images are discarded after the minute is over.  This saves having to reset all of the other sources if the source is changed or removed.
	[imageSourceEnumerator setIsOnProbation:YES];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeImageSourcesNotification object:self];
	
	if (![self isBeingLoaded])
		[imageSourceEnumerator resume];
	
	return imageSourceEnumerator;
}


- (MacOSaiXImageSourceEnumerator *)enumeratorForImageSource:(id<MacOSaiXImageSource>)imageSource
{
	NSEnumerator					*imageSourceEnumeratorEnumerator = [[self imageSourceEnumerators] objectEnumerator];
	MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = nil;
	while (imageSourceEnumerator = [imageSourceEnumeratorEnumerator nextObject])
		if ([imageSourceEnumerator imageSource] == imageSource)
			break;
	
	return imageSourceEnumerator;
}


- (BOOL)removeImagesFromSource:(id<MacOSaiXImageSource>)imageSource
{
	BOOL							tilesWereChanged = NO;
	MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = [self enumeratorForImageSource:imageSource];
	
	[newImageQueue	removeImagesFromImageSourceEnumerator:imageSourceEnumerator];
	[revisitImageQueue	removeImagesFromImageSourceEnumerator:imageSourceEnumerator];
	
		// Remove any images from this source from the tiles.
	NSEnumerator		*tileEnumerator = [tiles objectEnumerator];
	MacOSaiXTile		*tile = nil;
	while (tile = [tileEnumerator nextObject])
	{
		if ([[[tile userChosenImageMatch] sourceImage] enumerator] == imageSourceEnumerator)
		{
			[tile setUserChosenImageMatch:nil];
			tilesWereChanged = YES;
		}
		
		if ([[[tile uniqueImageMatch] sourceImage] enumerator] == imageSourceEnumerator)
		{
			[tile setUniqueImageMatch:nil];
			tilesWereChanged = YES;
		}
		
		if ([[[tile bestImageMatch] sourceImage] enumerator] == imageSourceEnumerator)
		{
			[tile setBestImageMatch:nil];
			tilesWereChanged = YES;
		}
	}
	
		// Remove any images cached to disk.
	if (![imageSource canRefetchImages])
	{
		NSString	*sourceCachePath = [[self diskCachePath] stringByAppendingPathComponent:
											[self diskCacheSubPathForImageSource:imageSource]];
		[[NSFileManager defaultManager] removeFileAtPath:sourceCachePath handler:nil];
	}
	
	return tilesWereChanged;
}


- (void)imageSource:(id<MacOSaiXImageSource>)imageSource didChangeSettings:(NSString *)changeDescription
{
	MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = [self enumeratorForImageSource:imageSource];
	
	BOOL							wasPaused = [self isPaused];
	
	if (!wasPaused)
		[self pause];
	
	if ([imageSource imagesShouldBeRemovedForLastChange])
	{
			// If any tiles were using images from this source then we have to reset all sources.  Ouch.
		if ([self removeImagesFromSource:imageSource])
			[self resetIncludingTiles:NO];
	}
	else
	{
		if ([imageSourceEnumerator isOnProbation])
		{
				// If the image source that was just edited is on probation then revisit any images removed during the probation period.
			[revisitImageQueue addImagesFromQueue:[imageSourceEnumerator probationaryImageQueue]];
			[imageSourceEnumerator setIsOnProbation:NO];
		}
	}
	
	[imageSourceEnumerator setImageSource:imageSource];	// make a new working copy
	[imageSourceEnumerator setIsOnProbation:YES];
	
	if (!wasPaused)
		[self resume];
}


- (void)removeImageSource:(id<MacOSaiXImageSource>)imageSource
{
	// TODO: No need to pause the whole mosaic.  Just signal and wait for the source's enumeration thread to exit.
	
	BOOL	wasRunning = ![self isPaused];
	if (wasRunning)
		[self pause];
	
	[imageSource retain];
	
	MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = [self enumeratorForImageSource:imageSource];
	
	[imageSourceEnumerator setIsOnProbation:NO];
	
	[enumerationsLock lock];
		[imageSourceEnumerators removeObject:imageSource];
	[enumerationsLock unlock];
	
	if ([self removeImagesFromSource:imageSource])
	{
			// At least one tile was using an image from the removed source.  All remaining sources must be reset in case any of their images can now be used.  The probation morgue is irrelevant in this case and can be discarded.
			// TBD: How will this affect sources that don't support re-fetching?  Should all of the images that were retained be added to the revisit queue?
		[self resetIncludingTiles:NO];
	}
	else
	{
		// No tiles were using images from the removed source.  However, if the source is on probation then we need to revisit any images from other sources that were removed from tiles during the probation period.
		if ([imageSourceEnumerator isOnProbation])
			[revisitImageQueue addImagesFromQueue:[imageSourceEnumerator probationaryImageQueue]];
	}
	
	[imageSourceEnumerator setIsOnProbation:NO];
	
		// Remove any cached images for this source.
	[[MacOSaiXImageCache sharedImageCache] removeCachedImagesFromSource:imageSource];
	
	if (wasRunning)
		[self resume];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeImageSourcesNotification object:self];

	
	[imageSource release];
}


// TBD: how to handle considering upcoming "pick image" API?
//- (MacOSaiXHandPickedImageSource *)handPickedImageSource
//{
//	NSEnumerator			*imageSourceEnumerator = [[self imageSources] objectEnumerator];
//	id<MacOSaiXImageSource>	imageSource = nil;
//	while (imageSource = [imageSourceEnumerator nextObject])
//		if ([imageSource isKindOfClass:[MacOSaiXHandPickedImageSource class]])
//			break;
//	
//	if (!imageSource)
//	{
//		imageSource = [[[MacOSaiXHandPickedImageSource alloc] init] autorelease];
//		[self addImageSource:imageSource];
//	}
//	
//	return (MacOSaiXHandPickedImageSource *)imageSource;
//}


// TODO: just listen for the notifications from the tiles
//- (void)setHandPickedImageAtPath:(NSString *)path withMatchValue:(float)matchValue forTile:(MacOSaiXTile *)tile
//{
//	MacOSaiXHandPickedImageSource	*handPickedSource = [self handPickedImageSource];
//	
//	if (![tile userChosenImageMatch])
//	{
//			// Increase the image count for the hand picked source.
//		[enumerationsLock lock];
//			unsigned long	currentCount = [[imagesFoundCounts objectForKey:[NSValue valueWithPointer:handPickedSource]] unsignedLongValue];
//			[imagesFoundCounts setObject:[NSNumber numberWithUnsignedLong:currentCount + 1] 
//								  forKey:[NSValue valueWithPointer:handPickedSource]];
//		[enumerationsLock unlock];
//	}
//	
//	[tile setUserChosenImageMatch:[MacOSaiXImageMatch imageMatchWithValue:matchValue 
//													   forImageIdentifier:path 
//														  fromImageSource:handPickedSource 
//																  forTile:tile]];
//}
//
//
//- (void)removeHandPickedImageForTile:(MacOSaiXTile *)tile
//{
//	if ([tile userChosenImageMatch])
//	{
//			// Decrease the image count for the hand picked source.
//		MacOSaiXHandPickedImageSource	*handPickedSource = [self handPickedImageSource];
//		[enumerationsLock lock];
//			unsigned long	currentCount = [[imagesFoundCounts objectForKey:[NSValue valueWithPointer:handPickedSource]] unsignedLongValue];
//			[imagesFoundCounts setObject:[NSNumber numberWithUnsignedLong:currentCount - 1] 
//								  forKey:[NSValue valueWithPointer:handPickedSource]];
//		[enumerationsLock unlock];
//		
//		[tile setUserChosenImageMatch:nil];
//	}
//}


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
	
	[imageSourcesLock lock];
		NSEnumerator					*imageSourceEnumeratorEnumerator = [imageSourceEnumerators objectEnumerator];
		MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = nil;
		while (imageSourceEnumerator = [imageSourceEnumeratorEnumerator nextObject])
			if (![[imageSourceEnumerator imageSource] canRefetchImages])
			{
				NSString	*sourceCachePath = [diskCachePath stringByAppendingPathComponent:
													[self diskCacheSubPathForImageSource:[imageSourceEnumerator imageSource]]];
				[[MacOSaiXImageCache sharedImageCache] setCacheDirectory:sourceCachePath forSource:[imageSourceEnumerator imageSource]];
			}
	[imageSourcesLock unlock];
}


#pragma mark -
#pragma mark Image source enumeration


- (unsigned long)numberOfImagesFound
{
	unsigned long	totalCount = 0;
	
	[imageSourcesLock lock];
		NSEnumerator					*imageSourceEnumeratorEnumerator = [imageSourceEnumerators objectEnumerator];
		MacOSaiXImageSourceEnumerator	*imageSourceEnumerator;
		while (imageSourceEnumerator = [imageSourceEnumeratorEnumerator nextObject])
			totalCount += [imageSourceEnumerator numberOfImagesFound];
	[imageSourcesLock unlock];
	
	return totalCount;
}


- (MacOSaiXImageQueue *)imageQueue
{
	return newImageQueue;
}


- (void)addSourceImageToQueue:(MacOSaiXSourceImage *)sourceImage
{
	[newImageQueue pushImage:sourceImage];
	
	if (!pausing && !paused && !calculateImageMatchesThreadAlive)
		[NSApplication detachDrawingThread:@selector(calculateImageMatches) toTarget:self withObject:nil];
}


#pragma mark -
#pragma mark Image matching


- (NSMutableArray *)betterMatchesForSourceImage:(MacOSaiXSourceImage *)sourceImage 
{
	NSMutableArray	*betterMatches = [betterMatchesCache objectForKey:[sourceImage universalIdentifier]];
	
	if (betterMatches)
	{
			// The cache contains the list of tiles which could be improved by using this image.  Remove any tiles from the list that have gotten a better match since the list was cached.  Also remove any tiles that have the exact same match value but for a different image.  This avoids infinite loop conditions if you have multiple images that have the exact same match value (typically when there are multiple files containing the exact same image).
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
								  [currentMatch sourceImage] != sourceImage)))
				indicesToRemove[countOfIndicesToRemove++] = currentIndex;
			
			currentIndex++;
		}
		[betterMatches removeObjectsFromIndices:indicesToRemove numIndices:countOfIndicesToRemove];
		
			// If only the dummy entry is left then we need to rematch.
		if ([betterMatches count] == 1 && ![(MacOSaiXImageMatch *)[betterMatches objectAtIndex:0] tile])
			betterMatches = nil;
	}
	
	if (!betterMatches)
	{
			// The better matches for this image are not in the cache so we must calculate them.
		betterMatches = [NSMutableArray array];
		
			// Loop through all of the tiles and calculate how well this image matches.
		MacOSaiXImageMatcher	*matcher = [MacOSaiXImageMatcher sharedMatcher];
		NSSize					imageSize = [sourceImage nativeSize];
		NSEnumerator			*tileEnumerator = [tiles objectEnumerator];
		MacOSaiXTile			*tile = nil;
		while ((tile = [tileEnumerator nextObject]) && !pausing)
		{
			NSAutoreleasePool	*tilePool = [[NSAutoreleasePool alloc] init];
			
			if (![[tile disallowedImages] containsObject:sourceImage])
			{
				NSBitmapImageRep	*tileBitmap = [tile bitmapRep];
				NSSize				tileSize = [tileBitmap size];
				float				croppedPercentage;
				
					// See if the image will be cropped too much.
				if ((imageSize.width / tileSize.width) < (imageSize.height / tileSize.height))
					croppedPercentage = (imageSize.width * (imageSize.height - imageSize.width * tileSize.height / tileSize.width)) / 
						(imageSize.width * imageSize.height) * 100.0;
				else
					croppedPercentage = ((imageSize.width - imageSize.height * tileSize.width / tileSize.height) * imageSize.height) / 
						(imageSize.width * imageSize.height) * 100.0;
				
				if (croppedPercentage <= [self imageCropLimit])
				{
						// Get a rep for the image scaled to the tile's bitmap size.
					NSBitmapImageRep	*imageRep = [sourceImage imageRepAtSize:tileSize];
					
					if (imageRep)
					{
							// Calculate how well this image matches this tile.
						float				previousBest = ([tile uniqueImageMatch] ? [[tile uniqueImageMatch] matchValue] : 1.0), 
											matchValue = [matcher compareImageRep:tileBitmap 
																		 withMask:[tile maskRep] 
																	   toImageRep:imageRep
																	 previousBest:previousBest];
						MacOSaiXImageMatch	*newMatch = [MacOSaiXImageMatch imageMatchWithValue:matchValue 
																				 forSourceImage:sourceImage
																						forTile:tile], 
											*previousBestMatch = [tile bestImageMatch];
						
							// If this image matches better than the tile's current best or this image is the same as the tile's current best then add it to the list of tile's that might get this image.
						if (matchValue < previousBest || [[tile uniqueImageMatch] sourceImage] == sourceImage)
							[betterMatches addObject:newMatch];
						
							// Update the tile's best match if appropriate.
						if (!previousBestMatch || matchValue < [previousBestMatch matchValue])
						{
							[tile setBestImageMatch:newMatch];
							
							MacOSaiXImageSourceEnumerator	*sourceImageEnumerator = [sourceImage enumerator];
							if ([sourceImageEnumerator isOnProbation] && 
								[previousBestMatch sourceImage] && 
								[[previousBestMatch sourceImage] enumerator] != sourceImageEnumerator)
								[sourceImageEnumerator rememberProbationaryImage:[previousBestMatch sourceImage]];
						}
					}
					else	// no image rep for image
						;	// anything to do or just lose the chance to match this image to this tile?
				}
			}
			
			[tilePool release];
		}
		
		// Sort the array with the best matches first.
		[betterMatches sortUsingSelector:@selector(compare:)];
	}
	
	return betterMatches;
}


- (void)setBetterMatches:(NSArray *)betterMatches forSourceImage:(MacOSaiXSourceImage *)sourceImage
{
		// Limit the number of matches cached otherwise we'll swamp RAM.
	int			maxBetterMatches = 4 + ([tiles count] / 2.0 * (100.0 - [self imageReuseDistance]) / 100.0);
	if ([betterMatches count] <= maxBetterMatches)
		[betterMatchesCache setObject:betterMatches forKey:[sourceImage universalIdentifier]];
	else
	{
		NSMutableArray	*croppedMatches = [NSMutableArray arrayWithArray:[betterMatches subarrayWithRange:NSMakeRange(0, maxBetterMatches)]];
		
			// Add a dummy entry with a nil tile on the end so we know that entries were removed.
		[croppedMatches addObject:[[[MacOSaiXImageMatch alloc] init] autorelease]];
		
		[betterMatchesCache setObject:croppedMatches forKey:[sourceImage universalIdentifier]];
	}
	
}


- (NSArray *)validMatchesForImageUsageSettings:(NSArray *)matches
{
	NSMutableArray		*validMatches = [NSMutableArray array];
	BOOL				haveAllMatches = ([(MacOSaiXImageMatch *)[matches lastObject] tile] != nil);
	
		// A use count of zero means no limit on the number of times an image can be used.
	int					useCount = [self imageUseCount];
	if (useCount == 0)
		useCount = [matches count];
	
		// If the list of matches is incomplete and there aren't enough matches to satisfy the settings then don't bother wasting time on the math.
	if ([matches count] < useCount && !haveAllMatches)
		matches = nil;
	
		// Loop through the list of matches and pick the first items (up to the use count) that aren't too close together.
	NSEnumerator		*matchEnumerator = [matches objectEnumerator];
	MacOSaiXImageMatch	*match = nil;
	while ((match = [matchEnumerator nextObject]) && [validMatches count] < useCount)
	{
		if ([validMatches count] == 0)
		{
				// Always use the first (best) match.
			[validMatches addObject:match];
		}
		else
		{
				// This match is valid if it isn't too close to any of the already valid matches.
			NSRect				matchTileBounds = [[[match tile] outline] bounds];
			float				minDistanceApart = [self targetImageMinimumReuseDistance];
			BOOL				matchTooClose = NO;
			NSEnumerator		*validMatchesEnumerator = [validMatches objectEnumerator];
			MacOSaiXImageMatch	*validMatch = nil;
			
			while (!matchTooClose && (validMatch = [validMatchesEnumerator nextObject]))
			{
				NSRect	validMatchBounds = [[[validMatch tile] outline] bounds];
				float	widthDiff = NSMidX(matchTileBounds) - NSMidX(validMatchBounds), 
						heightDiff = NSMidY(matchTileBounds) - NSMidY(validMatchBounds), 
						distanceSquared = widthDiff * widthDiff + heightDiff * heightDiff;
				
				if (distanceSquared < minDistanceApart)
					matchTooClose = YES;
			}
			
			if (!matchTooClose)
				[validMatches addObject:match];
		}
	}
	
		// If more matches could have been used and we were passed an incomplete list of matches then signal that we need a complete list.
	if ([validMatches count] < useCount && !haveAllMatches)
		validMatches = nil;
	
	return validMatches;
}


- (void)calculateImageMatches
{
		// This method is called in a new thread whenever a non-empty image queue is discovered.
		// It pulls images from the queue and matches them against each tile.  Once the queue
		// is empty the method will end and the thread is terminated.
    NSAutoreleasePool	*threadPool = [[NSAutoreleasePool alloc] init];

        // Make sure only one copy of this thread runs at any time.
	[calculateImageMatchesLock lock];
		if (calculateImageMatchesThreadAlive)
		{
                // Another copy is running, just exit.
			[calculateImageMatchesLock unlock];
			[threadPool release];
			return;
		}
		calculateImageMatchesThreadAlive = YES;
	[calculateImageMatchesLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
														object:self];
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
	MacOSaiXImageCache	*imageCache = [MacOSaiXImageCache sharedImageCache];
	unsigned int		revisitStep = 0;
	
	while (!pausing && ([newImageQueue count] > 0 || [revisitImageQueue count] > 0))
	{
		while (!pausing && ([newImageQueue count] > 0 || [revisitImageQueue count] > 0))
		{
				// As long as the image source threads are feeding images into the queue this loop will continue running so create a pool just for this pass through the loop.
			NSAutoreleasePool	*imagePool = [[NSAutoreleasePool alloc] init];
			
			NS_DURING
					// Decide whether to match a new image or revisit a previously matched one.
				MacOSaiXImageQueue				*imageQueue = nil;
				if ([newImageQueue count] > 0 && [revisitImageQueue count] == 0)
					imageQueue = newImageQueue;
				else if ([revisitImageQueue count] > 0 && [imageQueue count] == 0)
					imageQueue = revisitImageQueue;
				else if ([revisitImageQueue count] > 0 && [imageQueue count] > 0)
				{
					imageQueue = (revisitStep < 15 ? newImageQueue : revisitImageQueue);
					revisitStep = (revisitStep + 1) % 16;
				}
				
					// Pull the next image from the queue.
				MacOSaiXSourceImage				*sourceImage = [imageQueue popImage];
				MacOSaiXImageSourceEnumerator	*sourceImageEnumerator = [sourceImage enumerator];
				BOOL							sourceImageInUse = NO, 
												sourceImageIsDisplayed = NO;
				
					// Check if the probationary period for the most recently added/edited image source has ended.
				if ([sourceImageEnumerator isOnProbation])
					[sourceImageEnumerator rememberProbationaryImage:sourceImage];
				
					// Find the tiles that match this image better than their current image.  The returned array will be sorted by match value with the best match first.
				NSMutableArray	*betterMatches = [self betterMatchesForSourceImage:sourceImage];
				if ([betterMatches count] == 0)
				{
	//				NSLog(@"%@ from %@ is no longer needed", [sourceImage imageIdentifier], [sourceImage imageSource]);
					[betterMatchesCache removeObjectForKey:[sourceImage universalIdentifier]];
				}
				else
				{
					// Figure out which tiles should use this image based on the usage settings.
					
					NSArray	*validMatches = [self validMatchesForImageUsageSettings:betterMatches];
					
					if (!validMatches)
					{
						// There weren't enough matches in the cache to satisfy the image resue settings so we need to re-calculate the matches.
						
						[betterMatchesCache removeObjectForKey:[sourceImage universalIdentifier]];
						betterMatches = nil;	// The betterMatchesCache had the last retain on the array.
						
						[revisitImageQueue pushImage:sourceImage];
						
						sourceImageInUse = YES;
					}
					else if ([validMatches count] > 0)
					{
							// There were enough matches in betterMatches.  Update the winning tiles.
						NSEnumerator		*validMatchesEnumerator = [validMatches objectEnumerator];
						MacOSaiXImageMatch	*validMatch = nil;
						while (validMatch = [validMatchesEnumerator nextObject])
						{
							MacOSaiXImageMatch	*previousMatch = [[validMatch tile] uniqueImageMatch];
							if (previousMatch)
							{
								if (![[previousMatch sourceImage] isEqualTo:sourceImage])
									[revisitImageQueue pushImage:[previousMatch sourceImage]];
								
								if ([sourceImageEnumerator isOnProbation] && 
									[previousMatch sourceImage] && 
									[[previousMatch sourceImage] enumerator] != sourceImageEnumerator)
										[sourceImageEnumerator rememberProbationaryImage:[previousMatch sourceImage]];
							}
							
							[[validMatch tile] setUniqueImageMatch:validMatch];
							
							if ([[validMatch tile] fillStyle] == fillWithUniqueMatch)
								sourceImageIsDisplayed = YES;
						}
						
							// Remember which tiles matched better so we don't have to do all of the matching again.
						[self setBetterMatches:betterMatches forSourceImage:sourceImage];
						
						sourceImageInUse = YES;
					}
				}
				
				if (!sourceImageInUse && ![[[sourceImage enumerator] imageSource] canRefetchImages])
				{
						// Check if the image is the best match for any tile.
					NSEnumerator			*tileEnumerator = [tiles objectEnumerator];
					MacOSaiXTile			*tile = nil;
					while (!sourceImageInUse && (tile = [tileEnumerator nextObject]))
					{
						if ([[[tile bestImageMatch] sourceImage] isEqualTo:sourceImage])
						{
							sourceImageInUse = YES;
							break;
						}
					}
				}
					
				if (!sourceImageInUse)
					[imageCache removeCachedImagesWithIdentifiers:[NSArray arrayWithObject:[sourceImage imageIdentifier]] 
													   fromSource:[[sourceImage enumerator] workingImageSource]];
				
				[sourceImageEnumerator setImageIdentifier:[sourceImage imageIdentifier] isInUse:sourceImageIsDisplayed];
					
			NS_HANDLER
				#ifdef DEBUG
					NSLog(@"Could not calculate image matches: %@", [localException reason]);
				#endif
			NS_ENDHANDLER

			[imagePool release];
		}
		
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	}
	
	// TODO: put the image back on the queue if we were paused.
	
	[calculateImageMatchesLock lock];
		calculateImageMatchesThreadAlive = NO;
	[calculateImageMatchesLock unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
														object:self];

		// clean up and shutdown this thread
    [threadPool release];
}


- (unsigned long)numberOfImagesInUse
{
	unsigned long					totalCount = 0;
	NSEnumerator					*sourceEnumeratorEnumerator = [[self imageSourceEnumerators] objectEnumerator];
	MacOSaiXImageSourceEnumerator	*sourceEnumerator = nil;

	while (sourceEnumerator = [sourceEnumeratorEnumerator nextObject])
		totalCount += [[sourceEnumerator imageIdentifiersInUse] count];
	
	return totalCount;
}


#pragma mark -
#pragma mark Status


- (BOOL)isBusy
{
	BOOL	isBusy = (tileBitmapExtractionThreadAlive || calculateImageMatchesThreadAlive);
	
	if (!isBusy)
	{
		[imageSourcesLock lock];
			NSEnumerator					*imageSourceEnumeratorEnumerator = [imageSourceEnumerators objectEnumerator];
			MacOSaiXImageSourceEnumerator	*imageSourceEnumerator;
			while (imageSourceEnumerator = [imageSourceEnumeratorEnumerator nextObject])
				if ([imageSourceEnumerator isEnumerating])
					isBusy = YES;
		[imageSourcesLock unlock];
	}
	
	return isBusy;
}


- (NSString *)busyStatus
{
	NSString	*status = nil;
	
	if ([tilesWithoutBitmaps count] > 0)
		status = NSLocalizedString(@"Extracting tiles from target image...", @"");	// TODO: include the % complete (localized)
	else if (calculateImageMatchesThreadAlive)
		status = NSLocalizedString(@"Matching images...", @"");
	else if ([self isBeingLoaded])
		status = NSLocalizedString(@"Loading project...", @"");
	else if ([self isBusy])
		status = NSLocalizedString(@"Looking for new images...", @"");
	
	return status;
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
		[imageSourceEnumerators makeObjectsPerformSelector:@selector(pause)];
			
			// Allow any enumerator threads to queue any pending images so they can unlock and exit.
		[newImageQueue setMaximumCount:0];
		
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
		if ([self targetImage] && [self tileShapes] && [self imageOrientations])
		{
			// Start the worker threads.
			
			pausing = NO;
			paused = NO;
			
				// Finish extracting any tile bitmaps.
			if ([tilesWithoutBitmaps count] > 0)
				[NSThread detachNewThreadSelector:@selector(extractTileBitmaps) toTarget:self withObject:nil];
			
			[newImageQueue setMaximumCount:8];
			
				// Start or restart the image source enumerators.
			[imageSourceEnumerators makeObjectsPerformSelector:@selector(resume)];
			
			[NSApplication detachDrawingThread:@selector(calculateImageMatches) toTarget:self withObject:nil];
		}
		else
			paused = NO;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXMosaicDidChangeBusyStateNotification 
															object:self];
	}
}


#pragma mark -
#pragma mark "Don't Use" support


- (void)removeDisallowedImage:(MacOSaiXDisallowedImage *)disallowedImage
{
	BOOL			needToReset = NO;
	NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
	MacOSaiXTile	*tile = nil;
	
	while (tile = [tileEnumerator nextObject])
	{
		if ([tile fillStyle] == fillWithHandPicked && [disallowedImage isEqualTo:[[tile userChosenImageMatch] sourceImage]])
		{
			[tile setFillStyle:fillWithUniqueMatch];
			[tile setUserChosenImageMatch:nil];
		}
		
		if ([tile fillStyle] == fillWithUniqueMatch && [disallowedImage isEqualTo:[[tile uniqueImageMatch] sourceImage]])
		{
			[tile setUniqueImageMatch:nil];
			needToReset = YES;
		}
		
		if ([disallowedImage isEqualTo:[[tile bestImageMatch] sourceImage]])
			[tile setBestImageMatch:nil];
	}
	
	if (needToReset)
		[self resetIncludingTiles:NO];
}


- (void)disallowImage:(id)image
{
	MacOSaiXDisallowedImage	*disallowedImage = nil;
	
	if ([image isKindOfClass:[MacOSaiXDisallowedImage class]])
		disallowedImage = image;
	else if ([image isKindOfClass:[MacOSaiXSourceImage class]])
		disallowedImage = [MacOSaiXDisallowedImage imageWithSourceImage:image];
	else
		[NSException raise:NSInvalidArgumentException format:@"Invalid object passed to -disallowImage:"];
	
	[disallowedImages addObject:disallowedImage];
	
	[self removeDisallowedImage:disallowedImage];
}


- (NSArray *)disallowedImages
{
	return [NSArray arrayWithArray:disallowedImages];
}


- (void)disallowedImagesDidChange:(NSNotification *)notification
{
	MacOSaiXDisallowedImage	*disallowedImage = [notification object];
	
	if (disallowedImage)
		[self removeDisallowedImage:disallowedImage];
	else
	{
		// TBD: Will this ever happen?  If so then loop through all of the globally disallowed images.
	}
}


- (void)setIsBeingLoaded:(BOOL)flag
{
	isBeingLoaded = flag;
}


- (BOOL)isBeingLoaded
{
	return isBeingLoaded;
}


#pragma mark -


- (void)dealloc
{
	[imageSourceEnumerators release];
	[imageSourcesLock release];
	[diskCacheSubPaths release];
	
    [targetImage release];
	[imageIdentifiersInUse release];
	[betterMatchesCache release];
	[calculateImageMatchesLock release];
    [tiles release];
	[tilesWithoutBitmapsLock release];
	[tilesWithoutBitmaps release];
    [tileShapes release];
    [newImageQueue release];
	[revisitImageQueue release];
	
	[disallowedImages release];
	
    [super dealloc];
}


@end

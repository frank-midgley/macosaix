/*
	MacOSaiXImageCache.m
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import "MacOSaiXImageCache.h"

#import <unistd.h>


static	MacOSaiXImageCache	*sharedImageCache = nil;


@implementation MacOSaiXImageCache


+ (MacOSaiXImageCache *)sharedImageCache
{
	if (!sharedImageCache)
		sharedImageCache = [[MacOSaiXImageCache alloc] init];
	
	return sharedImageCache;
}


- (id)init
{
    if (self = [super init])
    {
		cacheLock = [[NSRecursiveLock alloc] init];
		diskCache = [[NSMutableDictionary alloc] init];
		memoryCache = [[NSMutableDictionary alloc] init];
		nativeImageSizeDict = [[NSMutableDictionary alloc] init];
		sourceCacheDirectories = [[NSMutableDictionary alloc] init];
		
		imageRepRecencyArray = [[NSMutableArray array] retain];
		imageIdentifierRecencyArray = [[NSMutableArray array] retain];
		imageSourceRecencyArray = [[NSMutableArray array] retain];
		
		maxMemoryCacheSize = NSRealMemoryAvailable() / 3;
		
			// Create a window that we can use to scale down images.  Ideally we'd just 
			// lock focus on an image but currently that uses a cached window that has 
			// threading issues.  Using this window avoids the crashes.
		scalingWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 512.0, 512.0) 
													styleMask:NSBorderlessWindowMask 
													  backing:NSBackingStoreBuffered 
														defer:NO];
		[scalingWindow orderOut:self];
	}
	
    return self;
}


- (void)cacheImageRep:(NSBitmapImageRep *)imageRep
	   withIdentifier:(NSString *)imageIdentifier 
		   fromSource:(id<MacOSaiXImageSource>)imageSource
{
		// Remove the least recently accessed image rep from the memory cache until we have enough room to store the new rep.
	unsigned long long	imageRepSize = [imageRep bytesPerRow] * [imageRep pixelsHigh];
	while ([memoryCache count] > 0 && (currentMemoryCacheSize + imageRepSize) > maxMemoryCacheSize)
	{
		NSString				*oldestIdentifier = [imageIdentifierRecencyArray lastObject];
		id<MacOSaiXImageSource>	oldestSource = [[imageSourceRecencyArray lastObject] pointerValue];
		NSValue					*oldestSourceKey = [NSValue valueWithPointer:oldestSource];
		NSBitmapImageRep		*oldestRep = [imageRepRecencyArray lastObject];
		unsigned long long		oldestRepSize = [oldestRep bytesPerRow] * [oldestRep pixelsHigh];
		NSMutableDictionary		*oldestImageSourceCache = [memoryCache objectForKey:oldestSourceKey];
		NSMutableArray			*oldestRepArray = [oldestImageSourceCache objectForKey:oldestIdentifier];
		
		[oldestRepArray removeObjectIdenticalTo:oldestRep];
		if ([oldestRepArray count] == 0)
		{
			[oldestImageSourceCache removeObjectForKey:oldestIdentifier];
			
				// Remove the native size of the oldest image unless it's the source of the new rep being cached.
			if (![oldestIdentifier isEqualToString:imageIdentifier] || oldestSource != imageSource)
				[[nativeImageSizeDict objectForKey:oldestSourceKey] removeObjectForKey:oldestIdentifier];
			
			if ([oldestImageSourceCache count] == 0)
				[memoryCache removeObjectForKey:oldestSourceKey];
		}
		
		[imageIdentifierRecencyArray removeLastObject];
		[imageSourceRecencyArray removeLastObject];
		[imageRepRecencyArray removeLastObject];
		
		currentMemoryCacheSize -= oldestRepSize;
		cachedImageCount--;
	}

		// Get the existing cache for this image source or create a new one.
	NSValue				*imageSourceKey = [NSValue valueWithPointer:imageSource];
	NSMutableDictionary	*imageSourceCache = [memoryCache objectForKey:imageSourceKey];
	if (!imageSourceCache)
	{
		imageSourceCache = [NSMutableDictionary dictionary];
		[memoryCache setObject:imageSourceCache forKey:imageSourceKey];
	}
	
		// Get the existing set of reps for this image or create a new one.
	NSMutableArray		*keyRepArray = [imageSourceCache objectForKey:imageIdentifier];
	if (!keyRepArray)
	{
		keyRepArray = [NSMutableArray array];
		[imageSourceCache setObject:keyRepArray forKey:imageIdentifier];
	}
	
		// Add the image rep to the memory cache and update its size.
	[keyRepArray addObject:imageRep];
	currentMemoryCacheSize += imageRepSize;
	
		// Remember how recently we last saw this rep.  The newest items are closest to index 0.
	[imageRepRecencyArray insertObject:imageRep atIndex:0];
	[imageIdentifierRecencyArray insertObject:imageIdentifier atIndex:0];
	[imageSourceRecencyArray insertObject:imageSourceKey atIndex:0];
	cachedImageCount++;
	
//	NSLog(@"%llu bytes, %d image reps in cache", currentMemoryCacheSize, [imageRepRecencyArray count]);
}


- (void)setCacheDirectory:(NSString *)directoryPath forSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
		[sourceCacheDirectories setObject:directoryPath forKey:[NSValue valueWithPointer:imageSource]];
	[cacheLock unlock];
}


- (NSString *)cachePathForIdentifier:(NSString *)imageIdentifier forSource:(id<MacOSaiXImageSource>)imageSource
{
	NSString		*diskCachePath = [sourceCacheDirectories objectForKey:[NSValue valueWithPointer:imageSource]];
	NSMutableString	*escapedIdentifier = [NSMutableString stringWithString:imageIdentifier];
	[escapedIdentifier replaceOccurrencesOfString:@"/" 
									   withString:@"#slash#" 
										  options:NSLiteralSearch 
											range:NSMakeRange(0, [escapedIdentifier length])];
	
	return [[diskCachePath stringByAppendingPathComponent:escapedIdentifier]
						   stringByAppendingPathExtension:@"tiff"];
}


- (void)cacheImage:(NSImage *)image 
	withIdentifier:(NSString *)imageIdentifier 
		fromSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
	
	NS_DURING
			// Get a bitmap image rep at the full size of the image.
		NSBitmapImageRep	*fullSizeRep = nil;
		
			// Check if the image already has a rep we can use.
		NSEnumerator		*existingRepEnumerator = [[image representations] objectEnumerator];
		NSImageRep			*existingRep = nil;
		while (existingRep = [existingRepEnumerator nextObject])
			if ([existingRep isKindOfClass:[NSBitmapImageRep class]] && 
				(!fullSizeRep || [existingRep size].width > [fullSizeRep size].width))
				fullSizeRep = (NSBitmapImageRep *)existingRep;
		
			// If not then create one.
		while (!fullSizeRep)
		{
			NS_DURING
				[image lockFocus];
					NSImageRep	*originalRep = [[image representations] objectAtIndex:0];
					NSRect		imageRect = NSMakeRect(0.0, 0.0, [originalRep pixelsWide], [originalRep pixelsHigh]);
					fullSizeRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:imageRect] autorelease];
				[image unlockFocus];
			NS_HANDLER
				#ifdef DEBUG
					NSLog(@"Failed to lock focus on %@", imageIdentifier);
				#endif
			NS_ENDHANDLER
		}

			// Cache the image in memory for efficient retrieval.
		[self cacheImageRep:fullSizeRep withIdentifier:imageIdentifier fromSource:imageSource];
		
			// Remember the native size of the image.
		NSValue				*imageSourceKey = [NSValue valueWithPointer:imageSource];
		NSMutableDictionary	*sourceNativeImageSizeDict = [nativeImageSizeDict objectForKey:imageSourceKey];
		if (!sourceNativeImageSizeDict)
		{
			sourceNativeImageSizeDict = [NSMutableDictionary dictionary];
			[nativeImageSizeDict setObject:sourceNativeImageSizeDict forKey:imageSourceKey];
		}
		[sourceNativeImageSizeDict setObject:[NSValue valueWithSize:[fullSizeRep size]] forKey:imageIdentifier];
		
			// Save the image to disk if its source can't refetch.
		if (![imageSource canRefetchImages])
		{
			NSString	*imagePath = [self cachePathForIdentifier:imageIdentifier forSource:imageSource];
			if (imagePath)
				[[image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0] 
											   writeToFile:imagePath atomically:NO];
		}
	NS_HANDLER
		#ifdef DEBUG
			NSLog(@"Could not cache \"%@\" (%@)", imageIdentifier, [localException reason]);
		#endif
	NS_ENDHANDLER
	
	[cacheLock unlock];
}


- (NSSize)nativeSizeOfImageWithIdentifier:(NSString *)imageIdentifier 
							   fromSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
		NSValue		*sizeValue = [[nativeImageSizeDict objectForKey:[NSValue valueWithPointer:imageSource]] 
										objectForKey:imageIdentifier];
	[cacheLock unlock];
	
	if (sizeValue)
		return [sizeValue sizeValue];
	else
		return NSZeroSize;
}


- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size 
					   forIdentifier:(NSString *)imageIdentifier 
						  fromSource:(id<MacOSaiXImageSource>)imageSource
{
	NSBitmapImageRep	*imageRep = nil,
						*scalableRep = nil;

	size = NSMakeSize(roundf(size.width), roundf(size.height));
	
	[cacheLock lock];
		NSValue			*imageSourceKey = [NSValue valueWithPointer:imageSource], 
						*nativeSizeValue = [[nativeImageSizeDict objectForKey:imageSourceKey]
												objectForKey:imageIdentifier];
		
		if (nativeSizeValue)
		{
				// There is at least one rep cached for this image.  Calculate the size that is 
				// just small enough to enclose the requested size.
			NSSize			nativeSize = [nativeSizeValue sizeValue];
			
				// Check if there is a cached image rep we can use.
			NSArray				*imageReps = [[memoryCache objectForKey:[NSValue valueWithPointer:imageSource]] 
													objectForKey:imageIdentifier];
			NSEnumerator		*cachedRepEnumerator = [imageReps objectEnumerator];
			NSBitmapImageRep	*cachedRep = nil;
			while (cachedRep = [cachedRepEnumerator nextObject])
			{
				NSSize	cachedRepSize = [cachedRep size];
				
				if (NSEqualSizes(cachedRepSize, size))
				{
						// Found an exact size match.  Perfect cache hit.
					perfectHitCount++;
					imageRep = cachedRep;
					
						// Move the image rep to the head of the recency arrays so it 
						// stays in the cache longer.
					int index = [imageRepRecencyArray indexOfObjectIdenticalTo:imageRep];
					if (index != NSNotFound)	// should always be found
					{
						[imageRepRecencyArray removeObjectAtIndex:index];
						[imageIdentifierRecencyArray removeObjectAtIndex:index];
						[imageSourceRecencyArray removeObjectAtIndex:index];
					}
					[imageRepRecencyArray insertObject:imageRep atIndex:0];
					[imageIdentifierRecencyArray insertObject:imageIdentifier atIndex:0];
					[imageSourceRecencyArray insertObject:imageSourceKey atIndex:0];
					break;
				}
				else if (NSEqualSizes(cachedRepSize, nativeSize))
					scalableRep = cachedRep;	// this is the original, OK to scale from it
			}
		}
		
		if (!imageRep && scalableRep)
		{
				// Scale and crop a copy of the closest rep to the desired size.
			scalableHitCount++;
			
			NSRect		scaledRect;
			if (([scalableRep pixelsWide] / size.width) < ([scalableRep pixelsHigh] / size.height))
			{
				float	scaledHeight = [scalableRep pixelsHigh] * size.width / [scalableRep pixelsWide];
				scaledRect = NSMakeRect(0.0, (size.height - scaledHeight) / 2.0, size.width, scaledHeight);
			}
			else
			{
				float	scaledWidth = [scalableRep pixelsWide] * size.height / [scalableRep pixelsHigh];
				scaledRect = NSMakeRect((size.width - scaledWidth) / 2.0, 0.0, scaledWidth, size.height);
			}
			
				// Use the scaling window if possible, else locking focus on an image and risk a crash.
			id			scalingContainer = [scalingWindow contentView];
			if (size.width > NSWidth([scalingContainer frame]) || size.height > NSHeight([scalingContainer frame]))
				scalingContainer = [[[NSImage alloc] initWithSize:size] autorelease];
			
			BOOL	gotFocus = NO;
			NS_DURING
				[scalingContainer lockFocus];
				gotFocus = YES;
				[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
				[scalableRep drawInRect:scaledRect];
				imageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, size.width, size.height)] autorelease];
			NS_HANDLER
				#ifdef DEBUG
					NSLog(@"Could not scale an image to (%f, %f)", size.width, size.height);
				#endif
			NS_ENDHANDLER
			
			if (gotFocus)
				[scalingContainer unlockFocus];
			
			if (imageRep)
				[self cacheImageRep:imageRep withIdentifier:imageIdentifier fromSource:imageSource];
		}
		
		if (!imageRep)
		{
				// There is no rep we can use in the memory cache.
			missCount++;
//			NSLog(@"Cache miss rate: %.3f%%", missCount * 100.0 / (perfectHitCount + scalableHitCount + missCount));
			
				// Re-request the image from the source or pull it from the source's disk cache.
			NSImage	*image = nil;
			if ([imageSource canRefetchImages])
			{
				BOOL				fetchedThumbnail = NO;
				volatile NSImage	*thumbnailImage = nil,
									*fullSizeImage = nil;
				
				[cacheLock unlock];
				
					// First grab the thumbnail.
				if (!NSEqualSizes(size, NSZeroSize) && size.width <= 128.0 && size.height <= 128.0)
				{
					fetchedThumbnail = YES;
					NS_DURING
						thumbnailImage = [imageSource thumbnailForIdentifier:imageIdentifier];
					NS_HANDLER
					NS_ENDHANDLER
				}
					
					// If there's no thumbnail or it's not big enough then grab the full size image.
				NSImageRep	*originalRep = [[thumbnailImage representations] objectAtIndex:0];
				if (!thumbnailImage || [originalRep pixelsWide] < size.width || [originalRep pixelsHigh] < size.height)
				{
					NS_DURING
						fullSizeImage = [imageSource imageForIdentifier:imageIdentifier];
					NS_HANDLER
					NS_ENDHANDLER
					
					if (!fullSizeImage && !fetchedThumbnail)
					{
							// If we couldn't get the full sized image then grab the thumbnail no matter what size is being requested.
						NS_DURING
							thumbnailImage = [imageSource thumbnailForIdentifier:imageIdentifier];
						NS_HANDLER
						NS_ENDHANDLER
					}
				}
				[cacheLock lock];
				
					// Prefer the full size image over the thumbnail.
				image = (NSImage *)(fullSizeImage ? fullSizeImage : thumbnailImage);
			}
			else
			{
				NSString	*imagePath = [self cachePathForIdentifier:imageIdentifier forSource:imageSource];
				if (imagePath)
				{
					image = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
					
					#ifdef DEBUG
						if (!image)
							NSLog(@"Crap!  Lost an image!");
					#endif
				}
			}
			
            if ([image isValid])
			{
				[image setCachedSeparately:YES];
				[image setCacheMode:NSImageCacheNever];
				
					// Ignore whatever DPI was set for the image.  We just care about the bitmap's pixel size.
					// TBD: scale down really big images?
				NSImageRep	*originalRep = [[image representations] objectAtIndex:0];
				NSSize		bitmapSize = NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh]);
				[originalRep setSize:bitmapSize];
				[image setSize:bitmapSize];
				
				[self cacheImage:image withIdentifier:imageIdentifier fromSource:imageSource];
				
					// Now that the image is cached again get a rep at the desired size.
					// A size of NSZeroSize means we should return a rep at the image's native size.
				if (NSEqualSizes(size, NSZeroSize))
					imageRep = [self imageRepAtSize:bitmapSize forIdentifier:imageIdentifier fromSource:imageSource];
				else
					imageRep = [self imageRepAtSize:size forIdentifier:imageIdentifier fromSource:imageSource];
			}
			else
			{
				#ifdef DEBUG
					NSLog(@"Invalid image retrieved for \"%@\" from %@", imageIdentifier, imageSource);
				#endif
			}
		}
	[cacheLock unlock];
	
	return imageRep;
}


- (void)removeCachedImagesWithIdentifiers:(NSArray *)imageIdentifiers 
							   fromSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
		NSEnumerator	*identifierEnumerator = [imageIdentifiers objectEnumerator];
		NSString		*identifier = nil;
		while (identifier = [identifierEnumerator nextObject])
		{
				// Remove the image from the memory cache.
			int		index = [imageRepRecencyArray count] - 1;
			while (index >= 0)
			{
				if ([[imageSourceRecencyArray objectAtIndex:index] pointerValue] == imageSource &&
					[[imageIdentifierRecencyArray objectAtIndex:index] isEqualToString:identifier])
				{
					NSBitmapImageRep	*imageRep = [imageRepRecencyArray objectAtIndex:index];
					currentMemoryCacheSize -= [imageRep bytesPerRow] * [imageRep pixelsHigh];
					
					[imageRepRecencyArray removeObjectAtIndex:index];
					[imageIdentifierRecencyArray removeObjectAtIndex:index];
					[imageSourceRecencyArray removeObjectAtIndex:index];
					cachedImageCount--;
				}
				
				index--;
			}
			
			[memoryCache removeObjectForKey:[NSValue valueWithPointer:imageSource]];
					
			if (![imageSource canRefetchImages])
			{
					// Remove the image from disk.
				NSString	*imagePath = [self cachePathForIdentifier:identifier forSource:imageSource];
				[[NSFileManager defaultManager] removeFileAtPath:imagePath handler:nil];
			}
		}
	[cacheLock unlock];
}


- (void)removeCachedImagesFromSource:(id<MacOSaiXImageSource>)imageSource
{
	[NSThread detachNewThreadSelector:@selector(removedCachedImagesFromSourceInThread:) 
							 toTarget:self 
						   withObject:imageSource];
}


- (void)removedCachedImagesFromSourceInThread:(id<MacOSaiXImageSource>)imageSource
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSValue				*imageSourceKey = [NSValue valueWithPointer:imageSource];
	
	[cacheLock lock];
		[memoryCache removeObjectForKey:imageSourceKey];
		[nativeImageSizeDict removeObjectForKey:imageSourceKey];
		[sourceCacheDirectories removeObjectForKey:imageSourceKey];
		
		signed int		index = [imageRepRecencyArray count];
		while (--index >= 0)
			if ([[imageSourceRecencyArray objectAtIndex:index] pointerValue] == imageSourceKey)
			{
				NSBitmapImageRep	*imageRep = [imageRepRecencyArray objectAtIndex:index];
				currentMemoryCacheSize -= [imageRep bytesPerRow] * [imageRep pixelsHigh];
				
				[imageSourceRecencyArray removeObjectAtIndex:index];
				[imageIdentifierRecencyArray removeObjectAtIndex:index];
				[imageRepRecencyArray removeObjectAtIndex:index];
				
				cachedImageCount--;
			}
	[cacheLock unlock];
			
	[pool release];
}


#pragma Statistics


- (unsigned long long)size
{
	return currentMemoryCacheSize;
}


- (unsigned long)count
{
	return cachedImageCount;
}


#pragma mark


- (void)dealloc
{
	[cachedImagesPath release];
	[cacheLock release];
	[diskCache release];
	[memoryCache release];
	[imageRepRecencyArray release];
	[imageIdentifierRecencyArray release];
	[imageSourceRecencyArray release];
    [scalingWindow close];
	[scalingWindow release];
	
    [super dealloc];
}

@end

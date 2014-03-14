/*
	MacOSaiXImageCache.m
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import "MacOSaiXImageCache.h"

#import "MacOSaiXBitmapImageRep.h"
#import "MacOSaiXSourceImage.h"
#import "NSImage+MacOSaiX.h"

#import <pthread.h>
#import <unistd.h>


static	MacOSaiXImageCache	*sharedImageCache = nil;


@implementation MacOSaiXImageCache


+ (void)initialize
{
	sharedImageCache = [[MacOSaiXImageCache alloc] init];
}


+ (MacOSaiXImageCache *)sharedImageCache
{
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
		
		flatImageRepCache  = [[NSMutableArray array] retain];
		
		maxMemoryCacheSize = NSRealMemoryAvailable() / 4;
	}
	
    return self;
}


- (void)lock
{
	[cacheLock lock];
}


- (void)unlock
{
	[cacheLock unlock];
}


- (id<MacOSaiXImageSource>)imageSourceFromKey:(NSString *)key
{
	void			*imageSourcePtr = 0;
	
	sscanf([key UTF8String], "%p\t", &imageSourcePtr);
	
	return (id<MacOSaiXImageSource>)imageSourcePtr;
}


- (NSString *)imageIdentifierFromKey:(NSString *)key
{
	unsigned int	tabPos = [key rangeOfString:@"\t"].location;
	
	return [key substringFromIndex:tabPos + 1];
}


	// TODO: the imageKey parameter is no longer required
- (void)addImageRep:(MacOSaiXBitmapImageRep *)imageRep toMemoryCacheForKey:(NSString *)imageKey
{
		// Remove the least recently accessed image rep from the memory cache until we have enough room to store the new rep.
	int	imageRepSize = [imageRep bytesPerRow] * [imageRep pixelsHigh];
	
	[cacheLock lock];
		if ([memoryCache count] > 0 && (currentMemoryCacheSize + imageRepSize) > maxMemoryCacheSize)
		{
			[flatImageRepCache sortUsingSelector:@selector(compare:)];
			
			while ([memoryCache count] > 0 && (currentMemoryCacheSize + imageRepSize) > (maxMemoryCacheSize * 0.9))
			{
				MacOSaiXBitmapImageRep	*oldestRep = [flatImageRepCache lastObject];
				unsigned long long		oldestRepSize = [oldestRep bytesPerRow] * [oldestRep pixelsHigh];
				NSString				*oldestKey = [[oldestRep sourceImage] key];
				NSMutableArray			*oldestRepArray = [memoryCache objectForKey:oldestKey];
				
				[oldestRepArray removeObjectIdenticalTo:oldestRep];
				if ([oldestRepArray count] == 0)
				{
					[memoryCache removeObjectForKey:oldestKey];
					if (![oldestKey isEqualToString:imageKey])
						[nativeImageSizeDict removeObjectForKey:oldestKey];
				}
				
				[flatImageRepCache removeLastObject];
				
				currentMemoryCacheSize -= oldestRepSize;
			}
		}
			// Get the existing array for this key or create a new array.
		NSMutableArray	*keyRepArray = [memoryCache objectForKey:imageKey];
		if (!keyRepArray)
		{
			keyRepArray = [NSMutableArray array];
			[memoryCache setObject:keyRepArray forKey:imageKey];
		}
		
			// Add the image rep to the memory cache and update its size.
		[keyRepArray addObject:imageRep];
		currentMemoryCacheSize += imageRepSize;
		
			// Remember how recently we last saw this rep.
			// The newest items are closer to index 0.
		[flatImageRepCache addObject:imageRep];
		
//		NSLog(@"%llu bytes, %d image reps in cache", currentMemoryCacheSize, [flatImageRepCache count]);
	[cacheLock unlock];
}


- (void)setCacheDirectory:(NSString *)directoryPath forSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
		[sourceCacheDirectories setObject:directoryPath forKey:[NSValue valueWithPointer:imageSource]];
	[cacheLock unlock];
}


- (NSString *)cachePathForSourceImage:(MacOSaiXSourceImage *)sourceImage
{
	[cacheLock lock];
		NSValue			*imageSourceKey = [NSValue valueWithPointer:[sourceImage source]];
		NSString		*diskCachePath = [[[sourceCacheDirectories objectForKey:imageSourceKey] retain] autorelease];
		NSMutableString	*escapedIdentifier = [NSMutableString stringWithString:[sourceImage identifier]];
		[escapedIdentifier replaceOccurrencesOfString:@"/" 
										   withString:@"#slash#" 
											  options:NSLiteralSearch 
												range:NSMakeRange(0, [escapedIdentifier length])];
	[cacheLock unlock];
	
	return [[diskCachePath stringByAppendingPathComponent:escapedIdentifier]
						   stringByAppendingPathExtension:@"tiff"];
}


- (void)cacheSourceImage:(MacOSaiXSourceImage *)sourceImage 
{
	// Cache the image in memory for efficient retrieval, if it's not already in the cache.
	
	NSString			*imageKey = [sourceImage key];
	
	[cacheLock lock];
		if (![nativeImageSizeDict objectForKey:imageKey])
		{
			MacOSaiXBitmapImageRep	*reasonablyFullSizedBitmapRep = [[sourceImage image] reasonablyFullSizedBitmapRep];
			[reasonablyFullSizedBitmapRep setSourceImage:sourceImage];
			[reasonablyFullSizedBitmapRep imageRepWasAccessed];
			
			[self addImageRep:reasonablyFullSizedBitmapRep toMemoryCacheForKey:imageKey];
			[nativeImageSizeDict setObject:[NSValue valueWithSize:[[sourceImage image] size]] forKey:imageKey];
			
			if (![[sourceImage source] canRefetchImages])
			{
					// Cache the image to disk in case it gets requested after being flushed from the memory cache.
				NSString	*imagePath = [self cachePathForSourceImage:sourceImage];
				if (imagePath)
					[[[sourceImage image] TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0] writeToFile:imagePath atomically:NO];
			}
		}
	[cacheLock unlock];
	
	[sourceImage setImage:nil];
}


- (NSSize)nativeSizeOfSourceImage:(MacOSaiXSourceImage *)sourceImage
{
	[cacheLock lock];
		NSValue		*sizeValue = [nativeImageSizeDict objectForKey:[sourceImage key]];
	[cacheLock unlock];
	
	if (sizeValue)
		return [sizeValue sizeValue];
	else
		return NSZeroSize;	// the size is unknown
}


- (MacOSaiXBitmapImageRep *)imageRep:(NSImageRep *)imageRep atSize:(NSSize)requestedSize 
{
	// Create a bitmap rep at the requested size that is completely filled by the image rep.  If the requested size has a different aspect ratio than the image rep then the image rep will be centered in the new bitmap and the extra pixels above and below or to the left and right will be clipped.
	
	MacOSaiXBitmapImageRep	*scaledRep = nil;
	
	if (!pthread_main_np())
	{
		NSMutableDictionary	*parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												imageRep, @"Image Rep", 
												[NSValue valueWithSize:requestedSize], @"Size", 
												nil];
		[self performSelectorOnMainThread:@selector(imageRepAtSize:) withObject:parameters waitUntilDone:YES];
		scaledRep = [parameters objectForKey:@"Scaled Rep"];
	}
	else
	{
			// Calculate the rect in which to draw the image rep.
		NSRect				scaledRect;
		if (([imageRep pixelsWide] / requestedSize.width) < ([imageRep pixelsHigh] / requestedSize.height))
		{
			float	scaledHeight = [imageRep pixelsHigh] * requestedSize.width / [imageRep pixelsWide];
			scaledRect = NSMakeRect(0.0, (requestedSize.height - scaledHeight) / 2.0, requestedSize.width, scaledHeight);
		}
		else
		{
			float	scaledWidth = [imageRep pixelsWide] * requestedSize.height / [imageRep pixelsHigh];
			scaledRect = NSMakeRect((requestedSize.width - scaledWidth) / 2.0, 0.0, scaledWidth, requestedSize.height);
		}
		
			// Create the scaled bitmap rep.
		NSImage				*scaledImage = [[NSImage alloc] initWithSize:requestedSize];
//		[scaledImage setCacheMode:NSImageCacheNever];
//		[scaledImage setCachedSeparately:YES];
		
		NS_DURING
			[scaledImage lockFocus];
			
			[[NSColor clearColor] set];
			NSRectFill(scaledRect);
			
			NS_DURING
				[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
				NSImage				*image = [[NSImage alloc] initWithSize:[imageRep size]];
				[image addRepresentation:imageRep];
				[image drawInRect:scaledRect 
						 fromRect:NSZeroRect 
						operation:NSCompositeSourceOver 
						 fraction:1.0];
				[image release];
				image = nil;
			NS_HANDLER
				#ifdef DEBUG
					NSLog(@"Could not scale an image to (%f, %f)", requestedSize.width, requestedSize.height);
				#endif
			NS_ENDHANDLER
			
			[scaledImage unlockFocus];
		NS_HANDLER
			#ifdef DEBUG
				NSLog(@"Could not lock focus on an image to scale it to (%f, %f)", requestedSize.width, requestedSize.height);
			#endif
		NS_ENDHANDLER
		
		NSData				*tiffData = [scaledImage TIFFRepresentation];
		scaledRep = [[[MacOSaiXBitmapImageRep alloc] initWithData:tiffData] autorelease];
		[scaledRep setProperty:NSImageColorSyncProfileData withValue:nil];	// free up ~4K of unused data
		[scaledImage release];
	}
	
	return scaledRep;
}


- (void)imageRepAtSize:(NSMutableDictionary *)parameters 
{
	MacOSaiXBitmapImageRep	*scaledRep = [self imageRep:[parameters objectForKey:@"Image Rep"] atSize:[[parameters objectForKey:@"Size"] sizeValue]];
	
	if (scaledRep)
		[parameters setObject:scaledRep forKey:@"Scaled Rep"];
}


- (NSBitmapImageRep *)imageRepAtSize:(NSSize)requestedSize forSourceImage:(MacOSaiXSourceImage *)sourceImage
{
	MacOSaiXBitmapImageRep	*imageRep = nil,
							*scalableRep = nil;
	NSString				*imageKey = [sourceImage key];

	requestedSize = NSMakeSize(round(requestedSize.width), round(requestedSize.height));
	
	[cacheLock lock];
	{
		NSValue			*nativeSizeValue = [nativeImageSizeDict objectForKey:imageKey];
		
		if (nativeSizeValue)
		{
				// There is at least one rep cached for this image.  Calculate the size that is just small enough to enclose the requested size.
			NSSize					nativeSize = [nativeSizeValue sizeValue];
			
			if (NSEqualSizes(requestedSize, NSZeroSize))
				requestedSize = nativeSize;
			
				// Check if there is a cached image rep we can use.
			NSArray					*cachedReps = [memoryCache objectForKey:imageKey];
			int						index, count = [cachedReps count];
			for (index = 0; index < count; index++)
			{
				MacOSaiXBitmapImageRep	*cachedRep = [cachedReps objectAtIndex:index];
				NSSize					cachedRepSize = NSMakeSize([cachedRep pixelsWide], [cachedRep pixelsHigh]);
				
				if (NSEqualSizes(cachedRepSize, requestedSize))
				{
						// Found an exact size match.  Perfect cache hit.
					perfectHitCount++;
					imageRep = cachedRep;
					break;
				}
				else if (NSEqualSizes(cachedRepSize, nativeSize) || (!NSEqualSizes(requestedSize, NSZeroSize) && cachedRepSize.width > requestedSize.width * 1.5 && cachedRepSize.height > requestedSize.height * 1.5))
					scalableRep = cachedRep;	// this is the original or it is big enough to scale down from.
			}
		}
	}
	[cacheLock unlock];
		
	if (!imageRep && scalableRep)
	{
			// Scale and crop a copy of the closest rep to the desired size.
		scalableHitCount++;
		
		imageRep = [self imageRep:scalableRep atSize:requestedSize];
		
		[scalableRep imageRepWasAccessed];
		
		if (imageRep)
		{
			[imageRep setSourceImage:sourceImage];
			[self addImageRep:imageRep toMemoryCacheForKey:imageKey];
		}
	}
	
	if (!imageRep)
	{
			// There is no rep we can use in the memory cache.
		missCount++;
//		NSLog(@"Cache miss rate: %.3f%%", missCount * 100.0 / (perfectHitCount + scalableHitCount + missCount));
		
			// Re-request the image from the source or pull it from the source's disk cache.
		NSImage		*image = nil;
		if ([[sourceImage source] canRefetchImages])
		{
				// Temporarily unlock the cache while the image is loading.
			NS_DURING
				image = [[sourceImage source] imageForIdentifier:[sourceImage identifier]];
			NS_HANDLER
				#ifdef DEBUG
					[localException raise];
				#else
					image = nil;
				#endif
			NS_ENDHANDLER
		}
		else
		{
			NSString	*imagePath = [self cachePathForSourceImage:sourceImage];
			if (imagePath)
			{
					// Temporarily unlock the cache while the image is loading.
				image = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
				
				#ifdef DEBUG
					NSAssert(image, @"Crap!  Lost an image!");
				#endif
			}
		}
		
		if ([image isValid])
		{
				// Ignore whatever DPI was set for the image.  We just care about the bitmap's pixel size.
			NSImageRep	*originalRep = [[image representations] objectAtIndex:0];
			NSSize		bitmapSize = NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh]);
			[originalRep setSize:bitmapSize];
			[image setSize:bitmapSize];
			
			[sourceImage setImage:image];
			
				// Cache the image at it's native size or at least a reasonably large size.
			[self cacheSourceImage:sourceImage];
			
				// Scale the full sized rep to the requested size and cache it.
				// A size of NSZeroSize means we should return a rep at the image's native size.
			BOOL		fullSizeRequested = NSEqualSizes(requestedSize, NSZeroSize);
			if (fullSizeRequested)
				requestedSize = bitmapSize;
			imageRep = [self imageRep:originalRep atSize:requestedSize];
			if (imageRep)
			{
				[imageRep setSourceImage:sourceImage];
				if (!fullSizeRequested)
					[self addImageRep:imageRep toMemoryCacheForKey:[sourceImage key]];
			}
		}
		else
		{
			#ifdef DEBUG
				NSLog(@"Invalid image retrieved for %@", sourceImage);
			#endif
		}
	}
	
	[imageRep imageRepWasAccessed];
	
	return (NSBitmapImageRep *)[[imageRep retain] autorelease];
}


- (void)removeSourceImage:(MacOSaiXSourceImage *)sourceImage
{
	[cacheLock lock];
		NSString	*imagePath = [self cachePathForSourceImage:sourceImage];
		[[NSFileManager defaultManager] removeFileAtPath:imagePath handler:nil];
		
		// TBD: also remove from in-memory cache?
	[cacheLock unlock];
}


- (void)removeCachedImagesFromSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
			// Remove the entries from the keyed cache.
		NSEnumerator	*keyEnumerator = [[memoryCache allKeys] objectEnumerator];
		NSString		*key = nil;
		while (key = [keyEnumerator nextObject])
			if ([self imageSourceFromKey:key] == imageSource)
			{
				[memoryCache removeObjectForKey:key];
				[nativeImageSizeDict removeObjectForKey:key];
			}
		
			// Remove the entries from the flattened cache.
		unsigned long	imageRepCount = [flatImageRepCache count],
						indexesToRemove[imageRepCount], 
						indexesToRemoveCount = 0, 
						index;
		for (index = 0; index < imageRepCount; index++)
		{
			MacOSaiXBitmapImageRep	*imageRep = [flatImageRepCache objectAtIndex:index];
			if ([[imageRep sourceImage] source] == imageSource)
			{
				indexesToRemove[indexesToRemoveCount++] = index;
				currentMemoryCacheSize -= [imageRep bytesPerRow] * [imageRep pixelsHigh];
			}
		}
		[flatImageRepCache removeObjectsFromIndices:indexesToRemove numIndices:indexesToRemoveCount];
		
			// Remove the cache directory entry.
		[sourceCacheDirectories removeObjectForKey:[NSValue valueWithPointer:imageSource]];
	[cacheLock unlock];
}


- (NSString *)xmlDataWithImageSources:(NSArray *)imageSources
{
		// Yuck...
	NSMutableString	*xmlData = [NSMutableString stringWithString:@"<CACHED_IMAGES>\n"];
	NSEnumerator	*keyEnumerator = [diskCache keyEnumerator];
	NSString		*key = nil;
	
	while (key = [keyEnumerator nextObject])
	{
		id<MacOSaiXImageSource>	imageSource = [self imageSourceFromKey:key];
		int						imageSourceIndex = [imageSources indexOfObjectIdenticalTo:imageSource];
		[xmlData appendString:[NSString stringWithFormat:@"\t<CACHED_IMAGE SOURCE_ID=\"%d\" IMAGE_ID=\"%@\" FILE_ID=\"%@\">\n", 
														 imageSourceIndex, 
														 [self imageIdentifierFromKey:key], 
														 [diskCache objectForKey:key]]];
	}
	[xmlData appendString:@"</CACHED_IMAGES>\n\n"];
	
	return xmlData;
}


- (unsigned long long)currentMemoryCacheSize
{
	return currentMemoryCacheSize;
}


#pragma mark


- (void)dealloc
{
	[cachedImagesPath release];
	[cacheLock release];
	[diskCache release];
	[memoryCache release];
	[flatImageRepCache release];
	
    [super dealloc];
}

@end

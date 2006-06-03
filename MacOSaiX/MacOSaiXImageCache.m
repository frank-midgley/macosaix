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
		imageKeyRecencyArray = [[NSMutableArray array] retain];
		
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


- (id)keyWithImageSource:(id<MacOSaiXImageSource>)imageSource identifier:(NSString *)imageIdentifier
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
				[NSValue valueWithPointer:imageSource], @"Image Source Pointer", 
				imageIdentifier, @"Image Identifier", 
				nil];
//	return [NSString stringWithFormat:@"%p\t%@", imageSource, imageIdentifier];
}


- (id<MacOSaiXImageSource>)imageSourceFromKey:(id)key
{
	void			*imageSourcePtr = 0;

	imageSourcePtr = [[(NSDictionary *)key objectForKey:@"Image Source Pointer"] pointerValue];
//	sscanf([(NSString *)key UTF8String], "%p\t", &imageSourcePtr);
	
	return (id<MacOSaiXImageSource>)imageSourcePtr;
}


- (NSString *)imageIdentifierFromKey:(id)key
{
	return [(NSDictionary *)key objectForKey:@"Image Identifier"];
	
//	unsigned int	tabPos = [key rangeOfString:@"\t"].location;
//	
//	return [(NSString *)key substringFromIndex:tabPos + 1];
}


- (void)addImageRep:(NSBitmapImageRep *)imageRep toMemoryCacheForKey:(NSString *)imageKey
{
		// Remove the least recently accessed image rep from the memory cache until we have
		// enough room to store the new rep.
	unsigned long long	imageRepSize = [imageRep bytesPerRow] * [imageRep pixelsHigh];
	while ([memoryCache count] > 0 && (currentMemoryCacheSize + imageRepSize) > maxMemoryCacheSize)
	{
		NSString			*oldestKey = [imageKeyRecencyArray lastObject];
		NSBitmapImageRep	*oldestRep = [imageRepRecencyArray lastObject];
		unsigned long long	oldestRepSize = [oldestRep bytesPerRow] * [oldestRep pixelsHigh];
		NSMutableArray		*oldestRepArray = [memoryCache objectForKey:oldestKey];
		
		[oldestRepArray removeObjectIdenticalTo:oldestRep];
		if ([oldestRepArray count] == 0)
		{
			[memoryCache removeObjectForKey:oldestKey];
			if (![oldestKey isEqualToString:imageKey])
				[nativeImageSizeDict removeObjectForKey:oldestKey];
		}
		
		[imageKeyRecencyArray removeLastObject];
		[imageRepRecencyArray removeLastObject];
		
		currentMemoryCacheSize -= oldestRepSize;
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
	[imageRepRecencyArray insertObject:imageRep atIndex:0];
	[imageKeyRecencyArray insertObject:imageKey atIndex:0];
	
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
		id					imageKey = [self keyWithImageSource:imageSource identifier:imageIdentifier];
			
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
		[self addImageRep:fullSizeRep toMemoryCacheForKey:imageKey];
		[nativeImageSizeDict setObject:[NSValue valueWithSize:[fullSizeRep size]] forKey:imageKey];
		
		if (![imageSource canRefetchImages])
		{
			NSString	*imagePath = [self cachePathForIdentifier:imageIdentifier forSource:imageSource];
			if (imagePath)
				[[image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0] 
											   writeToFile:imagePath atomically:NO];
		}
	[cacheLock unlock];
}


- (NSSize)nativeSizeOfImageWithIdentifier:(NSString *)imageIdentifier 
							   fromSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
		NSValue		*sizeValue = [nativeImageSizeDict objectForKey:[self keyWithImageSource:imageSource identifier:imageIdentifier]];
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
	id					imageKey = [self keyWithImageSource:imageSource identifier:imageIdentifier];

	size = NSMakeSize(roundf(size.width), roundf(size.height));
	
	[cacheLock lock];
		NSValue			*nativeSizeValue = [nativeImageSizeDict objectForKey:imageKey];
//		NSSize			repSize = NSZeroSize;
		
		if (nativeSizeValue)
		{
				// There is at least one rep cached for this image.  Calculate the size that is 
				// just small enough to enclose the requested size.
			NSSize			nativeSize = [nativeSizeValue sizeValue];
//			if (size.width / nativeSize.width < size.height / nativeSize.height)
//				repSize = NSMakeSize(size.height * nativeSize.width / nativeSize.height, size.height);
//			else
//				repSize = NSMakeSize(size.width, size.width * nativeSize.height / nativeSize.width);
//			
//			repSize.width = (int)(repSize.width + 0.5);
//			repSize.height = (int)(repSize.height + 0.5);
			
				// Check if there is a cached image rep we can use.
			NSEnumerator		*cachedRepEnumerator = [[memoryCache objectForKey:imageKey] objectEnumerator];
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
						[imageKeyRecencyArray removeObjectAtIndex:index];
					}
					[imageRepRecencyArray insertObject:imageRep atIndex:0];
					[imageKeyRecencyArray insertObject:imageKey atIndex:0];
					break;
				}
				else if (NSEqualSizes(cachedRepSize, nativeSize))
					scalableRep = cachedRep;	// this is the original, OK to scale from it
//				else if (repSize.width <= nativeSize.width &&	// not looking for a rep bigger than the original image and...
//						 cachedRepSize.width >= repSize.width * 2.0 &&	// the cached rep is big enough to scale down and...
//						 (!scalableRep || [scalableRep size].width > cachedRepSize.width))	// there was no previous match or the
//																							// previous match was larger then...
//					scalableRep = cachedRep;	// we can scale this rep to the size we need.  Partial cache hit.
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
				[self addImageRep:imageRep toMemoryCacheForKey:imageKey];
		}
		
		if (!imageRep)
		{
				// There is no rep we can use in the memory cache.
			missCount++;
//			NSLog(@"Cache miss rate: %.3f%%", missCount * 100.0 / (perfectHitCount + scalableHitCount + missCount));
			
				// Re-request the image from the source or pull it from the source's disk cache.
			NSImage		*image = nil;
			if ([imageSource canRefetchImages])
				image = [imageSource imageForIdentifier:imageIdentifier];
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
				NSLog(@"Invalid image retrieved for %@", imageKey);
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
			NSString	*imagePath = [self cachePathForIdentifier:identifier forSource:imageSource];
			[[NSFileManager defaultManager] removeFileAtPath:imagePath handler:nil];
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
	NSArray				*cacheKeys = nil;
	
	[cacheLock lock];
		cacheKeys = [NSArray arrayWithArray:[memoryCache allKeys]];
		[sourceCacheDirectories removeObjectForKey:[NSValue valueWithPointer:imageSource]];
	[cacheLock unlock];
	
	NSEnumerator	*keyEnumerator = [cacheKeys objectEnumerator];
	NSString		*key = nil;
	while (key = [keyEnumerator nextObject])
		if ([self imageSourceFromKey:key] == imageSource)
		{
			[cacheLock lock];
				[memoryCache removeObjectForKey:key];
				[nativeImageSizeDict removeObjectForKey:key];
				
				unsigned	keyIndex = [imageKeyRecencyArray indexOfObject:key];
				
				while (keyIndex != NSNotFound)
				{
					[imageKeyRecencyArray removeObjectAtIndex:keyIndex];
					[imageRepRecencyArray removeObjectAtIndex:keyIndex];
					
					keyIndex = [imageKeyRecencyArray indexOfObject:key];
				}
			[cacheLock unlock];
		}
			
	[pool release];
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


#pragma mark


- (void)dealloc
{
	[cachedImagesPath release];
	[cacheLock release];
	[diskCache release];
	[memoryCache release];
	[imageRepRecencyArray release];
	[imageKeyRecencyArray release];
    [scalingWindow close];
	[scalingWindow release];
	
    [super dealloc];
}

@end

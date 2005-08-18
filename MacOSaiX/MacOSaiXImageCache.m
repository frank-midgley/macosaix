/*
	MacOSaiXImageCache.m
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import "MacOSaiXImageCache.h"
#import <unistd.h>
#import <malloc/malloc.h>


    // The number of cached images that will be held in memory at any one time.
#define MAX_MEMORY_CACHE_SIZE 200*1024*1024


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
		NSString	*tempPathTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"MacOSaiX Cached Images XXXXXX"];
		char		*tempPath = mkdtemp((char *)[tempPathTemplate fileSystemRepresentation]);
		
		if (tempPath)
		{
			cachedImagesPath = [[NSString stringWithCString:tempPath] retain];
			cacheLock = [[NSRecursiveLock alloc] init];
			diskCache = [[NSMutableDictionary dictionary] retain];
			memoryCache = [[NSMutableDictionary dictionary] retain];
			nativeImageSizeDict = [[NSMutableDictionary dictionary] retain];
			
			imageRepRecencyArray = [[NSMutableArray array] retain];
			imageKeyRecencyArray = [[NSMutableArray array] retain];
		}
		else
		{
			[self autorelease];
			self = nil;
		}
	}
	
    return self;
}


- (NSString *)filePathForCachedImageID:(long)imageID
{
	return [cachedImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Image %u.jpg", imageID]];
}


- (NSString *)keyWithImageSource:(id<MacOSaiXImageSource>)imageSource identifier:(NSString *)imageIdentifier
{
	return [NSString stringWithFormat:@"%p\t%@", imageSource, imageIdentifier];
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


- (void)addImageRep:(NSBitmapImageRep *)imageRep toMemoryCacheForKey:(NSString *)imageKey
{
		// Remove the least recently accessed image rep from the memory cache until we have
		// enough room to store the new rep.
	size_t	imageRepSize = malloc_size((void *)[imageRep bitmapData]);
	while ([memoryCache count] > 0 && ((memoryCacheSize + imageRepSize) > MAX_MEMORY_CACHE_SIZE || [imageKeyRecencyArray count] > 256))
	{
		NSString			*oldestKey = [imageKeyRecencyArray lastObject];
		NSBitmapImageRep	*oldestRep = [imageRepRecencyArray lastObject];
		unsigned long long	oldestRepSize = malloc_size([oldestRep bitmapData]);
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
		
		memoryCacheSize -= oldestRepSize;
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
	memoryCacheSize += imageRepSize;
	
		// Remember how recently we last saw this rep.
		// The newest items are closer to index 0.
	[imageRepRecencyArray insertObject:imageRep atIndex:0];
	[imageKeyRecencyArray insertObject:imageKey atIndex:0];
	
//	NSLog(@"%d image reps in cache", [imageRepRecencyArray count]);
}


- (NSString *)cacheImage:(NSImage *)image 
		  withIdentifier:(NSString *)imageIdentifier 
			  fromSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
		NSString		*imageKey = nil;
		
		if ([imageIdentifier length] == 0)
		{
				// This image source cannot refetch images.  Create a unique identifier 
				// within the context of our document and store the image to disk.
			unsigned long	uniqueID = cachedImageCount++;
			
			imageIdentifier = [NSString stringWithFormat:@"%u", uniqueID];
			imageKey = [self keyWithImageSource:imageSource identifier:imageIdentifier];
			[[image TIFFRepresentation] writeToFile:[self filePathForCachedImageID:uniqueID] atomically:NO];
			[diskCache setObject:[NSNumber numberWithLong:uniqueID] forKey:imageKey];
		}
		else
			imageKey = [self keyWithImageSource:imageSource identifier:imageIdentifier];
			
			// Get a bitmap image rep at the full size of the image.
		NSBitmapImageRep	*fullSizeRep = nil;
		
		while (!fullSizeRep)
		{
			NS_DURING
				[image lockFocus];
					NSImageRep	*originalRep = [[image representations] objectAtIndex:0];
					NSRect		imageRect = NSMakeRect(0.0, 0.0, [originalRep pixelsWide], [originalRep pixelsHigh]);
					fullSizeRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:imageRect] autorelease];
				[image unlockFocus];
			NS_HANDLER
				NSLog(@"Failed to lock focus on %@", imageIdentifier);
			NS_ENDHANDLER
		}

			// Cache the image in memory for efficient retrieval.
		[self addImageRep:fullSizeRep toMemoryCacheForKey:imageKey];
//		NSLog(@"Native size of %@ is %f by %f", imageIdentifier, [fullSizeRep size].width, [fullSizeRep size].height);
		[nativeImageSizeDict setObject:[NSValue valueWithSize:[fullSizeRep size]] forKey:imageKey];
		
	[cacheLock unlock];
	
	return imageIdentifier;
}


- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size 
					   forIdentifier:(NSString *)imageIdentifier 
						  fromSource:(id<MacOSaiXImageSource>)imageSource
{
	NSBitmapImageRep	*imageRep = nil,
						*scalableRep = nil;
	NSString			*imageKey = [self keyWithImageSource:imageSource identifier:imageIdentifier];

	[cacheLock lock];
		NSValue			*nativeSizeValue = [nativeImageSizeDict objectForKey:imageKey];
		NSSize			repSize = NSZeroSize;
		
		if (nativeSizeValue)
		{
				// There is at least one rep cached for this image.  Calculate the size that is 
				// just small enough to enclose the requested size.
			NSSize			nativeSize = [nativeSizeValue sizeValue];
			if (size.width / nativeSize.width < size.height / nativeSize.height)
				repSize = NSMakeSize(size.height * nativeSize.width / nativeSize.height, size.height);
			else
				repSize = NSMakeSize(size.width, size.width * nativeSize.height / nativeSize.width);
			
			repSize.width = (int)(repSize.width + 0.5);
			repSize.height = (int)(repSize.height + 0.5);
			
				// Check if there is a cached image rep we can use.
			NSEnumerator		*cachedRepEnumerator = [[memoryCache objectForKey:imageKey] objectEnumerator];
			NSBitmapImageRep	*cachedRep = nil;
			while (cachedRep = [cachedRepEnumerator nextObject])
			{
				NSSize	cachedRepSize = [cachedRep size];
				
				if (NSEqualSizes(cachedRepSize, repSize))
				{
						// Found an exact size match.  Perfect cache hit.
					perfectHitCount++;
					imageRep = cachedRep;
					break;
				}
				else if (NSEqualSizes(cachedRepSize, nativeSize))
					scalableRep = cachedRep;	// this is the original, OK to scale from it
				else if (repSize.width <= nativeSize.width &&	// not looking for a rep bigger than the original image and...
						 cachedRepSize.width >= repSize.width * 2.0 &&	// the cached rep is big enough to scale down and...
						 (!scalableRep || [scalableRep size].width > cachedRepSize.width))	// there was no previous match or the
																							// previous match was larger then...
					scalableRep = cachedRep;	// we can scale this rep to the size we need.  Partial cache hit.
			}
		}
		
		if (imageRep)
        {
				// There was an exact match in the cache.
				// Remove the image from its current position in the memory cache.
				// It will be added at the head of the queue below.
			int index = [imageKeyRecencyArray indexOfObjectIdenticalTo:imageKey];
			if (index != NSNotFound)
			{
				[imageKeyRecencyArray removeObjectAtIndex:index];
				[imageRepRecencyArray removeObjectAtIndex:index];
			}
		}
		else if (scalableRep)
		{
				// Scale a copy of the closest rep to the desired size.
			scalableHitCount++;
			NSImage		*scaledImage = [[NSImage alloc] initWithSize:repSize];
			NSRect		scaledRect = NSMakeRect(0.0, 0.0, repSize.width, repSize.height);
			[scaledImage setCachedSeparately:YES];
			[scaledImage setCacheMode:NSImageCacheNever];
			do
			{
				NS_DURING
					[scaledImage lockFocus];
						[scalableRep drawInRect:NSMakeRect(0.0, 0.0, repSize.width, repSize.height)];
						imageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:scaledRect] autorelease];
					[scaledImage unlockFocus];
				NS_HANDLER
					NSLog(@"Could not lock focus on image to scale.");
				NS_ENDHANDLER
			} while (!imageRep);
			[scaledImage release];
			[self addImageRep:imageRep toMemoryCacheForKey:imageKey];
		}
		
		if (!imageRep)
		{
				// There is no rep we can use in the memory cache.
				// See if we have the image in our disk cache, otherwise re-request it from the source.
			missCount++;
//			NSLog(@"Cache miss rate: %.3f%%", missCount * 100.0 / (perfectHitCount + scalableHitCount + missCount));
			
			NSImage		*image = nil;
			NSNumber	*imageID = [diskCache objectForKey:imageKey];
			if (imageID)
				image = [[[NSImage alloc] initWithContentsOfFile:[self filePathForCachedImageID:[imageID unsignedLongValue]]] autorelease];
            else
			{
					// This image is not in the disk cache so get the image from its source.
//				NSLog(@"Requesting %@ from %@@%p", imageIdentifier, [imageSource class], imageSource);
				if (imageSource)
					image = [imageSource imageForIdentifier:imageIdentifier];
				else
					image = [[[NSImage alloc] initWithContentsOfFile:imageIdentifier] autorelease];
			}
			
            if ([image isValid])
			{
				[image setCachedSeparately:YES];
				[image setCacheMode:NSImageCacheNever];
				
					// Ignore whatever DPI was set for the image.  We just care about the bitmap.
				NSImageRep	*originalRep = [[image representations] objectAtIndex:0];
				[originalRep setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
				[image setSize:NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh])];
				
				[self cacheImage:image withIdentifier:imageIdentifier fromSource:imageSource];
				
					// Now that the image is cached again get a rep at the desired size.
				imageRep = [self imageRepAtSize:size forIdentifier:imageIdentifier fromSource:imageSource];
			}
			else
				NSLog(@"Invalid image retrieved for %@", imageKey);
		}
	[cacheLock unlock];
	
	return imageRep;
}


- (void)removeCachedImageRepsFromSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
		NSEnumerator	*keyEnumerator = [memoryCache keyEnumerator];
		NSString		*key = nil;
		while (key = [keyEnumerator nextObject])
			if ([self imageSourceFromKey:key] == imageSource)
			{
				[memoryCache removeObjectForKey:key];
				[nativeImageSizeDict removeObjectForKey:key];
				
				unsigned	keyIndex = [imageKeyRecencyArray indexOfObjectIdenticalTo:key];
				
				if (keyIndex != NSNotFound)
				{
					[imageKeyRecencyArray removeObjectAtIndex:keyIndex];
					[imageRepRecencyArray removeObjectAtIndex:keyIndex];
				}
			}
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


#pragma mark


- (void)dealloc
{
	[cachedImagesPath release];
	[cacheLock release];
	[diskCache release];
	[memoryCache release];
	[imageRepRecencyArray release];
	[imageKeyRecencyArray release];
    
    [super dealloc];
}

@end

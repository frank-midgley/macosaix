/*
	MacOSaiXImageCache.m
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import "MacOSaiXImageCache.h"
#import <unistd.h>
#import <malloc/malloc.h>


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
			
			maxMemoryCacheSize = NSRealMemoryAvailable() / 3;
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
	NSString			*imageKey = [self keyWithImageSource:imageSource identifier:imageIdentifier];

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
			NSImage		*scaledImage = [[NSImage alloc] initWithSize:size];
			[scaledImage setCachedSeparately:YES];
			[scaledImage setCacheMode:NSImageCacheNever];
			
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
			
			[[NSGraphicsContext currentContext] saveGraphicsState];
			[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
			do
			{
				NS_DURING
					[scaledImage lockFocus];
						[scalableRep drawInRect:scaledRect];
						imageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, size.width, size.height)] autorelease];
					[scaledImage unlockFocus];
				NS_HANDLER
					NSLog(@"Could not lock focus on image to scale.");
				NS_ENDHANDLER
			} while (!imageRep);
			[[NSGraphicsContext currentContext] restoreGraphicsState];
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
				image = [imageSource imageForIdentifier:imageIdentifier];
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


- (void)removeCachedImageRepsFromSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
		NSEnumerator	*keyEnumerator = [[memoryCache allKeys] objectEnumerator];
		NSString		*key = nil;
		while (key = [keyEnumerator nextObject])
			if ([self imageSourceFromKey:key] == imageSource)
			{
				[memoryCache removeObjectForKey:key];
				[nativeImageSizeDict removeObjectForKey:key];
				
				unsigned	keyIndex = [imageKeyRecencyArray indexOfObject:key];
				
				while (keyIndex != NSNotFound)
				{
					[imageKeyRecencyArray removeObjectAtIndex:keyIndex];
					[imageRepRecencyArray removeObjectAtIndex:keyIndex];
					
					keyIndex = [imageKeyRecencyArray indexOfObject:key];
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

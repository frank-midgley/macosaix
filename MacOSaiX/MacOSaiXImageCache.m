/*
	MacOSaiXImageCache.m
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import "MacOSaiXImageCache.h"
#import <unistd.h>


    // The number of cached images that will be held in memory at any one time.
#define IMAGE_CACHE_MAX_COUNT 100


@implementation MacOSaiXImageCache


- (id)init
{
    if (self = [super init])
    {
		NSString	*tempPathTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"MacOSaiX Cached Images XXXXXX"];
		char		*tempPath = mkdtemp((char *)[tempPathTemplate fileSystemRepresentation]);
		
		if (tempPath)
		{
			cachedImagesPath = [[NSString stringWithCString:tempPath] retain];
			cacheLock = [[NSLock alloc] init];
			imageCache = [[NSMutableDictionary dictionary] retain];
			
			orderedCache = [[NSMutableArray array] retain];
			orderedCacheID = [[NSMutableArray array] retain];
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


- (NSMutableDictionary *)cacheDictionaryForImageSource:(id<MacOSaiXImageSource>)imageSource
{
	if (!cachedImagesDictionary)
		cachedImagesDictionary = [[NSMutableDictionary dictionary] retain];
	
		// locking?
	NSNumber			*sourceKey = [NSNumber numberWithUnsignedLong:(unsigned long)imageSource];
	NSMutableDictionary *sourceDict = [cachedImagesDictionary objectForKey:sourceKey];
	
	if (!sourceDict)
	{
		sourceDict = [NSMutableDictionary dictionary];
		[cachedImagesDictionary setObject:sourceDict forKey:sourceKey];
	}
	
	return sourceDict;
}


- (NSString *)cacheImage:(NSImage *)image 
		  withIdentifier:(NSString *)imageIdentifier 
			  fromSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
		unsigned long	uniqueID = cachedImageCount++;
		
		if ([imageIdentifier length] == 0)
		{
				// This image source cannot refetch images.  Create a unique identifier 
				// within the context of our document and store the image to disk.
			imageIdentifier = [NSString stringWithFormat:@"%u", uniqueID];
			[[image TIFFRepresentation] writeToFile:[self filePathForCachedImageID:uniqueID] atomically:NO];
		}
		
		NSMutableDictionary	*imageSourceCache = [self cacheDictionaryForImageSource:imageSource];
		
			// Associate the ID with the image source/image identifier combo
		[imageSourceCache setObject:[NSNumber numberWithLong:uniqueID] forKey:imageIdentifier];
		
			// Cache the image for efficient retrieval.
		[imageCache setObject:image forKey:[NSNumber numberWithLong:uniqueID]];
		[orderedCache insertObject:image atIndex:0];
		[orderedCacheID insertObject:[NSNumber numberWithLong:uniqueID] atIndex:0];
		if ([orderedCache count] > IMAGE_CACHE_MAX_COUNT)
		{
			[imageCache removeObjectForKey:[orderedCacheID lastObject]];
			[orderedCache removeLastObject];
			[orderedCacheID removeLastObject];
		}
	[cacheLock unlock];
	
	return imageIdentifier;
}


- (NSImage *)imageForIdentifier:(NSString *)imageIdentifier fromSource:(id<MacOSaiXImageSource>)imageSource
{
	NSImage		*image = nil;
	
	[cacheLock lock];
		long		imageID = [[[self cacheDictionaryForImageSource:imageSource] objectForKey:imageIdentifier] longValue];
		NSNumber	*imageKey = [NSNumber numberWithLong:imageID];
		
			// First see if we have this image in memory already.
		image = [imageCache objectForKey:imageKey];
		if (image)
        {
				// Remove the image from its current position in the memory cache.
				// It will be added at the head of the queue below.
			int index = [orderedCache indexOfObjectIdenticalTo:image];
            if (index != NSNotFound)
            {
                [orderedCache removeObjectAtIndex:index];
                [orderedCacheID removeObjectAtIndex:index];
            }
        }
		else
		{
				// See if we have the image in our disk cache.
			image = [[[NSImage alloc] initWithContentsOfFile:[self filePathForCachedImageID:imageID]] autorelease];
            if (!image) // TODO: && [imageSource canRefetchImages] ?
			{
					// We don't have this image cached so re-request the image from the source.
				NSLog(@"Re-requesting %@ from source", imageIdentifier);
				image = [imageSource imageForIdentifier:imageIdentifier];
			}
			
            if (image)
			{
					// Disable caching to avoid deadlocks.  Hopefully this won't be necessary in a future OS...
				[image setCacheMode:NSImageCacheNever];
				
					// Add the image to the in-memory cache.
				[imageCache setObject:image forKey:imageKey];
			}
		}
		
		if (image)
		{
				// Add this image at the front of the in-memory cache.
			[orderedCache insertObject:image atIndex:0];
			[orderedCacheID insertObject:[NSNumber numberWithLong:imageID] atIndex:0];
			
				// Prune the in-memory cache if it has gotten too large.
			if ([orderedCache count] > IMAGE_CACHE_MAX_COUNT)
			{
				[imageCache removeObjectForKey:[orderedCacheID lastObject]];
				[orderedCache removeLastObject];
				[orderedCacheID removeLastObject];
			}
		}
	[cacheLock unlock];
	
	return image;
}


- (NSString *)xmlData
{
		// Yuck...
	NSMutableString	*xmlData = [NSMutableString stringWithString:@"<CACHED_IMAGES>\n"];
	NSEnumerator	*sourceEnumerator = [cachedImagesDictionary keyEnumerator];
	NSNumber		*imageSourceAddress = nil;
	
	while (imageSourceAddress = [sourceEnumerator nextObject])
	{
		id<MacOSaiXImageSource>	imageSource = (void *)[imageSourceAddress unsignedLongValue];
		NSDictionary			*cacheDict = [self cacheDictionaryForImageSource:imageSource];
		NSEnumerator			*imageIDEnumerator = [cacheDict keyEnumerator];
		NSString				*imageID = nil;
		while (imageID = [imageIDEnumerator nextObject])
			[xmlData appendString:[NSString stringWithFormat:@"\t<CACHED_IMAGE SOURCE_ID=\"%d\" IMAGE_ID=\"%@\"/ FILE_ID=\"%@\">\n", 
															 index, imageID, [cacheDict objectForKey:imageID]]];
	}
	[xmlData appendString:@"</CACHED_IMAGES>\n"];
	
	return xmlData;
}


#pragma mark


- (void)dealloc
{
	[cachedImagesPath release];
	[cacheLock release];
	[imageCache release];
	[orderedCache release];
	[orderedCacheID release];
	[cachedImagesDictionary release];
    
    [super dealloc];
}

@end

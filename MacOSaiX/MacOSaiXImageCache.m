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
			diskCache = [[NSMutableDictionary dictionary] retain];
			memoryCache = [[NSMutableDictionary dictionary] retain];
			
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
		
			// Cache the image in memory for efficient retrieval.
		[memoryCache setObject:image forKey:imageKey];
		[orderedCache insertObject:image atIndex:0];
		[orderedCacheID insertObject:imageKey atIndex:0];
		if ([orderedCache count] > IMAGE_CACHE_MAX_COUNT)
		{
			[memoryCache removeObjectForKey:[orderedCacheID lastObject]];
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
		NSString	*imageKey = [self keyWithImageSource:imageSource identifier:imageIdentifier];
		
			// Check if the image is in the memory cache.
		image = [memoryCache objectForKey:imageKey];
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
			NSNumber	*imageID = [diskCache objectForKey:imageKey];
			if (imageID)
				image = [[[NSImage alloc] initWithContentsOfFile:[self filePathForCachedImageID:[imageID unsignedLongValue]]] autorelease];
            else
			{
					// This image is not in the disk cache so get the image from its source.
				NSLog(@"Requesting %@ from %@@%p", imageIdentifier, [imageSource class], imageSource);
				image = [imageSource imageForIdentifier:imageIdentifier];
			}
			
            if (image)
			{
					// Disable caching to avoid deadlocks.  Hopefully this won't be necessary in a future OS...
				[image setCacheMode:NSImageCacheNever];
				
					// Add the image to the in-memory cache.
				[memoryCache setObject:image forKey:imageKey];
			}
		}
		
		if (image)
		{
				// Add this image at the front of the in-memory cache.
			[orderedCache insertObject:image atIndex:0];
			[orderedCacheID insertObject:imageKey atIndex:0];
			
				// Prune the in-memory cache if it has gotten too large.
			if ([orderedCache count] > IMAGE_CACHE_MAX_COUNT)
			{
				[memoryCache removeObjectForKey:[orderedCacheID lastObject]];
				[orderedCache removeLastObject];
				[orderedCacheID removeLastObject];
			}
		}
	[cacheLock unlock];
	
	return image;
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
	[orderedCache release];
	[orderedCacheID release];
    
    [super dealloc];
}

@end

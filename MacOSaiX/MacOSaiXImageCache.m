/*
	MacOSaiXImageCache.m
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import "MacOSaiXImageCache.h"
#import <unistd.h>


	// The maximum width or height of the cached thumbnail images
#define kThumbnailMax 64.0
    // The number of cached images that will be held in memory at any one time.
#define IMAGE_CACHE_SIZE 100


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


- (void)cacheImage:(NSImage *)image 
	withIdentifier:(NSString *)imageIdentifier 
		fromSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
		long		imageID = cachedImageCount++;
		
			// Permanently store the image.  Squeeze it down to fit within one allocation block on disk (4KB).
		NSBitmapImageRep	*bitmapRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
		NSData				*imageData = nil;
		float				compressionFactor = 1.0;
		do
		{
			imageData = [bitmapRep representationUsingType:NSJPEGFileType 
												properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:compressionFactor]
																					   forKey:NSImageCompressionFactor]];
			compressionFactor -= 0.05;
		} while ([imageData length] > 4096);
		[imageData writeToFile:[self filePathForCachedImageID:imageID] atomically:NO];
		
		NSMutableDictionary	*imageSourceCache = [self cacheDictionaryForImageSource:imageSource];
		
			// Associate the ID with the image source/image identifier combo
		[imageSourceCache setObject:[NSNumber numberWithLong:imageID] forKey:imageIdentifier];
		
			// Cache the image for efficient retrieval.
		[imageCache setObject:image forKey:[NSNumber numberWithLong:imageID]];
		[orderedCache insertObject:image atIndex:0];
		[orderedCacheID insertObject:[NSNumber numberWithLong:imageID] atIndex:0];
		if ([orderedCache count] > IMAGE_CACHE_SIZE)
		{
			[imageCache removeObjectForKey:[orderedCacheID lastObject]];
			[orderedCache removeLastObject];
			[orderedCacheID removeLastObject];
		}
	[cacheLock unlock];
}


- (NSImage *)cachedImageForIdentifier:(NSString *)imageIdentifier fromSource:(id<MacOSaiXImageSource>)imageSource
{
	NSImage		*image = nil;
	
	[cacheLock lock];
		long		imageID = [[[self cacheDictionaryForImageSource:imageSource] objectForKey:imageIdentifier] longValue];
		NSNumber	*imageKey = [NSNumber numberWithLong:imageID];
		
		image = [imageCache objectForKey:imageKey];
		if (image)
        {
			int index = [orderedCache indexOfObjectIdenticalTo:image];
            if (index != NSNotFound)
            {
                [orderedCache removeObjectAtIndex:index];
                [orderedCacheID removeObjectAtIndex:index];
            }
        }
		else
		{
			image = [[[NSImage alloc] initWithContentsOfFile:[self filePathForCachedImageID:imageID]] autorelease];
            if (!image)
                NSLog(@"Huh?");
			else
				[imageCache setObject:image forKey:imageKey];
		}
		
		if (image)
		{
				// Move this image to the front of the in-memory cache so it persists longer.
			[orderedCache insertObject:image atIndex:0];
			[orderedCacheID insertObject:[NSNumber numberWithLong:imageID] atIndex:0];
			if ([orderedCache count] > IMAGE_CACHE_SIZE)
			{
				[imageCache removeObjectForKey:[NSNumber numberWithLong:imageID]];
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
	[cachedImagesDictionary release];
	[[NSFileManager defaultManager] removeFileAtPath:cachedImagesPath handler:nil];	// TODO: only if still in /tmp...
    
    [super dealloc];
}

@end

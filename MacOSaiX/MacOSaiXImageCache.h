/*
	MacOSaiXImageCache.h
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import <Cocoa/Cocoa.h>
#import "MacOSaiXImageSource.h"


	// The maximum width or height of the cached thumbnail images
#define kImageCacheThumbnailSize 64.0


@interface MacOSaiXImageCache : NSObject 
{
	NSMutableDictionary			*diskCache,
								*memoryCache;
	NSString					*cachedImagesPath;
    NSLock						*cacheLock;
    NSMutableArray				*orderedCache,
                                *orderedCacheID;
	unsigned long				cachedImageCount;
}

- (NSString *)cacheImage:(NSImage *)image 
		  withIdentifier:(NSString *)imageIdentifier 
			  fromSource:(id<MacOSaiXImageSource>)imageSource;

- (NSImage *)imageForIdentifier:(NSString *)imageIdentifier fromSource:(id<MacOSaiXImageSource>)imageSource;

- (NSString *)xmlDataWithImageSources:(NSArray *)imageSources;

@end

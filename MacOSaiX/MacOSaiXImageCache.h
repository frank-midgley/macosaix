/*
	MacOSaiXImageCache.h
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import <Cocoa/Cocoa.h>
#import "MacOSaiXImageSource.h"


@interface MacOSaiXImageCache : NSObject 
{
	NSMutableDictionary			*diskCache,
								*memoryCache,
								*nativeImageSizeDict;
	NSString					*cachedImagesPath;
    NSRecursiveLock				*cacheLock;
    NSMutableArray				*imageRepRecencyArray,
                                *imageKeyRecencyArray;
	unsigned long				cachedImageCount,
								perfectHitCount,
								scalableHitCount,
								missCount;
	unsigned long long			memoryCacheSize;
}


+ (MacOSaiXImageCache *)sharedImageCache;

- (NSString *)cacheImage:(NSImage *)image 
		  withIdentifier:(NSString *)imageIdentifier 
			  fromSource:(id<MacOSaiXImageSource>)imageSource;

- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size 
					   forIdentifier:(NSString *)imageIdentifier 
						  fromSource:(id<MacOSaiXImageSource>)imageSource;

- (void)removeCachedImageRepsFromSource:(id<MacOSaiXImageSource>)imageSource;

- (NSString *)xmlDataWithImageSources:(NSArray *)imageSources;

@end

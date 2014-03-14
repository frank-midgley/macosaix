/*
	MacOSaiXImageCache.h
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import <Cocoa/Cocoa.h>
#import "MacOSaiXImageSource.h"

@class MacOSaiXSourceImage;


@interface MacOSaiXImageCache : NSObject 
{
	NSMutableDictionary			*diskCache,
								*memoryCache,
								*nativeImageSizeDict, 
								*sourceCacheDirectories;
	NSString					*cachedImagesPath;
    NSRecursiveLock				*cacheLock;
//    NSMutableArray				*imageRepRecencyArray,
//                                *imageKeyRecencyArray;
	NSMutableArray				*flatImageRepCache;
	unsigned long				perfectHitCount,
								scalableHitCount,
								missCount;
	unsigned long long			maxMemoryCacheSize,
								currentMemoryCacheSize;
//	NSWindow					*scalingWindow;
}


+ (MacOSaiXImageCache *)sharedImageCache;

- (void)lock;
- (void)unlock;

- (void)setCacheDirectory:(NSString *)directoryPath forSource:(id<MacOSaiXImageSource>)imageSource;

- (void)cacheSourceImage:(MacOSaiXSourceImage *)sourceImage ;

- (NSSize)nativeSizeOfSourceImage:(MacOSaiXSourceImage *)sourceImage;

- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size 
					  forSourceImage:(MacOSaiXSourceImage *)sourceImage;

- (void)removeSourceImage:(MacOSaiXSourceImage *)sourceImage;

- (void)removeCachedImagesFromSource:(id<MacOSaiXImageSource>)imageSource;

- (NSString *)xmlDataWithImageSources:(NSArray *)imageSources;

- (unsigned long long)currentMemoryCacheSize;

@end

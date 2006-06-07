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
								*nativeImageSizeDict, 
								*sourceCacheDirectories;
	NSString					*cachedImagesPath;
    NSRecursiveLock				*cacheLock;
    NSMutableArray				*imageRepRecencyArray,
                                *imageIdentifierRecencyArray, 
								*imageSourceRecencyArray;
	unsigned long				cachedImageCount,
								perfectHitCount,
								scalableHitCount,
								missCount;
	unsigned long long			maxMemoryCacheSize,
								currentMemoryCacheSize;
	NSWindow					*scalingWindow;
}


+ (MacOSaiXImageCache *)sharedImageCache;

- (void)setCacheDirectory:(NSString *)directoryPath forSource:(id<MacOSaiXImageSource>)imageSource;

- (void)cacheImage:(NSImage *)image 
	withIdentifier:(NSString *)imageIdentifier 
		fromSource:(id<MacOSaiXImageSource>)imageSource;

- (NSSize)nativeSizeOfImageWithIdentifier:(NSString *)imageIdentifier 
							   fromSource:(id<MacOSaiXImageSource>)imageSource;

- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size 
					   forIdentifier:(NSString *)imageIdentifier 
						  fromSource:(id<MacOSaiXImageSource>)imageSource;

- (void)removeCachedImagesWithIdentifiers:(NSArray *)imageIdentifiers 
							   fromSource:(id<MacOSaiXImageSource>)imageSource;

- (void)removeCachedImagesFromSource:(id<MacOSaiXImageSource>)imageSource;

@end

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
	NSMutableDictionary			*cachedImagesDictionary;
	NSString					*cachedImagesPath;
    NSLock						*cacheLock;
	NSMutableDictionary			*imageCache;
    NSMutableArray				*orderedCache,
                                *orderedCacheID;
	long						cachedImageCount;
}

- (void)cacheImage:(NSImage *)image 
	withIdentifier:(NSString *)imageIdentifier 
		fromSource:(id<MacOSaiXImageSource>)imageSource;

- (NSImage *)cachedImageForIdentifier:(NSString *)imageIdentifier fromSource:(id<MacOSaiXImageSource>)imageSource;

@end

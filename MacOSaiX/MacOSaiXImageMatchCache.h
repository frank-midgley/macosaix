//
//  MacOSaiXImageMatchCache.h
//  MacOSaiX
//
//  Created by Frank Midgley on 2/20/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MacOSaiXImageMatch, MacOSaiXSourceImage, MacOSaiXTile;
@protocol MacOSaiXImageSource;


@interface MacOSaiXImageMatchCache : NSObject
{
	NSMutableDictionary		*cache;
	long					matchCount, 
							cacheLimit;
	NSMutableArray			*recencyArray;
	NSLock					*cacheLock;
}

+ (MacOSaiXImageMatchCache *)sharedCache;

- (unsigned)size;

- (void)addImageMatch:(MacOSaiXImageMatch *)imageMatch;
- (void)addImageMatches:(NSArray *)imageMatches forSourceImage:(MacOSaiXSourceImage *)sourceImage;
- (void)addImageMatches:(NSArray *)imageMatches forTile:(MacOSaiXTile *)tile;

- (NSArray *)matchesForSourceImage:(MacOSaiXSourceImage *)sourceImage;
- (NSArray *)matchesForTile:(MacOSaiXTile *)tile;

- (void)removeImageMatch:(MacOSaiXImageMatch *)imageMatch;
- (void)removeMatchesFromSource:(id<MacOSaiXImageSource>)imageSource;

- (void)lock;
- (void)unlock;

@end

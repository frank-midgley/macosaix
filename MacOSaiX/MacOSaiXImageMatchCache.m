//
//  MacOSaiXImageMatchCache.m
//  MacOSaiX
//
//  Created by Frank Midgley on 2/20/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageMatchCache.h"

#import "MacOSaiXImageMatch.h"
#import "MacOSaiXSourceImage.h"
#import "Tiles.h"


static	MacOSaiXImageMatchCache	*sharedCache = nil;


@interface MacOSaiXTile (ImageMatchCaching)
- (void)cacheMatch:(MacOSaiXImageMatch *)match;
- (NSMutableArray *)cachedMatches;
- (void)removeCachedMatch:(MacOSaiXImageMatch *)match;
- (void)removeCachedMatches;
@end


@implementation MacOSaiXImageMatchCache


+ (void)initialize
{
	sharedCache = [[MacOSaiXImageMatchCache alloc] init];
}


+ (MacOSaiXImageMatchCache *)sharedCache
{
	return sharedCache;
}


- (id)init
{
	if (self = [super init])
	{
		cache = [[NSMutableDictionary alloc] init];
		recencyArray = [[NSMutableArray alloc] init];
		
		// Set a limit on the number of image matches cached so that no more than 1/16 of physical RAM is used.  It is assumed that each match uses 40 bytes:
		//     16 bytes for the match object itself
		//      4 bytes for the reference to the match in the source image cache
		//      4 bytes for the reference to the match in the tile cache
		cacheLimit = (NSRealMemoryAvailable() / 8) / 24;
		
		cacheLock = [[NSLock alloc] init];
	}
	
	return self;
}


- (unsigned)size
{
	return matchCount * 24;
}


- (void)pruneCache
{
	// Don't let the cache get too big.
	while (matchCount > cacheLimit)
	{
		// Remove all of the matches for the source image that was least recently touched.
		NSString			*keyToPurge = [[recencyArray lastObject] key];
		NSArray				*matchesToPurge = [cache objectForKey:keyToPurge];
//		NSLog(@"Purging %5d matches for %@", [matchesToPurge count], keyToPurge);
		NSEnumerator		*matchEnumerator = [matchesToPurge objectEnumerator];
		MacOSaiXImageMatch	*matchToPurge = nil;
		while ((matchToPurge = [matchEnumerator nextObject]))
			[[matchToPurge tile] removeCachedMatch:matchToPurge];
		[cache removeObjectForKey:keyToPurge];
		[recencyArray removeLastObject];
		matchCount -= [matchesToPurge count];
	}
}


- (void)addImageMatch:(MacOSaiXImageMatch *)imageMatch
{
	[cacheLock lock];
	
    MacOSaiXSourceImage	*sourceImage = [imageMatch sourceImage];
	NSString			*sourceImageKey = [sourceImage key];
	NSMutableArray		*cachedMatches = [cache objectForKey:sourceImageKey];
	
	if (!cachedMatches)
	{
		cachedMatches = [NSMutableArray array];
		[cache setObject:cachedMatches forKey:sourceImageKey];
	}
	
	[cachedMatches addObject:imageMatch];
	matchCount += 1;
	
	if ([recencyArray count] == 0 || ![[recencyArray objectAtIndex:0] isEqual:sourceImage])
	{
		[recencyArray removeObject:sourceImage];
		[recencyArray insertObject:sourceImage atIndex:0];
	}
	
	[[imageMatch tile] cacheMatch:imageMatch];
	
	[self pruneCache];
	
	[cacheLock unlock];
}


- (void)addImageMatches:(NSArray *)imageMatches forSourceImage:(MacOSaiXSourceImage *)sourceImage
{
	if ([imageMatches count] > 0)
	{
		[cacheLock lock];
		
		NSString			*sourceImageKey = [sourceImage key];
		NSMutableArray		*cachedMatches = [cache objectForKey:sourceImageKey];
		
		if (!cachedMatches)
		{
			cachedMatches = [NSMutableArray array];
			[cache setObject:cachedMatches forKey:sourceImageKey];
		}
		
		[cachedMatches addObjectsFromArray:imageMatches];
		matchCount += [imageMatches count];
		
		[recencyArray removeObject:sourceImage];
		[recencyArray insertObject:sourceImage atIndex:0];
		
		NSEnumerator		*matchEnumerator = [imageMatches objectEnumerator];
		MacOSaiXImageMatch	*imageMatch = nil;
		while (imageMatch = [matchEnumerator nextObject])
			[[imageMatch tile] cacheMatch:imageMatch];
		
		[self pruneCache];
		
		[cacheLock unlock];
	}
}


- (void)addImageMatches:(NSArray *)imageMatches forTile:(MacOSaiXTile *)tile
{
	if ([imageMatches count] > 0)
	{
		[cacheLock lock];
		
		NSEnumerator		*matchEnumerator = [imageMatches objectEnumerator];
		MacOSaiXImageMatch	*imageMatch = nil;
		while (imageMatch = [matchEnumerator nextObject])
		{
			[tile cacheMatch:imageMatch];
			
			NSString		*sourceImageKey = [[imageMatch sourceImage] key];
			NSMutableArray	*cachedMatches = [cache objectForKey:sourceImageKey];
			
			if (!cachedMatches)
			{
				cachedMatches = [NSMutableArray array];
				[cache setObject:cachedMatches forKey:sourceImageKey];
			}
			
			[cachedMatches addObject:imageMatch];
		}
		
		matchCount += [imageMatches count];
		
		[self pruneCache];
		
		[cacheLock unlock];
	}
}


- (NSArray *)matchesForSourceImage:(MacOSaiXSourceImage *)sourceImage
{
    NSArray *matches = nil;
    
	[cacheLock lock];
	
	NSMutableArray	*cachedMatches = [cache objectForKey:[sourceImage key]];
	
	if (cachedMatches)
	{
		[recencyArray removeObject:sourceImage];
		[recencyArray insertObject:sourceImage atIndex:0];
	}
    
	matches = [NSArray arrayWithArray:cachedMatches];
	
    [cacheLock unlock];
    
	return matches;
}


- (NSArray *)matchesForTile:(MacOSaiXTile *)tile
{
	NSArray	*cachedMatches = nil;
	
	[cacheLock lock];
	
	cachedMatches = [tile cachedMatches];
	
	[cacheLock unlock];
	
	return cachedMatches;
}


- (void)removeImageMatch:(MacOSaiXImageMatch *)imageMatch
{
	[cacheLock lock];
	
	NSString		*sourceImageKey = [[imageMatch sourceImage] key];
	NSMutableArray	*cachedMatches = [cache objectForKey:sourceImageKey];
	
	[cachedMatches removeObjectIdenticalTo:imageMatch];
	
	if ([cachedMatches count] == 0)
	{
		[cache removeObjectForKey:sourceImageKey];
		[recencyArray removeObject:[imageMatch sourceImage]];
	}
	
	[[imageMatch tile] removeCachedMatch:imageMatch];
	
	matchCount -= 1;
	
	[cacheLock unlock];
}


- (void)removeMatchesFromSource:(id<MacOSaiXImageSource>)imageSource
{
	[cacheLock lock];
	
	NSEnumerator		*sourceImageEnumerator = [recencyArray objectEnumerator];
	MacOSaiXSourceImage	*sourceImage = nil;
	unsigned long		indexesToRemove[[recencyArray count]], 
						indexesToRemoveCount = 0, 
						index = 0;
	
	while (sourceImage = [sourceImageEnumerator nextObject])
	{
		if ([sourceImage source] == imageSource)
		{
			NSString		*sourceImageKey = [sourceImage key];
			NSArray			*matches = [cache objectForKey:sourceImageKey];
//            {
//                NSEnumerator	*matchEnumerator = [matches objectEnumerator];
//                MacOSaiXImageMatch	*match = nil;
//                while (match = [matchEnumerator nextObject])
//                    [[match tile] removeCachedMatch:match];
//            }
			matchCount -= [matches count];
			[cache removeObjectForKey:sourceImageKey];
			
			indexesToRemove[indexesToRemoveCount++] = index;
		}
		
		index++;
	}
	
	[recencyArray removeObjectsFromIndices:indexesToRemove numIndices:indexesToRemoveCount];
	
	[cacheLock unlock];
}


- (void)lock
{
	[cacheLock lock];
}


- (void)unlock
{
	[cacheLock unlock];
}


- (void)dealloc
{
	[cache release];
	[recencyArray release];
	[cacheLock release];
	
	[super dealloc];
}


@end

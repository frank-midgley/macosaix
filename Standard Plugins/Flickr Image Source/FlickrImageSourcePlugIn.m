//
//  FlickrImageSourcePlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 1/4/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "FlickrImageSourcePlugIn.h"

#import "FlickrImageSource.h"
#import "FlickrImageSourceController.h"
#import "FlickrPreferencesController.h"

#import <sys/time.h>
#import <sys/stat.h>
#import <sys/mount.h>


static NSImage				*fIcon, 
							*flickrIcon;
static NSLock				*imageCacheLock;
static NSString				*imageCachePath;
static BOOL					pruningCache, 
							purgeCache;
static unsigned long long	imageCacheSize, 
							maxImageCacheSize = 128 * 1024 * 1024,
							minDiskFreeSpace = 1024 * 1024 * 1024;


static int compareWithKey(NSDictionary	*dict1, NSDictionary *dict2, void *context)
{
	return [(NSNumber *)[dict1 objectForKey:context] compare:(NSNumber *)[dict2 objectForKey:context]];
}


@implementation MacOSaiXFlickrImageSourcePlugIn


+ (void)load
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	imageCachePath = [[[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] 
											stringByAppendingPathComponent:@"Caches"]
											stringByAppendingPathComponent:@"MacOSaiX Flickr Images"] retain];
	if (![[NSFileManager defaultManager] fileExistsAtPath:imageCachePath])
		[[NSFileManager defaultManager] createDirectoryAtPath:imageCachePath attributes:nil];
	
	imageCacheLock = [[NSLock alloc] init];
	
	NSString	*iconPath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"f"];
	fIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	
	iconPath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"flickr"];
	flickrIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	
	NSNumber	*maxCacheSize = [self preferredValueForKey:@"Maximum Cache Size"],
		*minFreeSpace = [self preferredValueForKey:@"Minimum Free Space On Cache Volume"];
	
	if (maxCacheSize)
		maxImageCacheSize = [maxCacheSize unsignedLongLongValue];
	if (minFreeSpace)
		minDiskFreeSpace = [minFreeSpace unsignedLongLongValue];
	
	// Do an initial prune which also gets the current size of the cache.
	// No new images can be cached until this completes but images can be read from the cache.
	[self pruneCache];
	
	[pool release];
}


+ (NSImage *)image
{
    return fIcon;
}


+ (NSImage *)flickrIcon
{
	return flickrIcon;
}


+ (Class)dataSourceClass
{
	return [MacOSaiXFlickrImageSource class];
}


+ (Class)editorClass
{
	return [MacOSaiXFlickrImageSourceEditor class];
}


+ (Class)preferencesEditorClass
{
	return [MacOSaiXFlickrPreferencesController class];
}


#pragma mark
#pragma mark Image cache


+ (NSString *)imageCachePath
{
	return imageCachePath;
}


+ (NSString *)cachedFileNameForIdentifier:(NSString *)identifier thumbnail:(BOOL)thumbnail
{
	NSArray		*identifierComponents = [identifier componentsSeparatedByString:@"\t"];
	NSString	*serverID = [identifierComponents objectAtIndex:0], 
				*photoID = [identifierComponents objectAtIndex:1];
	
	return [NSString stringWithFormat:@"%@-%@%@.jpg", serverID, photoID, (thumbnail ? @" thumb" : @"")];
}


+ (void)cacheImageData:(NSData *)imageData withIdentifier:(NSString *)identifier isThumbnail:(BOOL)isThumbnail
{
	if (!pruningCache)
	{
		NSString	*imageFileName = [self cachedFileNameForIdentifier:identifier thumbnail:isThumbnail];

		[imageCacheLock lock];
			[imageData writeToFile:[[self imageCachePath] stringByAppendingPathComponent:imageFileName] atomically:NO];
			
				// Spawn a cache pruning thread if called for.
			imageCacheSize += [imageData length];
			unsigned long long	freeSpace = [[[[NSFileManager defaultManager] fileSystemAttributesAtPath:[self imageCachePath]] 
													objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
			if (imageCacheSize > maxImageCacheSize || freeSpace < minDiskFreeSpace)
				[self pruneCache];
		[imageCacheLock unlock];
	}
}


+ (NSImage *)cachedImageWithIdentifier:(NSString *)identifier getThumbnail:(BOOL)thumbnail
{
	NSImage		*cachedImage = nil;
	NSString	*imageFileName = [self cachedFileNameForIdentifier:identifier thumbnail:thumbnail];
	NSData		*imageData = nil;
	
	imageData = [[NSData alloc] initWithContentsOfFile:[[self imageCachePath] stringByAppendingPathComponent:imageFileName]];
	if (imageData)
	{
		cachedImage = [[[NSImage alloc] initWithData:imageData] autorelease];
		[imageData release];
	}
	
	if (!pruningCache)
	{
			// Spawn a cache pruning thread if called for.
		unsigned long long	freeSpace = [[[[NSFileManager defaultManager] fileSystemAttributesAtPath:[self imageCachePath]] 
												objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
		if (freeSpace < minDiskFreeSpace)
			[self pruneCache];
	}
	
	return cachedImage;
}


+ (void)pruneCache
{
	if (!pruningCache)
		[NSThread detachNewThreadSelector:@selector(pruneCacheInThread) toTarget:self withObject:nil];
}


+ (void)pruneCacheInThread
{
	pruningCache = YES;
	
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	NSFileManager		*fileManager = [NSFileManager defaultManager];
	NSString			*cachePath = [self imageCachePath];

	unsigned long long	freeSpace = [[[fileManager fileSystemAttributesAtPath:cachePath] objectForKey:NSFileSystemFreeSize] 
										unsignedLongLongValue];
	
	[imageCacheLock lock];
			// Get the size and last access date of every image in the cache.
		NSEnumerator		*imageNameEnumerator = [[fileManager directoryContentsAtPath:cachePath] objectEnumerator];
		NSString			*imageName = nil;
		NSMutableArray		*imageArray = [NSMutableArray array];
		imageCacheSize = 0;
		while (!purgeCache && (imageName = [imageNameEnumerator nextObject]))
		{
			NSString	*imagePath = [cachePath stringByAppendingPathComponent:imageName];
			struct stat	fileStat;
			if (lstat([imagePath fileSystemRepresentation], &fileStat) == 0)
			{
				NSDictionary	*attributes = [NSDictionary dictionaryWithObjectsAndKeys:
												imagePath, @"Path", 
												[NSNumber numberWithUnsignedLong:fileStat.st_size], @"Size", 
												[NSNumber numberWithUnsignedLong:fileStat.st_atimespec.tv_sec], @"Last Access",
												nil];
				[imageArray addObject:attributes];
				imageCacheSize += fileStat.st_size;
			}
		}
			
			// Sort the images by the date/time they were last accessed.
		if (!purgeCache)
			[imageArray sortUsingFunction:compareWithKey context:@"Last Access"];
		
			// Remove the least recently accessed image until we satisfy the user's prefs.
		unsigned long long	targetCacheSize = maxImageCacheSize * 0.9, 
							targetFreeSpace = minDiskFreeSpace * 1.1;
		int					purgeCount = 0;
		while (!purgeCache && (imageCacheSize > targetCacheSize || freeSpace < targetFreeSpace) && [imageArray count] > 0)
		{
			NSDictionary		*imageToDelete = [imageArray objectAtIndex:0];
			unsigned long long	fileSize = [[imageToDelete objectForKey:@"Size"] unsignedLongLongValue];
			
			[fileManager removeFileAtPath:[imageToDelete objectForKey:@"Path"] handler:nil];
			imageCacheSize -= fileSize;
			freeSpace += fileSize;
			
			[imageArray removeObjectAtIndex:0];
			purgeCount++;
		}
		#ifdef DEBUG
			if (purgeCount > 0)
				NSLog(@"Purged %d images from the flickr cache.", purgeCount);
		#endif
		
		if (purgeCache)
		{
			[fileManager removeFileAtPath:cachePath handler:nil];
			[fileManager createDirectoryAtPath:cachePath attributes:nil];
			imageCacheSize = 0;
			purgeCache = NO;
		}
	[imageCacheLock unlock];

	[pool release];
	
	pruningCache = NO;
}


+ (void)purgeCache
{
	if (pruningCache)
		purgeCache = YES;	// let the pruning thread handle the purge
	else
	{
		[imageCacheLock lock];
			NSFileManager	*fileManager = [NSFileManager defaultManager];
			NSString		*cachePath = [self imageCachePath];
			
			[fileManager removeFileAtPath:cachePath handler:nil];
			[fileManager createDirectoryAtPath:cachePath attributes:nil];
			
			imageCacheSize = 0;
		[imageCacheLock unlock];
	}
}


#pragma mark
#pragma mark Preferences


+ (void)setPreferredValue:(id)value forKey:(NSString *)key
{
		// NSUserDefaults is not thread safe.  Make sure we set the default on the main thread.
	[self performSelectorOnMainThread:@selector(setPreferredValueOnMainThread:) 
						   withObject:[NSDictionary dictionaryWithObject:value forKey:key] 
						waitUntilDone:NO];
}


+ (void)setPreferredValueOnMainThread:(NSDictionary *)keyValuePair
{
		// Save all of the preferences for this plug-in in a dictionary within the main prefs dictionary.
	NSMutableDictionary	*flickrPrefs = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Flickr Image Source"] mutableCopy] autorelease];
	if (!flickrPrefs)
		flickrPrefs = [NSMutableDictionary dictionary];
	
	NSString	*key = [[keyValuePair allKeys] lastObject];
	[flickrPrefs setObject:[keyValuePair objectForKey:key] forKey:key];
	
	[[NSUserDefaults standardUserDefaults] setObject:flickrPrefs forKey:@"Flickr Image Source"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


+ (id)preferredValueForKey:(NSString *)key
{
		// This should be done on the main thread, too, but it could deadlock since we would need to wait for return.
	return [[[NSUserDefaults standardUserDefaults] objectForKey:@"Flickr Image Source"] objectForKey:key];
}


+ (void)setMaxCacheSize:(unsigned long long)size
{
	[self setPreferredValue:[NSNumber numberWithUnsignedLongLong:maxImageCacheSize] 
					 forKey:@"Maximum Cache Size"];
	maxImageCacheSize = size;
}


+ (unsigned long long)maxCacheSize
{
	return maxImageCacheSize;
}


+ (void)setMinFreeSpace:(unsigned long long)space
{
	[self setPreferredValue:[NSNumber numberWithUnsignedLongLong:minDiskFreeSpace] 
					 forKey:@"Minimum Free Space On Cache Volume"];
	minDiskFreeSpace = space;
}


+ (unsigned long long)minFreeSpace
{
	return minDiskFreeSpace;
}


#pragma mark -


- (void)dealloc
{
	[fIcon release];
	[flickrIcon release];
	
	[super dealloc];
}


@end

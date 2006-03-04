/*
	GoogleImageSource.m
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

#import "GoogleImageSource.h"
#import "GoogleImageSourceController.h"
#import "GooglePreferencesController.h"
#import "NSString+MacOSaiX.h"
#import <CoreFoundation/CFURL.h>
#import <sys/time.h>
#import <sys/stat.h>
#import <sys/mount.h>


	// The image cache is shared between all instances so we need a class level lock.
static NSLock				*sImageCacheLock = nil;
static BOOL					sPruningCache = NO, 
							sPurgeCache = NO;
static unsigned long long	sCacheSize = 0, 
							sMaxCacheSize = 128 * 1024 * 1024,
							sMinFreeSpace = 1024 * 1024 * 1024;

static NSImage				*gIcon = nil,
							*googleIcon = nil;


NSString *escapedNSString(NSString *string)
{
	NSString	*escapedString = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, 
																					 NULL, NULL, kCFStringEncodingUTF8);
	return [escapedString autorelease];
}


int compareWithKey(NSDictionary	*dict1, NSDictionary *dict2, void *context)
{
	return [(NSNumber *)[dict1 objectForKey:context] compare:(NSNumber *)[dict2 objectForKey:context]];
}


@interface GoogleImageSource (PrivateMethods)
+ (void)pruneCache;
+ (id)preferredValueForKey:(NSString *)key;
- (void)updateQueryAndDescriptor;
@end


@implementation GoogleImageSource


+ (void)load
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:[self imageCachePath]])
		[[NSFileManager defaultManager] createDirectoryAtPath:[self imageCachePath] attributes:nil];
	
	sImageCacheLock = [[NSLock alloc] init];
	
	NSString	*iconPath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"G"];
	gIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	
	iconPath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"GoogleImageSource"];
	googleIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	
	NSNumber	*maxCacheSize = [self preferredValueForKey:@"Maximum Cache Size"],
				*minFreeSpace = [self preferredValueForKey:@"Minimum Free Space On Cache Volume"];
	
	if (maxCacheSize)
		sMaxCacheSize = [maxCacheSize unsignedLongLongValue];
	if (minFreeSpace)
		sMinFreeSpace = [minFreeSpace unsignedLongLongValue];
	
		// Do an initial prune which also gets the current size of the cache.
		// No new images can be cached until this completes but images can be read from the cache.
	[self pruneCache];
	
	[pool release];
}


+ (NSImage *)image;
{
    return gIcon;
}


+ (Class)editorClass
{
	return [GoogleImageSourceController class];
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


#pragma mark
#pragma mark Image cache


+ (NSString *)imageCachePath
{
	return [[[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] 
								 stringByAppendingPathComponent:@"Caches"]
								 stringByAppendingPathComponent:@"MacOSaiX Google Images"] retain];
}


+ (void)cacheImageData:(NSData *)imageData withIdentifier:(NSString *)identifier
{
	if (!sPruningCache)
	{
		NSString	*imageID = [identifier substringWithRange:NSMakeRange(14, 12)],
					*imageFileName = [NSString stringWithFormat:@"%x%x%x%x%x%x%x%x%x%x%x%x",
																[imageID characterAtIndex:0], [imageID characterAtIndex:1],
																[imageID characterAtIndex:2], [imageID characterAtIndex:3],
																[imageID characterAtIndex:4], [imageID characterAtIndex:5],
																[imageID characterAtIndex:6], [imageID characterAtIndex:7],
																[imageID characterAtIndex:8], [imageID characterAtIndex:9],
																[imageID characterAtIndex:10], [imageID characterAtIndex:11]];

		[sImageCacheLock lock];
			[imageData writeToFile:[[self imageCachePath] stringByAppendingPathComponent:imageFileName] atomically:NO];
			
				// Spawn a cache pruning thread if called for.
			sCacheSize += [imageData length];
			unsigned long long	freeSpace = [[[[NSFileManager defaultManager] fileSystemAttributesAtPath:[self imageCachePath]] 
													objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
			if (sCacheSize > sMaxCacheSize || freeSpace < sMinFreeSpace)
				[self pruneCache];
		[sImageCacheLock unlock];
	}
}


+ (NSImage *)cachedImageWithIdentifier:(NSString *)identifier
{
	NSImage		*cachedImage = nil;
	NSString	*imageID = [identifier substringWithRange:NSMakeRange(14, 12)],
				*imageFileName = [NSString stringWithFormat:@"%x%x%x%x%x%x%x%x%x%x%x%x",
															[imageID characterAtIndex:0], [imageID characterAtIndex:1],
															[imageID characterAtIndex:2], [imageID characterAtIndex:3],
															[imageID characterAtIndex:4], [imageID characterAtIndex:5],
															[imageID characterAtIndex:6], [imageID characterAtIndex:7],
															[imageID characterAtIndex:8], [imageID characterAtIndex:9],
															[imageID characterAtIndex:10], [imageID characterAtIndex:11]];
	NSData		*imageData = nil;
	
	imageData = [[NSData alloc] initWithContentsOfFile:[[self imageCachePath] stringByAppendingPathComponent:imageFileName]];
	if (imageData)
	{
		cachedImage = [[[NSImage alloc] initWithData:imageData] autorelease];
		[imageData release];
	}
	
	if (!sPruningCache)
	{
			// Spawn a cache pruning thread if called for.
		unsigned long long	freeSpace = [[[[NSFileManager defaultManager] fileSystemAttributesAtPath:[self imageCachePath]] 
												objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
		if (freeSpace < sMinFreeSpace)
			[self pruneCache];
	}
	
	return cachedImage;
}


+ (void)pruneCache
{
	if (!sPruningCache)
		[NSThread detachNewThreadSelector:@selector(pruneCacheInThread) toTarget:self withObject:nil];
}


+ (void)pruneCacheInThread
{
	sPruningCache = YES;
	
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	NSFileManager		*fileManager = [NSFileManager defaultManager];
	NSString			*cachePath = [self imageCachePath];

	unsigned long long	freeSpace = [[[fileManager fileSystemAttributesAtPath:cachePath] objectForKey:NSFileSystemFreeSize] 
										unsignedLongLongValue];
	
	[sImageCacheLock lock];
			// Get the size and last access date of every image in the cache.
		NSEnumerator		*imageNameEnumerator = [[fileManager directoryContentsAtPath:cachePath] objectEnumerator];
		NSString			*imageName = nil;
		NSMutableArray		*imageArray = [NSMutableArray array];
		sCacheSize = 0;
		while (!sPurgeCache && (imageName = [imageNameEnumerator nextObject]))
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
				sCacheSize += fileStat.st_size;
			}
		}
			
			// Sort the images by the date/time they were last accessed.
		if (!sPurgeCache)
			[imageArray sortUsingFunction:compareWithKey context:@"Last Access"];
		
			// Remove the least recently accessed image until we satisfy the user's prefs.
		unsigned long long	targetSize = sMaxCacheSize * 0.9;
		while (!sPurgeCache && (sCacheSize > targetSize || freeSpace < sMinFreeSpace) && [imageArray count] > 0)
		{
			NSDictionary		*imageToDelete = [imageArray lastObject];
			unsigned long long	fileSize = [[imageToDelete objectForKey:@"Size"] unsignedLongLongValue];
			
			[fileManager removeFileAtPath:[imageToDelete objectForKey:@"Path"] handler:nil];
			sCacheSize -= fileSize;
			freeSpace += fileSize;
			
			[imageArray removeLastObject];
		}
		
		if (sPurgeCache)
		{
			[fileManager removeFileAtPath:cachePath handler:nil];
			[fileManager createDirectoryAtPath:cachePath attributes:nil];
			sCacheSize = 0;
			sPurgeCache = NO;
		}
	[sImageCacheLock unlock];

	[pool release];
	
	sPruningCache = NO;
}


+ (void)purgeCache
{
	if (sPruningCache)
		sPurgeCache = YES;	// let the pruning thread handle the purge
	else
	{
		[sImageCacheLock lock];
			NSFileManager	*fileManager = [NSFileManager defaultManager];
			NSString		*cachePath = [self imageCachePath];
			
			[fileManager removeFileAtPath:cachePath handler:nil];
			[fileManager createDirectoryAtPath:cachePath attributes:nil];
			
			sCacheSize = 0;
		[sImageCacheLock unlock];
	}
}


#pragma mark
#pragma mark Preferences


+ (Class)preferencesControllerClass
{
	return [GooglePreferencesController class];
}


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
	NSMutableDictionary	*googlePrefs = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Google Image Source"] mutableCopy] autorelease];
	if (!googlePrefs)
		googlePrefs = [NSMutableDictionary dictionary];
	
	NSString	*key = [[keyValuePair allKeys] lastObject];
	[googlePrefs setObject:[keyValuePair objectForKey:key] forKey:key];
	
	[[NSUserDefaults standardUserDefaults] setObject:googlePrefs forKey:@"Google Image Source"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


+ (id)preferredValueForKey:(NSString *)key
{
		// This should be done on the main thread, too, but it could deadlock since we would need to wait for return.
	return [[[NSUserDefaults standardUserDefaults] objectForKey:@"Google Image Source"] objectForKey:key];
}


+ (void)setMaxCacheSize:(unsigned long long)maxCacheSize
{
	[self setPreferredValue:[NSNumber numberWithUnsignedLongLong:maxCacheSize] 
					 forKey:@"Maximum Cache Size"];
	sMaxCacheSize = maxCacheSize;
}


+ (unsigned long long)maxCacheSize
{
	return sMaxCacheSize;
}


+ (void)setMinFreeSpace:(unsigned long long)minFreeSpace
{
	[self setPreferredValue:[NSNumber numberWithUnsignedLongLong:minFreeSpace] 
					 forKey:@"Minimum Free Space On Cache Volume"];
	sMinFreeSpace = minFreeSpace;
}


+ (unsigned long long)minFreeSpace
{
	return sMinFreeSpace;
}


#pragma mark


- (id)init
{
	if (self = [super init])
	{
		if ([[NSFileManager defaultManager] fileExistsAtPath:[GoogleImageSource imageCachePath]])
		{
			imageURLQueue = [[NSMutableArray array] retain];
		}
		else
		{
			[self autorelease];
			self = nil;
		}
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	GoogleImageSource	*copy = [[GoogleImageSource allocWithZone:zone] init];
	
	[copy setRequiredTerms:requiredTerms];
	[copy setOptionalTerms:optionalTerms];
	[copy setExcludedTerms:excludedTerms];
	[copy setColorSpace:colorSpace];
	[copy setSiteString:siteString];
	[copy setAdultContentFiltering:adultContentFiltering];
	
	return copy;
}


- (NSString *)settingsAsXMLElement
{
	NSMutableString	*settingsXML = [NSMutableString string];
	
	[settingsXML appendFormat:@"<TERMS REQUIRED=\"%@\"\n       OPTIONAL=\"%@\"\n       EXCLUDED=\"%@\"/>\n", 
							  [[self requiredTerms] stringByEscapingXMLEntites],
							  [[self optionalTerms] stringByEscapingXMLEntites],
							  [[self excludedTerms] stringByEscapingXMLEntites]];
	
	switch ([self colorSpace])
	{
		case anyColorSpace:
			[settingsXML appendString:@"<COLOR_SPACE FILTER=\"ANY\"/>\n"]; break;
		case rgbColorSpace:
			[settingsXML appendString:@"<COLOR_SPACE FILTER=\"RGB\"/>\n"]; break;
		case grayscaleColorSpace:
			[settingsXML appendString:@"<COLOR_SPACE FILTER=\"GRAYSCALE\"/>\n"]; break;
		case blackAndWhiteColorSpace:
			[settingsXML appendString:@"<COLOR_SPACE FILTER=\"B&amp;W\"/>\n"]; break;
	}
	
	if ([self siteString])
		[settingsXML appendFormat:@"<SITE FILTER=\"%@\"/>\n", [[self siteString] stringByEscapingXMLEntites]];
	
	switch ([self adultContentFiltering])
	{
		case strictFiltering:
			[settingsXML appendString:@"<ADULT_CONTENT FILTER=\"STRICT\"/>\n"]; break;
		case moderateFiltering:
			[settingsXML appendString:@"<ADULT_CONTENT FILTER=\"MODERATE\"/>\n"]; break;
		case noFiltering:
			[settingsXML appendString:@"<ADULT_CONTENT FILTER=\"NONE\"/>\n"]; break;
	}
	
	[settingsXML appendFormat:@"<PAGE INDEX=\"%d\"/>\n", startIndex];
	
	NSEnumerator	*queuedURLEnumerator = [imageURLQueue objectEnumerator];
	NSString		*queuedURL = nil;
	while (queuedURL = [queuedURLEnumerator nextObject])
		[settingsXML appendFormat:@"<QUEUED_IMAGE URL=\"%@\"/>\n", queuedURL];
	
	return settingsXML;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"TERMS"])
	{
		[self setRequiredTerms:[[[settingDict objectForKey:@"REQUIRED"] description] stringByUnescapingXMLEntites]];
		[self setOptionalTerms:[[[settingDict objectForKey:@"OPTIONAL"] description] stringByUnescapingXMLEntites]];
		[self setExcludedTerms:[[[settingDict objectForKey:@"EXCLUDED"] description] stringByUnescapingXMLEntites]];
	}
	else if ([settingType isEqualToString:@"COLOR_SPACE"])
	{
		NSString	*filterValue = [[settingDict objectForKey:@"FILTER"] description];
		
		if ([filterValue isEqualToString:@"ANY"])
			[self setColorSpace:anyColorSpace];
		else if ([filterValue isEqualToString:@"RGB"])
			[self setColorSpace:rgbColorSpace];
		else if ([filterValue isEqualToString:@"GRAYSCALE"])
			[self setColorSpace:grayscaleColorSpace];
		else if ([filterValue isEqualToString:@"B&W"])
			[self setColorSpace:blackAndWhiteColorSpace];
	}
	else if ([settingType isEqualToString:@"SITE"])
		[self setSiteString:[[[settingDict objectForKey:@"FILTER"] description] stringByUnescapingXMLEntites]];
	else if ([settingType isEqualToString:@"ADULT_CONTENT"])
	{
		NSString	*filterValue = [[settingDict objectForKey:@"FILTER"] description];
		
		if ([filterValue isEqualToString:@"STRICT"])
			[self setAdultContentFiltering:strictFiltering];
		else if ([filterValue isEqualToString:@"MODERATE"])
			[self setAdultContentFiltering:moderateFiltering];
		else if ([filterValue isEqualToString:@"NONE"])
			[self setAdultContentFiltering:noFiltering];
	}
	else if ([settingType isEqualToString:@"PAGE"])
		startIndex = [[[settingDict objectForKey:@"INDEX"] description] intValue];
	else if ([settingType isEqualToString:@"QUEUED_IMAGE"])
		[imageURLQueue addObject:[[settingDict objectForKey:@"URL"] description]];
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	// not needed
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
	[self updateQueryAndDescriptor];
}


- (void)updateQueryAndDescriptor
{
	[urlBase autorelease];
	urlBase = [[NSMutableString stringWithString:@"http://images.google.com/images?svnum=10&hl=en&"] retain];
	[descriptor autorelease];
	descriptor = [[NSMutableString string] retain];
	
	if ([requiredTerms length] > 0)
	{
		[urlBase appendString:[NSString stringWithFormat:@"as_q=%@&", escapedNSString(requiredTerms)]];
		[descriptor appendString:requiredTerms];
	}
	
	if ([optionalTerms length] > 0)
	{
		[urlBase appendString:[NSString stringWithFormat:@"as_oq=%@&", escapedNSString(optionalTerms)]];
		if ([descriptor length] > 0)
			[descriptor appendString:@" and any of "];
		else
			[descriptor appendString:@"Any of "];
		[descriptor appendString:optionalTerms];
	}
	
	if ([excludedTerms length] > 0)
	{
		[urlBase appendString:[NSString stringWithFormat:@"as_eq=%@&", escapedNSString(excludedTerms)]];
		if ([descriptor length] > 0)
			[descriptor appendString:@" but not "];
		else
			[descriptor appendString:@"Not "];
		[descriptor appendString:excludedTerms];
	}
	
	switch (colorSpace)
	{
		case anyColorSpace:
			[urlBase appendString:@"imgc=&"];
			break;
		case rgbColorSpace:
			[urlBase appendString:@"imgc=color&"];
			if ([descriptor length] > 0)
				[descriptor appendString:@" color"];
			else
				[descriptor appendString:@"Color"];
			break;
		case grayscaleColorSpace:
			[urlBase appendString:@"imgc=gray&"];
			if ([descriptor length] > 0)
				[descriptor appendString:@" grayscale"];
			else
				[descriptor appendString:@"Grayscale"];
			break;
		case blackAndWhiteColorSpace:
			[urlBase appendString:@"imgc=mono&"];
			if ([descriptor length] > 0)
				[descriptor appendString:@" black & white"];
			else
				[descriptor appendString:@"Black & white"];
			break;
	}
	
	if ([siteString length] > 0)
	{
		[urlBase appendString:[NSString stringWithFormat:@"as_sitesearch=%@&", escapedNSString(siteString)]];
		if ([descriptor length] > 0)
			[descriptor appendString:@" images from "];
		else
			[descriptor appendString:@"Images from "];
		[descriptor appendString:siteString];
	}
	else
		[descriptor appendString:@" images"];
	
	switch (adultContentFiltering)
	{
		case strictFiltering:
			[urlBase appendString:@"safe=active&"]; break;
		case moderateFiltering:
			[urlBase appendString:@"safe=images&"]; break;
		case noFiltering:
			[urlBase appendString:@"safe=off&"]; break;
	}
	[urlBase appendString:@"start="];
}


- (void)setRequiredTerms:(NSString *)terms
{
	[requiredTerms autorelease];
	requiredTerms = [terms copy];
	
	[self updateQueryAndDescriptor];
}


- (NSString *)requiredTerms
{
	return requiredTerms;
}


- (void)setOptionalTerms:(NSString *)terms
{
	[optionalTerms autorelease];
	optionalTerms = [terms copy];
	
	[self updateQueryAndDescriptor];
}


- (NSString *)optionalTerms
{
	return optionalTerms;
}


- (void)setExcludedTerms:(NSString *)terms
{
	[excludedTerms autorelease];
	excludedTerms = [terms copy];
	
	[self updateQueryAndDescriptor];
}


- (NSString *)excludedTerms
{
	return excludedTerms;
}


- (void)setColorSpace:(GoogleColorSpace)inColorSpace
{
	colorSpace = inColorSpace;
	
	[self updateQueryAndDescriptor];
}


- (GoogleColorSpace)colorSpace
{
	return colorSpace;
}


- (void)setSiteString:(NSString *)string
{
	[siteString autorelease];
	siteString = [string copy];
	
	[self updateQueryAndDescriptor];
}


- (NSString *)siteString
{
	return siteString;
}


- (void)setAdultContentFiltering:(GoogleAdultContentFiltering)filtering
{
	adultContentFiltering = filtering;
	
	[self updateQueryAndDescriptor];
}


- (GoogleAdultContentFiltering)adultContentFiltering
{
	return adultContentFiltering;
}


- (void)reset
{
	[imageURLQueue removeAllObjects];
	startIndex = 0;
}


- (NSImage *)image;
{
    return googleIcon;
}


- (id)descriptor
{
    return descriptor;
}


- (void)populateImageQueueFromNextPage
{
	while ([imageURLQueue count] == 0 && startIndex >= 0)
	{
		NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
		NSString			*nextPage = [urlBase stringByAppendingString:[NSString stringWithFormat:@"%d", startIndex]];
		NSString			*URLcontent = [NSString stringWithContentsOfURL:[NSURL URLWithString:nextPage]];
		
		if (URLcontent)
		{
				// break up the HTML by img tags and look for image URLs
			NSEnumerator	*tagEnumerator = [[URLcontent componentsSeparatedByString:@"<img "] objectEnumerator];
			NSString		*tag = nil;
			
			[tagEnumerator nextObject];	// The first item didn't start with "<img ", the rest do.
			while (tag = [tagEnumerator nextObject])
			{
					// Find where the image URL starts.
				NSRange		src = [tag rangeOfString:@"src="];
				tag = [tag substringWithRange:NSMakeRange(src.location + 4, [tag length] - src.location - 4)];
				
					// Find where the image URL ends
				src = [tag rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" \">"]];
				if (src.location != NSNotFound)
					src.length = src.location;
				else
					src.length = [tag length];
				src.location = 0;
				
					// If the URL has the expected prefix then add it to the queue.
				NSString	*imageURL = [tag substringWithRange:src];
				if ([imageURL hasPrefix:@"/images?q="])
					[imageURLQueue addObject:[imageURL substringToIndex:([[imageURL substringFromIndex:1] rangeOfString:@"/"].location + 1)]];
			}
			
				// Check if there are any more pages of search results.
			if ([URLcontent rangeOfString:@"nav_next.gif"].location == NSNotFound)
				startIndex = -1;	// This was the last page of search results.
			else
				startIndex += 20;
		}
		[pool release];
	}
}


- (BOOL)hasMoreImages
{
	return ([imageURLQueue count] > 0 || startIndex >= 0);
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	NSImage		*image = nil;
    
	do
	{
		if ([imageURLQueue count] == 0)
			[self populateImageQueueFromNextPage];
		else
		{
				// Get the image for the first identifier in the queue.
			image = [self imageForIdentifier:[imageURLQueue objectAtIndex:0]];
			if (image)
				*identifier = [[[imageURLQueue objectAtIndex:0] retain] autorelease];
			[imageURLQueue removeObjectAtIndex:0];
		}
	} while (!image && [self hasMoreImages]);
	
	return image;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	NSImage		*image = nil;
	
	if ([identifier length] > 26)
	{
			// First check if we have this image in the cache.
		image = [GoogleImageSource cachedImageWithIdentifier:identifier];
		
			// If the image couldn't be read from the cache then fetch it from Google.
		if (!image)
		{
				// TODO: Try to get the higher res image from the original site and only fallback 
				//       to Google's copy if that fails.
			NSURL	*imageURL = [self urlForIdentifier:identifier];
			NSData	*imageData = [[NSData alloc] initWithContentsOfURL:imageURL];
			
			if (imageData)
			{
				image = [[[NSImage alloc] initWithData:imageData] autorelease];
				
				if (image)
					[GoogleImageSource cacheImageData:imageData withIdentifier:identifier];
				
				[imageData release];
			}
		}
	}
	
    return image;
}


- (NSURL *)urlForIdentifier:(NSString *)identifier
{
	return [NSURL URLWithString:[NSString stringWithFormat:@"http://images.google.com%@", identifier]];
}	


- (NSURL *)contextURLForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (NSString *)descriptionForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (void)dealloc
{
	[requiredTerms release];
	[optionalTerms release];
	[excludedTerms release];
	[siteString release];
	
	[imageURLQueue release];
	
	[super dealloc];
}


@end

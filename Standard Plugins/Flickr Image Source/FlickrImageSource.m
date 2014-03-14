/*
	FlickrImageSource.m
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "FlickrImageSource.h"
#import "FlickrImageSourceController.h"
#import "FlickrPreferencesController.h"
#import "MacOSaiXFlickrGroup.h"

#import "NSData+MacOSaiX.h"
#import "NSString+MacOSaiX.h"

#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <netdb.h>
#import <sys/time.h>
#import <sys/stat.h>
#import <sys/mount.h>


NSString	*MacOSaiXFlickrFavoriteGroupsDidChangeNotification = @"MacOSaiXFlickrFavoriteGroupsDidChangeNotification";
NSString	*MacOSaiXFlickrShowFavoriteGroupsNotification = @"MacOSaiXFlickrShowFavoriteGroupsNotification";
NSString	*MacOSaiXFlickrAuthenticationDidChangeNotification = @"MacOSaiXFlickrAuthenticationDidChangeNotification";


	// The image cache is shared between all instances so we need a class level lock.
static NSRecursiveLock		*sImageCacheLock = nil;
static BOOL					sPruningCache = NO, 
							sPurgeCache = NO;
static unsigned long long	sCacheSize = 0, 
							sMaxCacheSize = 128 * 1024 * 1024,
							sMinFreeSpace = 1024 * 1024 * 1024;

static NSString				*sAuthFrob = nil, 
							*sAuthToken = nil, 
							*sAuthUserName = nil;
static int					sAuthAttempts = 0;
static NSRecursiveLock		*sAuthLock = nil;

static NSMutableArray		*sFavoriteGroups = nil;

static NSImage				*fIcon = nil,
							*flickrIcon = nil;


NSString *escapedNSString(NSString *string)
{
	NSString	*escapedString = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, 
																					 NULL, NULL, kCFStringEncodingUTF8);
	return [escapedString autorelease];
}


static NSComparisonResult compareWithKey(NSDictionary	*dict1, NSDictionary *dict2, void *context)
{
	return [(NSNumber *)[dict1 objectForKey:context] compare:(NSNumber *)[dict2 objectForKey:context]];
}


@interface FlickrImageSource (PrivateMethods)
+ (void)pruneCache;
+ (void)pruneCacheInThread;
+ (id)preferredValueForKey:(NSString *)key;
@end


@implementation FlickrImageSource


+ (void)load
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	sImageCacheLock = [[NSRecursiveLock alloc] init];
	
	NSString	*iconPath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"f"];
	fIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	
	iconPath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"flickr"];
	flickrIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
	
	NSNumber	*maxCacheSize = [self preferredValueForKey:@"Maximum Cache Size"],
				*minFreeSpace = [self preferredValueForKey:@"Minimum Free Space On Cache Volume"];
	
	if (maxCacheSize)
		sMaxCacheSize = [maxCacheSize unsignedLongLongValue];
	if (minFreeSpace)
		sMinFreeSpace = [minFreeSpace unsignedLongLongValue];
	
	[pool release];
}


+ (void)initialize;
{
	// Do an initial prune which also gets the current size of the cache.
	// No new images can be cached until this completes but images can be read from the cache.
//	[self pruneCache];
	
	sAuthLock = [[NSRecursiveLock alloc] init];
}


+ (NSImage *)image;
{
    return fIcon;
}


+ (Class)editorClass
{
	return [FlickrImageSourceController class];
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


#pragma mark -
#pragma mark Image cache


+ (NSString *)imageCachePath
{
	static NSString	*imageCachePath = nil;
	
	if (!imageCachePath)
	{
		FSRef		cachesRef;
		
		if (FSFindFolder(kUserDomain, kCachedDataFolderType, kCreateFolder, &cachesRef) == noErr)
		{
			CFURLRef		cachesURLRef = CFURLCreateFromFSRef(kCFAllocatorDefault, &cachesRef);
			
			if (cachesURLRef)
			{
				imageCachePath = [[[(NSURL *)cachesURLRef path] stringByAppendingPathComponent:@"MacOSaiX"] retain];
				CFRelease(cachesURLRef);
			}
		}
		
		if (!imageCachePath)
			imageCachePath = [[[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] 
												   stringByAppendingPathComponent:@"Caches"]
												   stringByAppendingPathComponent:@"MacOSaiX"] retain];
		
		// Get rid of any folder at the the old location.
		NSString	*oldPath = [imageCachePath stringByAppendingString:@" Flickr Images"];
		if ([[NSFileManager defaultManager] fileExistsAtPath:oldPath])
			[[NSFileManager defaultManager] removeFileAtPath:oldPath handler:nil];
		
		if (imageCachePath && ![[NSFileManager defaultManager] fileExistsAtPath:imageCachePath])
			[[NSFileManager defaultManager] createDirectoryAtPath:imageCachePath attributes:nil];
		
		imageCachePath = [[imageCachePath stringByAppendingPathComponent:@"Flickr Images"] retain];
		if (imageCachePath && ![[NSFileManager defaultManager] fileExistsAtPath:imageCachePath])
			[[NSFileManager defaultManager] createDirectoryAtPath:imageCachePath attributes:nil];
	}
	
	return imageCachePath;
}


+ (NSString *)cachedFileNameForIdentifier:(NSString *)identifier
{
	NSArray		*identifierComponents = [identifier componentsSeparatedByString:@"\t"];
	NSString	*serverID = [identifierComponents objectAtIndex:0], 
				*photoID = [identifierComponents objectAtIndex:1];
	
	return [NSString stringWithFormat:@"%@-%@.jpg", serverID, photoID];
}


+ (void)cacheImageData:(NSData *)imageData withIdentifier:(NSString *)identifier
{
	if (!sPruningCache)
	{
		NSString	*imageFileName = [self cachedFileNameForIdentifier:identifier];

		[sImageCacheLock lock];
		
			if (sCacheSize == 0)
				[self pruneCacheInThread];
			
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
	NSString	*imageFileName = [self cachedFileNameForIdentifier:identifier];
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
		int					purgeCount = 0;
		while (!sPurgeCache && (sCacheSize > targetSize || freeSpace < sMinFreeSpace) && [imageArray count] > 0)
		{
			NSDictionary		*imageToDelete = [imageArray lastObject];
			unsigned long long	fileSize = [[imageToDelete objectForKey:@"Size"] unsignedLongLongValue];
			
			[fileManager removeFileAtPath:[imageToDelete objectForKey:@"Path"] handler:nil];
			sCacheSize -= fileSize;
			freeSpace += fileSize;
			
			[imageArray removeLastObject];
			purgeCount++;
		}
		#ifdef DEBUG
			if (purgeCount > 0)
				NSLog(@"Purged %d images from the flickr cache.", purgeCount);
		#endif
		
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


#pragma mark -
#pragma mark Preferences


+ (Class)preferencesControllerClass
{
	return [FlickrPreferencesController class];
}


+ (void)setPreferredValue:(id)value forKey:(NSString *)key
{
		// NSUserDefaults is not thread safe.  Make sure we set the default on the main thread.
	[self performSelectorOnMainThread:@selector(setPreferredValueOnMainThread:) 
						   withObject:[NSDictionary dictionaryWithObject:(value ? value : [NSNull null]) forKey:key] 
						waitUntilDone:NO];
}


+ (void)setPreferredValueOnMainThread:(NSDictionary *)keyValuePair
{
		// Save all of the preferences for this plug-in in a dictionary within the main prefs dictionary.
	NSMutableDictionary	*flickrPrefs = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Flickr Image Source"] mutableCopy] autorelease];
	if (!flickrPrefs)
		flickrPrefs = [NSMutableDictionary dictionary];
	
	NSString	*key = [[keyValuePair allKeys] lastObject];
	id			value = [keyValuePair objectForKey:key];
	
	if ([value isKindOfClass:[NSNull class]])
		[flickrPrefs removeObjectForKey:key];
	else
		[flickrPrefs setObject:value forKey:key];
	
	[[NSUserDefaults standardUserDefaults] setObject:flickrPrefs forKey:@"Flickr Image Source"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


+ (id)preferredValueForKey:(NSString *)key
{
		// This should be done on the main thread, too, but it could deadlock since we would need to wait for return.
	return [[[NSUserDefaults standardUserDefaults] objectForKey:@"Flickr Image Source"] objectForKey:key];
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


#pragma mark -
#pragma mark Favorite groups


+ (NSArray *)favoriteGroups
{
	// TODO: thread safety
	
	if (!sFavoriteGroups)
	{
		sFavoriteGroups = [[NSMutableArray alloc] init];
		
		NSEnumerator	*groupDictEnumerator = [[self preferredValueForKey:@"Favorite Groups"] objectEnumerator];
		NSDictionary	*groupDict = nil;
		while (groupDict = [groupDictEnumerator nextObject])
			[sFavoriteGroups addObject:[MacOSaiXFlickrGroup groupWithName:[groupDict objectForKey:@"Name"] 
																  groupID:[groupDict objectForKey:@"ID"] 
																 is18Plus:[[groupDict objectForKey:@"18+"] boolValue]]];
		
		[sFavoriteGroups sortUsingSelector:@selector(compare:)];
	}
	
	return [NSArray arrayWithArray:sFavoriteGroups];
}


+ (void)saveFavoriteGroups
{
	NSMutableArray		*archivedGroups = [NSMutableArray array];
	NSEnumerator		*groupEnumerator = [sFavoriteGroups objectEnumerator];
	MacOSaiXFlickrGroup	*group = nil;
	
	while (group = [groupEnumerator nextObject])
		[archivedGroups addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										[group groupID], @"ID", 
										[group name], @"Name", 
										[NSNumber numberWithBool:[group is18Plus]], @"18+", 
										nil]];
	
	[self setPreferredValue:archivedGroups forKey:@"Favorite Groups"];
}


+ (void)addFavoriteGroup:(MacOSaiXFlickrGroup *)group
{
	// TODO: thread safety
	
	[sFavoriteGroups addObject:group];
	[sFavoriteGroups sortUsingSelector:@selector(compare:)];
	[self saveFavoriteGroups];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXFlickrFavoriteGroupsDidChangeNotification object:nil];
}


+ (void)removeFavoriteGroup:(MacOSaiXFlickrGroup *)group
{
	// TODO: thread safety
	
	[sFavoriteGroups removeObject:group];
	[self saveFavoriteGroups];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXFlickrFavoriteGroupsDidChangeNotification object:nil];
}


#pragma mark -
#pragma mark flickr authentication


+ (NSString *)flickrAPIKey
{
	return @"514c14062bc75c91688dfdeacc6252c7";
}


+ (NSString *)flickrSignature
{
	return @"afa9fd8d21f74989";
}


void *createGetFrobStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	volatile id			newObject = nil;
	
	NS_DURING
		if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeElement)
			newObject = info;
		else if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeText)
		{
			NSMutableDictionary	*contextDict = info;
			
			[contextDict setObject:(NSString *)CFXMLNodeGetString(node) forKey:@"frob"];
			
			newObject = contextDict;
		}
	NS_HANDLER
		CFXMLParserAbort(parser, kCFXMLErrorMalformedStartTag, 
						 (CFStringRef)[NSString stringWithFormat:@"Could not create structure (%@)", [localException reason]]);
	NS_ENDHANDLER
	
	[pool release];
	
		// Return the object that will be passed to the addChild and endStructure callbacks.
	return (void *)newObject;
}


void addGetFrobChild(CFXMLParserRef parser, void *parent, void *child, void *info)
{
}


void endGetFrobStructure(CFXMLParserRef parser, void *newObject, void *info)
{
}


+ (NSError *)getAuthFrob
{
	// Docs at http://www.flickr.com/services/api/flickr.auth.getFrob.html
	
	NSError					*error = nil;
	WSMethodInvocationRef	getFrobInvocation = WSMethodInvocationCreate((CFURLRef)[NSURL URLWithString:@"http://www.flickr.com/services/xmlrpc/"],
																		 CFSTR("flickr.auth.getFrob"),
																		 kWSXMLRPCProtocol);
	NSDictionary			*getFrobParameters = [self authenticatedParameters:[NSDictionary dictionaryWithObject:@"flickr.auth.getFrob" forKey:@"method"]];
	
	WSMethodInvocationSetParameters(getFrobInvocation, (CFDictionaryRef)[NSDictionary dictionaryWithObject:getFrobParameters forKey:@"foo"], nil);
	CFDictionaryRef			getFrobResults = WSMethodInvocationInvoke(getFrobInvocation);
	
	if (WSMethodResultIsFault(getFrobResults))
		error = [FlickrImageSource errorFromWSMethodResults:(NSDictionary *)getFrobResults];
	else
	{
			// Create a parser with the option to skip whitespace.
		NSString				*xmlString = [(NSDictionary *)getFrobResults objectForKey:(NSString *)kWSMethodInvocationResult];
		NSData					*xmlData = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
		CFXMLParserCallBacks	callbacks = {0, createGetFrobStructure, addGetFrobChild, endGetFrobStructure, NULL, NULL};
		NSMutableDictionary		*contextDict = [NSMutableDictionary dictionary];
		CFXMLParserContext		context = {0, contextDict, NULL, NULL, NULL};
		CFXMLParserRef			getFrobParser = CFXMLParserCreate(kCFAllocatorDefault, 
																  (CFDataRef)xmlData, 
																  NULL, // data source URL for resolving external refs
																  kCFXMLParserSkipWhitespace, 
																  kCFXMLNodeCurrentVersion, 
																  &callbacks, 
																  &context);
		
			// Invoke the parser.
		if (!CFXMLParserParse(getFrobParser))
		{
				// An error occurred parsing the XML.
			NSString	*parserError = (NSString *)CFXMLParserCopyErrorDescription(getFrobParser);
			
			NSString	*errorMessage = [NSString stringWithFormat:@"Error at line %d: %@", CFXMLParserGetLineNumber(getFrobParser), parserError];
			
			error = [NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				errorMessage, NSLocalizedDescriptionKey, 
				nil]];
			
			[parserError release];
		}
		else
		{
			[sAuthLock lock];
				sAuthFrob = [[contextDict objectForKey:@"frob"] retain];
			[sAuthLock unlock];
		}
		
		CFRelease(getFrobParser);
	}
	
	CFRelease(getFrobResults);
	
	return error;
}


void *createGetTokenStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	volatile id			newObject = nil;
	
	NS_DURING
		if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeElement)
		{
			NSString	*nodeName = (NSString *)CFXMLNodeGetString(node);
			
			if ([nodeName isEqualToString:@"user"])
			{
				CFXMLElementInfo	*nodeInfo = (CFXMLElementInfo *)CFXMLNodeGetInfoPtr(node);
				
				[(NSMutableDictionary *)info setObject:[(NSDictionary *)nodeInfo->attributes objectForKey:@"fullname"] forKey:@"fullname"];
			}
			else if ([nodeName isEqualToString:@"token"])
				newObject = @"token";
			else
				newObject = info;
		}
		else if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeText)
			newObject = (NSString *)CFXMLNodeGetString(node);
	NS_HANDLER
		CFXMLParserAbort(parser, kCFXMLErrorMalformedStartTag, 
						 (CFStringRef)[NSString stringWithFormat:@"Could not create structure (%@)", [localException reason]]);
	NS_ENDHANDLER
	
	[pool release];
	
		// Return the object that will be passed to the addChild and endStructure callbacks.
	return (void *)newObject;
}


void addGetTokenChild(CFXMLParserRef parser, void *parent, void *child, void *info)
{
	if ([(id)parent isKindOfClass:[NSString class]] && [(NSString *)parent isEqualToString:@"token"])
		[(NSMutableDictionary *)info setObject:[NSString stringWithString:(NSString *)child] forKey:@"token"];
}


void endGetTokenStructure(CFXMLParserRef parser, void *newObject, void *info)
{
}


+ (NSError *)getAuthToken
{
	// Docs at http://www.flickr.com/services/api/flickr.auth.getToken.html
	
	NSError					*error = nil;
	WSMethodInvocationRef	getTokenInvocation = WSMethodInvocationCreate((CFURLRef)[NSURL URLWithString:@"http://www.flickr.com/services/xmlrpc/"],
																		  CFSTR("flickr.auth.getToken"),
																		  kWSXMLRPCProtocol);
	NSDictionary			*getTokenParameters = [self authenticatedParameters:[NSDictionary dictionaryWithObjectsAndKeys:
																					@"flickr.auth.getToken", @"method", 
																					sAuthFrob, @"frob", 
																					nil]];
	
	WSMethodInvocationSetParameters(getTokenInvocation, (CFDictionaryRef)[NSDictionary dictionaryWithObject:getTokenParameters forKey:@"foo"], nil);
	CFDictionaryRef			getTokenResults = WSMethodInvocationInvoke(getTokenInvocation);
	
	if (WSMethodResultIsFault(getTokenResults))
		error = [FlickrImageSource errorFromWSMethodResults:(NSDictionary *)getTokenResults];
	else
	{
			// Create a parser with the option to skip whitespace.
		NSString				*xmlString = [(NSDictionary *)getTokenResults objectForKey:(NSString *)kWSMethodInvocationResult];
		NSData					*xmlData = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
		CFXMLParserCallBacks	callbacks = {0, createGetTokenStructure, addGetTokenChild, endGetTokenStructure, NULL, NULL};
		NSMutableDictionary		*contextDict = [NSMutableDictionary dictionary];
		CFXMLParserContext		context = {0, contextDict, NULL, NULL, NULL};
		CFXMLParserRef			getTokenParser = CFXMLParserCreate(kCFAllocatorDefault, 
																   (CFDataRef)xmlData, 
																   NULL, // data source URL for resolving external refs
																   kCFXMLParserSkipWhitespace, 
																   kCFXMLNodeCurrentVersion, 
																   &callbacks, 
																   &context);
		
			// Invoke the parser.
		if (!CFXMLParserParse(getTokenParser))
		{
				// An error occurred parsing the XML.
			NSString	*parserError = (NSString *)CFXMLParserCopyErrorDescription(getTokenParser);
			
			NSString	*errorMessage = [NSString stringWithFormat:@"Error at line %d: %@", CFXMLParserGetLineNumber(getTokenParser), parserError];
			
			error = [NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				errorMessage, NSLocalizedDescriptionKey, 
				nil]];
			
			[parserError release];
		}
		else
		{
			sAuthToken = [[contextDict objectForKey:@"token"] retain];
			[self setPreferredValue:sAuthToken forKey:@"Auth Token"];
			sAuthUserName = [[contextDict objectForKey:@"fullname"] retain];
		}
		
		CFRelease(getTokenParser);
	}
	
	CFRelease(getTokenResults);
	
	return error;
}


+ (NSError *)checkAuthToken
{
	// Docs at http://www.flickr.com/services/api/flickr.auth.checkToken.html
	
	NSError					*error = nil;
	WSMethodInvocationRef	checkTokenInvocation = WSMethodInvocationCreate((CFURLRef)[NSURL URLWithString:@"http://www.flickr.com/services/xmlrpc/"],
																			CFSTR("flickr.auth.checkToken"),
																			kWSXMLRPCProtocol);
	NSDictionary			*checkTokenParameters = [self authenticatedParameters:[NSDictionary dictionaryWithObjectsAndKeys:
																						@"flickr.auth.checkToken", @"method", 
																						sAuthToken, @"auth_token", 
																						nil]];
	
	WSMethodInvocationSetParameters(checkTokenInvocation, (CFDictionaryRef)[NSDictionary dictionaryWithObject:checkTokenParameters forKey:@"foo"], nil);
	CFDictionaryRef			checkTokenResults = WSMethodInvocationInvoke(checkTokenInvocation);
	
	if (WSMethodResultIsFault(checkTokenResults))
	{
		[sAuthToken release];
		sAuthToken = nil;
	}
	else
	{
			// Create a parser with the option to skip whitespace.
		NSString				*xmlString = [(NSDictionary *)checkTokenResults objectForKey:(NSString *)kWSMethodInvocationResult];
		NSData					*xmlData = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
		CFXMLParserCallBacks	callbacks = {0, createGetTokenStructure, addGetTokenChild, endGetTokenStructure, NULL, NULL};
		NSMutableDictionary		*contextDict = [NSMutableDictionary dictionary];
		CFXMLParserContext		context = {0, contextDict, NULL, NULL, NULL};
		CFXMLParserRef			checkTokenParser = CFXMLParserCreate(kCFAllocatorDefault, 
																	 (CFDataRef)xmlData, 
																	 NULL, // data source URL for resolving external refs
																	 kCFXMLParserSkipWhitespace, 
																	 kCFXMLNodeCurrentVersion, 
																	 &callbacks, 
																	 &context);
		
			// Invoke the parser.
		if (!CFXMLParserParse(checkTokenParser))
		{
				// An error occurred parsing the XML.
			NSString	*parserError = (NSString *)CFXMLParserCopyErrorDescription(checkTokenParser);
			
			NSString	*errorMessage = [NSString stringWithFormat:@"Error at line %d: %@", CFXMLParserGetLineNumber(checkTokenParser), parserError];
			
			error = [NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				errorMessage, NSLocalizedDescriptionKey, 
				nil]];
			
			[parserError release];
		}
		else
			sAuthUserName = [[contextDict objectForKey:@"fullname"] retain];
		
		CFRelease(checkTokenParser);
	}
	
	CFRelease(checkTokenResults);
	
	return error;
}


+ (NSString *)apiSigForMethodCallWithParameters:(NSDictionary *)parameters
{
	NSMutableString		*signature = [NSMutableString stringWithString:[self flickrSignature]];
	
	NSEnumerator		*parameterEnumerator = [[[parameters allKeys] sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
	NSString			*parameter = nil;
	while (parameter = [parameterEnumerator nextObject])
	{
		[signature appendString:parameter];
		[signature appendString:[parameters objectForKey:parameter]];
	}
	
	return [[signature dataUsingEncoding:NSUTF8StringEncoding] checksum];
}


+ (NSDictionary *)authenticatedParameters:(NSDictionary *)parameters
{
	NSMutableDictionary	*authenticatedParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
	
	[authenticatedParameters setObject:[self flickrAPIKey] forKey:@"api_key"];
	if (sAuthToken)
		[authenticatedParameters setObject:sAuthToken forKey:@"auth_token"];
	[authenticatedParameters setObject:[self apiSigForMethodCallWithParameters:authenticatedParameters] forKey:@"api_sig"];
	
	return authenticatedParameters;
}


+ (NSError *)signIn
{
	NSError	*error = nil;
	
	[sAuthLock lock];
	
	if (!sAuthToken)
	{
		sAuthToken = [[self preferredValueForKey:@"Auth Token"] retain];

		if (sAuthToken)
		{
			error = [self checkAuthToken];
			
			if (error)
			{
				[sAuthToken release];
				sAuthToken = nil;
				
				if ([error code] == 98)
					[self setPreferredValue:nil forKey:@"Auth Token"];
			}
			else
				[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXFlickrAuthenticationDidChangeNotification object:nil];
		}
	}

	if (!error && !sAuthToken)
	{
		error = [self getAuthFrob];
		
		if (sAuthFrob)
		{
			if (NSRunAlertPanel(@"You need to authorize MacOSaiX to access your flickr account." , @"Authorizing is a simple process that takes place in your web browser.  Return to MacOSaiX when you're finished.", @"Authorize", @"Cancel", nil) == NSAlertDefaultReturn)
			{
				NSDictionary	*parameters = [NSDictionary dictionaryWithObjectsAndKeys:
													[self flickrAPIKey], @"api_key", 
													sAuthFrob, @"frob", 
													@"read", @"perms", 
													nil];
				NSString		*apiSig = [FlickrImageSource apiSigForMethodCallWithParameters:parameters], 
								*authorizationURL = [NSString stringWithFormat:@"http://flickr.com/services/auth/?api_key=%@&perms=read&frob=%@&api_sig=%@", [self flickrAPIKey], sAuthFrob, apiSig];
				
				if ([[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:authorizationURL]])
				{
						// Wait for the user to authenticate MacOSaiX in their web browser.
					sAuthAttempts = 0;
					[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkIfSignedIn:) userInfo:nil repeats:NO];
				}
				else
				{
					[sAuthFrob release];
					sAuthFrob = nil;
					
					error = [NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																			@"The flickr authorization page could not be opened.", NSLocalizedDescriptionKey, 
																			nil]];
				}
			}
			else
			{
				[sAuthFrob release];
				sAuthFrob = nil;
				
				error = [NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																		@"MacOSaiX is not authorized to access your flickr account.", NSLocalizedDescriptionKey, 
																		nil]];
			}
		}
	}
	
	[sAuthLock unlock];
	
	return error;
}


+ (void)checkIfSignedIn:(NSTimer *)timer
{
	[sAuthLock lock];
	
		// Try to sign in.
	NSError	*error = [self getAuthToken], 
			*underlyingError = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
	
	if (!error)
	{
			// Sign in succeeded.
		[sAuthFrob release];
		sAuthFrob = nil;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXFlickrAuthenticationDidChangeNotification object:nil];
	}
	else if ([underlyingError code] == 108 && sAuthAttempts < 15)
	{
			// Keep trying to sign in.  The user may still be reading the authorization page.
		sAuthAttempts++;
		[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkIfSignedIn:) userInfo:nil repeats:NO];
	}
	else
	{
			// Stop trying to sign in.
		[sAuthFrob release];
		sAuthFrob = nil;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXFlickrAuthenticationDidChangeNotification object:nil];
	}
	
	[sAuthLock unlock];
}


+ (void)signOut
{
	[sAuthLock lock];
		[sAuthFrob release];
		sAuthFrob = nil;
		[sAuthToken release];
		sAuthToken = nil;
		[sAuthUserName release];
		sAuthUserName = nil;
		
		[self setPreferredValue:nil forKey:@"Auth Token"];
	[sAuthLock unlock];
}


+ (BOOL)signingIn
{
	BOOL	signingIn;
	
	[sAuthLock lock];
		signingIn = (sAuthFrob != nil);
	[sAuthLock unlock];
	
	return signingIn;
}


+ (BOOL)signedIn
{
	BOOL	signedIn;
	
	[sAuthLock lock];
		signedIn = (sAuthToken != nil);
	[sAuthLock unlock];
	
	return signedIn;
}


+ (NSString *)signedInUserName
{
	NSString	*userName;
	
	[sAuthLock lock];
		userName = [[sAuthUserName copy] autorelease];
	[sAuthLock unlock];
	
	return userName;
}


#pragma mark -
#pragma mark Web Services utilities


+ (NSError *)errorFromWSMethodResults:(NSDictionary *)resultsDict
{
	NSString			*errorDomain = @"";
	int					errorCode = 0;
	NSMutableDictionary	*userInfo = [NSMutableDictionary dictionary];
	
	if ([[resultsDict objectForKey:(id)kWSFaultString] isEqualToString:(id)kWSNetworkStreamFaultString])
	{
		NSDictionary	*extraDict = [resultsDict objectForKey:(id)kWSFaultExtra];
		int				domainCode = [(NSNumber *)[extraDict objectForKey:(id)kWSStreamErrorDomain] intValue];
		
		errorCode = [(NSNumber *)[extraDict objectForKey:(id)kWSStreamErrorError] intValue];
		
		if (domainCode == kCFStreamErrorDomainPOSIX)
			errorDomain = NSPOSIXErrorDomain;
		else if (domainCode == kCFStreamErrorDomainMacOSStatus)
			errorDomain = NSOSStatusErrorDomain;
		else if (domainCode == kCFStreamErrorDomainNetDB)
		{
			errorDomain = @"NetDB domain";
			[userInfo setObject:[NSString stringWithCString:gai_strerror(errorCode)] forKey:NSLocalizedDescriptionKey];
		}
		else if (domainCode == kCFStreamErrorDomainNetServices)
			errorDomain = @"Net Services domain";
		else if (domainCode == kCFStreamErrorDomainMach)
			errorDomain = NSMachErrorDomain;
		else if (domainCode == kCFStreamErrorDomainFTP)
			errorDomain = @"FTP domain";
		else if (domainCode == kCFStreamErrorDomainHTTP)
			errorDomain = @"HTTP domain";
		else if (domainCode == kCFStreamErrorDomainSOCKS)
			errorDomain = @"SOCKS domain";
		else if (domainCode == kCFStreamErrorDomainSystemConfiguration)
			errorDomain = @"System configuration domain";
		else if (domainCode == kCFStreamErrorDomainSSL)
			errorDomain = @"SSL domain";
		else
			errorDomain = [NSString stringWithFormat:@"Error domain %d", [(NSNumber *)[extraDict objectForKey:(id)kWSStreamErrorDomain] intValue]];
		
		if (![userInfo objectForKey:NSLocalizedDescriptionKey] && [extraDict objectForKey:(id)kWSStreamErrorMessage])
			[userInfo setObject:[extraDict objectForKey:(id)kWSStreamErrorMessage] forKey:NSLocalizedDescriptionKey];
		
	}
	else
	{
		errorDomain = [NSString stringWithFormat:@"Error domain %d", [(NSNumber *)[resultsDict objectForKey:(id)kWSStreamErrorDomain] intValue]];
		errorCode = [(NSNumber *)[resultsDict objectForKey:(id)kWSFaultCode] intValue];
		[userInfo setObject:[resultsDict objectForKey:(id)kWSFaultString] forKey:NSLocalizedDescriptionKey];
	}
	
	NSError	*underlyingError = [NSError errorWithDomain:errorDomain code:errorCode userInfo:userInfo];
	return [NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
															@"Could not contact flickr", NSLocalizedDescriptionKey, 
															underlyingError, NSUnderlyingErrorKey, 
															nil]];
}


#pragma mark -


- (id)init
{
	if (self = [super init])
	{
		if ([[NSFileManager defaultManager] fileExistsAtPath:[[self class] imageCachePath]])
		{
			identifierQueue = [[NSMutableArray array] retain];
			haveMoreImages = YES;
		}
		else
		{
			[self autorelease];
			self = nil;
		}
	}
	
	return self;
}


- (NSString *)settingsAsXMLElement
{
	NSMutableString	*settingsXML = [NSMutableString string];
	
	NSString		*queryTypeXML = nil;
	if ([self queryType] == matchAllTags)
		queryTypeXML = @"All Tags";
	else if ([self queryType] == matchAllTags)
		queryTypeXML = @"Any Tags";
	else
		queryTypeXML = @"Titles, Tags or Descriptions";
	
	NSString		*queryStringXML = ([self queryString] ? [NSString stringWithFormat:@"STRING=\"%@\" ", [[self queryString] stringByEscapingXMLEntites]] : @""), 
					*groupIDXML = ([self queryGroup] ? [NSString stringWithFormat:@"GROUP_ID=\"%@\" ", [[self queryGroup] groupID]] : @"");
		
	[settingsXML appendFormat:@"<QUERY %@TYPE=\"%@\" %@LAST_UPLOAD_TIMESTAMP=\"%@\"/>\n", 
							  queryStringXML, queryTypeXML, groupIDXML, lastUploadTimeStamp];
	
	if ([identifierQueue count] > 0)
	{
		[settingsXML appendString:@"<IDENTIFIER_QUEUE>\n"];
		NSEnumerator	*enumerator = [identifierQueue objectEnumerator];
		NSString		*identifier = nil;
		while (identifier = [enumerator nextObject])
			[settingsXML appendFormat:@"\t<IDENTIFIER ID=\"%@\"/>\n", [identifier stringByEscapingXMLEntites]];
		[settingsXML appendString:@"</IDENTIFIER_QUEUE>\n"];
	}
	
	return settingsXML;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"QUERY"])
	{
		[self setQueryString:[[[settingDict objectForKey:@"STRING"] description] stringByUnescapingXMLEntites]];

		NSString	*queryTypeString = [[settingDict objectForKey:@"TYPE"] description];
		if ([queryTypeString isEqualToString:@"All Tags"])
			[self setQueryType:matchAllTags];
		else if ([queryTypeString isEqualToString:@"Any Tags"])
			[self setQueryType:matchAnyTags];
		else if ([queryTypeString isEqualToString:@"Titles, Tags or Descriptions"])
			[self setQueryType:matchTitlesTagsOrDescriptions];
		
		NSString	*groupIDString = [[settingDict objectForKey:@"GROUP_ID"] description];
		if ([groupIDString length] > 0)
		{
			MacOSaiXFlickrGroup	*group = [MacOSaiXFlickrGroup groupWithName:@"" groupID:groupIDString is18Plus:NO];
			[group populate];
			
			[self setQueryGroup:group];
		}
		
		lastUploadTimeStamp = [[settingDict objectForKey:@"LAST_UPLOAD_TIMESTAMP"] description];
		if ([lastUploadTimeStamp length] > 0)
			[lastUploadTimeStamp retain];
		else
			lastUploadTimeStamp = nil;
	}
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	NSString	*settingType = [childSettingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"IDENTIFIER"])
	{
		NSString	*identifier = [[childSettingDict objectForKey:@"ID"] stringByUnescapingXMLEntites];
		
		if (identifier)
			[identifierQueue addObject:identifier];
	}
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
}


- (void)setQueryString:(NSString *)string
{
	[queryString autorelease];
	queryString = [string copy];
}


- (NSString *)queryString
{
	return queryString;
}


- (void)setQueryType:(FlickrQueryType)type;
{
	queryType = type;
}


- (FlickrQueryType)queryType;
{
	return queryType;
}


- (void)setQueryGroup:(MacOSaiXFlickrGroup *)group
{
	[queryGroup autorelease];
	queryGroup = [group retain];
}


- (MacOSaiXFlickrGroup *)queryGroup
{
	return queryGroup;
}


- (void)reset
{
	[identifierQueue removeAllObjects];
	
	[lastUploadTimeStamp release];
	lastUploadTimeStamp = nil;
	
	haveMoreImages = YES;
}


- (NSImage *)image;
{
    return flickrIcon;
}


- (id)descriptor
{
	NSMutableString	*descriptor = [NSMutableString stringWithString:@"Pictures"];
	
	if (queryString)
		[descriptor appendFormat:@" matching \"%@\"", queryString];
	
	if (queryGroup)
		[descriptor appendFormat:@" in %@", [queryGroup name]];
	
    return descriptor;
}


- (id)copyWithZone:(NSZone *)zone
{
	FlickrImageSource	*copy = [[FlickrImageSource allocWithZone:zone] init];
	
	[copy setQueryString:queryString];
	[copy setQueryType:queryType];
	[copy setQueryGroup:queryGroup];
	
	return copy;
}


// Parser callback prototypes.
void	*createStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info);
void	addChild(CFXMLParserRef parser, void *parent, void *child, void *info);
void	endStructure(CFXMLParserRef parser, void *xmlType, void *info);


- (NSError *)populateImageQueueFromNextPage
{
	/*
		MacOSaiX's flickr API Key: 514c14062bc75c91688dfdeacc6252c7
		
		http://www.flickr.com/services/api/flickr.photos.search.html
	 
		Sorting: interestingness-desc
	*/
	NSError					*error = nil;
	WSMethodInvocationRef	flickrInvocation = WSMethodInvocationCreate((CFURLRef)[NSURL URLWithString:@"http://www.flickr.com/services/xmlrpc/"],
																		CFSTR("flickr.photos.search"),
																		kWSXMLRPCProtocol);
	NSMutableDictionary		*parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												@"1", @"page", 
												@"200", @"per_page", 
												@"date-posted-asc", @"sort", 
												@"date_upload", @"extras", 
												nil];
	
	if (queryString)
	{
		if (queryType == matchAllTags)
		{
			[parameters setObject:queryString forKey:@"tags"];
			[parameters setObject:@"all" forKey:@"tag_mode"];
		}
		else if (queryType == matchAnyTags)
		{
			[parameters setObject:queryString forKey:@"tags"];
			[parameters setObject:@"any" forKey:@"tag_mode"];
		}
		else
			[parameters setObject:queryString forKey:@"text"];
	}
	
	if (queryGroup)
		[parameters setObject:[queryGroup groupID] forKey:@"group_id"];
//	[parameters setObject:@"783349@N22" forKey:@"group_id"];
	
	if (lastUploadTimeStamp)
		[parameters setObject:lastUploadTimeStamp forKey:@"min_upload_date"];
	
	NSDictionary			*wrappedParameters = [NSDictionary dictionaryWithObject:[[self class] authenticatedParameters:parameters] forKey:@"foo"];
	WSMethodInvocationSetParameters(flickrInvocation, (CFDictionaryRef)wrappedParameters, nil);
	CFDictionaryRef			results = WSMethodInvocationInvoke(flickrInvocation);
	
	if (WSMethodResultIsFault(results))
	{
		if ([(NSNumber *)[(NSDictionary *)results objectForKey:(id)kWSFaultCode] intValue] == 4)
		{
			if ([[self class] signedIn])
				haveMoreImages = NO;
			else if (![[self class] signingIn])
				error = [[self class] signIn];
		}
		else
			error = [[self class] errorFromWSMethodResults:(NSDictionary *)results];
	}
	else
	{
			// Create the parser with the option to skip whitespace.
		NSString				*xmlString = [(NSDictionary *)results objectForKey:(NSString *)kWSMethodInvocationResult];
		NSData					*xmlData = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
		CFXMLParserCallBacks	callbacks = {0, createStructure, addChild, endStructure, NULL, NULL};
		NSMutableDictionary		*contextDict = [NSMutableDictionary dictionaryWithObject:identifierQueue
																				  forKey:@"Identifier Queue"];
		CFXMLParserContext		context = {0, contextDict, NULL, NULL, NULL};
		CFXMLParserRef			parser = CFXMLParserCreate(kCFAllocatorDefault, 
														   (CFDataRef)xmlData, 
														   NULL, // data source URL for resolving external refs
														   kCFXMLParserSkipWhitespace, 
														   kCFXMLNodeCurrentVersion, 
														   &callbacks, 
														   &context);
		
			// Invoke the parser.
		if (!CFXMLParserParse(parser))
		{
				// An error occurred parsing the XML.
			NSString	*parserError = [(NSString *)CFXMLParserCopyErrorDescription(parser) autorelease];
			NSString	*errorMessage = [NSString stringWithFormat:@"Error at line %d: %@", CFXMLParserGetLineNumber(parser), parserError];
			
			error = [NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																		errorMessage, NSLocalizedDescriptionKey, 
																		nil]];
		}
		else
		{
			NSString		*dateUploaded = [contextDict objectForKey:@"Last Upload Timestamp"];
			
			if (!dateUploaded)
				haveMoreImages = NO;
			else
			{
				NSDecimalNumber	*timestamp = [[NSDecimalNumber decimalNumberWithString:dateUploaded]
													decimalNumberByAdding:[NSDecimalNumber one]];
				[lastUploadTimeStamp release];
				lastUploadTimeStamp = [[timestamp stringValue] retain];
			}
		}
		
		CFRelease(parser);
	}
	
	CFRelease(results);
	
	return error;
}


void *createStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	volatile id			newObject = nil;
	
	NS_DURING
		NSMutableDictionary	*contextDict = info;
		NSMutableArray		*identifierQueue = [contextDict objectForKey:@"Identifier Queue"];
		
		switch (CFXMLNodeGetTypeCode(node))
		{
			case kCFXMLNodeTypeElement:
			{
				NSString			*elementType = (NSString *)CFXMLNodeGetString(node);
				CFXMLElementInfo	*nodeInfo = (CFXMLElementInfo *)CFXMLNodeGetInfoPtr(node);
				NSDictionary		*nodeAttributes = (NSDictionary *)nodeInfo->attributes;
				
				if ([elementType isEqualToString:@"photos"])
				{
					[contextDict setObject:[nodeAttributes objectForKey:@"pages"] forKey:@"Page Count"];
					
					newObject = identifierQueue;
				}
				else if ([elementType isEqualToString:@"photo"])
				{
					NSString		*serverID = [nodeAttributes objectForKey:@"server"], 
									*photoID = [nodeAttributes objectForKey:@"id"], 
									*secret = [nodeAttributes objectForKey:@"secret"], 
									*owner = [nodeAttributes objectForKey:@"owner"], 
									*dateUploaded = [nodeAttributes objectForKey:@"dateupload"];
					NSMutableString	*title = [nodeAttributes objectForKey:@"title"];
					
						// Clean up the title
					[title replaceOccurrencesOfString:@"\'" withString:@"'" options:0 range:NSMakeRange(0, [title length])];
					[title replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, [title length])];
					[title replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, [title length])];
					[title replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, [title length])];
					[title replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, [title length])];
					[title replaceOccurrencesOfString:@"%20" withString:@" " options:0 range:NSMakeRange(0, [title length])];
					
					newObject = [[NSString stringWithFormat:@"%@\t%@\t%@\t%@\t%@", serverID, photoID, secret, owner, title] retain];
					
					[contextDict setObject:dateUploaded forKey:@"Last Upload Timestamp"];
				}
			}
				
			default:
				;
		}
	NS_HANDLER
		CFXMLParserAbort(parser, kCFXMLErrorMalformedStartTag, 
						 (CFStringRef)[NSString stringWithFormat:@"Could not create structure (%@)", [localException reason]]);
	NS_ENDHANDLER
	
	[pool release];
	
		// Return the object that will be passed to the addChild and endStructure callbacks.
	return (void *)newObject;
}


void addChild(CFXMLParserRef parser, void *parent, void *child, void *info)
{
	if ([(id)parent isKindOfClass:[NSMutableArray class]] && [(id)child isKindOfClass:[NSString class]])
	{
		[(NSMutableArray *)parent addObject:(id)child];
		[(id)child release];
	}
}


void endStructure(CFXMLParserRef parser, void *newObject, void *info)
{
}


- (BOOL)hasMoreImages
{
	return haveMoreImages;
}


- (NSError *)nextImage:(NSImage **)image andIdentifier:(NSString **)identifier
{
	NSError	*error = nil;
	
	*image = nil;
	*identifier = nil;
    
	if (![[self class] signingIn])
	{
		if ([identifierQueue count] == 0)
			error = [self populateImageQueueFromNextPage];
		
		if (!error && [identifierQueue count] > 0)
		{
				// Get the image for the first identifier in the queue.
			*image = [self imageForIdentifier:[identifierQueue objectAtIndex:0]];
			if (*image)
				*identifier = [[[identifierQueue objectAtIndex:0] retain] autorelease];
			[identifierQueue removeObjectAtIndex:0];
		}
	}
	
	return error;
}


- (BOOL)canReenumerateImages
{
	return YES;
}


- (BOOL)canRefetchImages
{
	return YES;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
		// First check if we have this image in the disk cache.
	NSImage		*image = [[self class] cachedImageWithIdentifier:identifier];
	
		// If it's not in the cache then fetch the image from flickr.
	if (!image)
	{
		NSURL	*imageURL = [self urlForIdentifier:identifier];
//		NSData	*imageData = [imageURL resourceDataUsingCache:YES];
		NSData	*imageData = [NSData dataWithContentsOfURL:imageURL options:0 error:nil];
		
		if (imageData)
		{
			image = [[[NSImage alloc] initWithData:imageData] autorelease];
			if ([image isValid])
				[[self class] cacheImageData:imageData withIdentifier:identifier];
			else
			{
				[image autorelease];
				image = nil;
			}
		}
	}
	
    return image;
}


- (NSURL *)urlForIdentifier:(NSString *)identifier
{
	NSArray		*identifierComponents = [identifier componentsSeparatedByString:@"\t"];
	NSString	*serverID = [identifierComponents objectAtIndex:0], 
				*photoID = [identifierComponents objectAtIndex:1],
				*secret = [identifierComponents objectAtIndex:2];
	
	return [NSURL URLWithString:[NSString stringWithFormat:@"http://static.flickr.com/%@/%@_%@.jpg", 
														   serverID, photoID, secret]];
}	


- (NSURL *)contextURLForIdentifier:(NSString *)identifier
{
	NSURL		*contextURL = nil;
	NSArray		*identifierComponents = [identifier componentsSeparatedByString:@"\t"];
	
	if ([identifierComponents count] > 3)
	{
		NSString	*photoID = [identifierComponents objectAtIndex:1],
					*owner = [identifierComponents objectAtIndex:3];
	
		contextURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.flickr.com/photos/%@/%@/", 
										  owner, photoID]];
	}
	
	return contextURL;
}	


- (NSString *)descriptionForIdentifier:(NSString *)identifier
{
	NSString	*description = nil;
	NSArray		*identifierComponents = [identifier componentsSeparatedByString:@"\t"];
	
	if ([identifierComponents count] > 4)
		description = [identifierComponents objectAtIndex:4];
	
	return description;
}	


- (void)dealloc
{
	[queryString release];
	[queryGroup release];
	
	[identifierQueue release];
	[lastUploadTimeStamp release];
	
	[super dealloc];
}


@end

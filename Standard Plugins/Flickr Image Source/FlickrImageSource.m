/*
	FlickrImageSource.m
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "FlickrImageSource.h"
#import "FlickrImageSourceController.h"
#import "FlickrPreferencesController.h"
#import "NSString+MacOSaiX.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <sys/time.h>
#import <sys/stat.h>
#import <sys/mount.h>


	// The image cache is shared between all instances so we need a class level lock.
static NSLock				*sImageCacheLock = nil;
static NSString				*sImageCachePath = nil;
static BOOL					sPruningCache = NO, 
							sPurgeCache = NO;
static unsigned long long	sCacheSize = 0, 
							sMaxCacheSize = 128 * 1024 * 1024,
							sMinFreeSpace = 1024 * 1024 * 1024;

static NSImage				*fIcon = nil,
							*flickrIcon = nil;


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


@interface FlickrImageSource (PrivateMethods)
+ (void)pruneCache;
+ (id)preferredValueForKey:(NSString *)key;
@end


@implementation FlickrImageSource


+ (void)load
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	sImageCachePath = [[[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] 
											stringByAppendingPathComponent:@"Caches"]
											stringByAppendingPathComponent:@"MacOSaiX Flickr Images"] retain];
	if (![[NSFileManager defaultManager] fileExistsAtPath:sImageCachePath])
		[[NSFileManager defaultManager] createDirectoryAtPath:sImageCachePath attributes:nil];
	
	sImageCacheLock = [[NSLock alloc] init];
	
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
	
		// Do an initial prune which also gets the current size of the cache.
		// No new images can be cached until this completes but images can be read from the cache.
	[self pruneCache];
	
	[pool release];
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


#pragma mark
#pragma mark Image cache


+ (NSString *)imageCachePath
{
	return sImageCachePath;
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
		while (!sPurgeCache && (sCacheSize > targetSize || freeSpace < sMinFreeSpace) && [imageArray count] > 0)
		{
			NSDictionary		*imageToDelete = [imageArray lastObject];
			unsigned long long	fileSize = [[imageToDelete objectForKey:@"Size"] unsignedLongLongValue];
			
			#ifdef DEBUG
				NSLog(@"Purging %@", [imageToDelete objectForKey:@"Path"]);
			#endif
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
	return [FlickrPreferencesController class];
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
		if ([[NSFileManager defaultManager] fileExistsAtPath:[[self class] imageCachePath]])
		{
			identifierQueue = [[NSMutableArray array] retain];
			nextPage = 1;
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
	NSString		*queryTypeString = nil;
	
	if ([self queryType] == matchAllTags)
		queryTypeString = @"All Tags";
	else if ([self queryType] == matchAllTags)
		queryTypeString = @"Any Tags";
	else
		queryTypeString = @"Titles, Tags or Descriptions";
	
	[settingsXML appendFormat:@"<QUERY STRING=\"%@\" TYPE=\"%@\"/>\n", 
							  [[self queryString] stringByEscapingXMLEntites], queryTypeString];
	
	[settingsXML appendFormat:@"<PAGE INDEX=\"%d\"/>\n", nextPage];
	
	if ([identifierQueue count] > 0)
	{
		[settingsXML appendString:@"<IDENTIFIER_QUEUE>\n"];
		NSEnumerator	*enumerator = [identifierQueue objectEnumerator];
		NSString		*identifier = nil;
		while (identifier = [enumerator nextObject])
			[settingsXML appendFormat:@"\t<IDENTIFIER>\"%@\"</IDENTIFIER>\n", identifier];
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
		if ([queryTypeString isEqualToString:@"Any Tags"])
			[self setQueryType:matchAnyTags];
		if ([queryTypeString isEqualToString:@"Titles, Tags or Descriptions"])
			[self setQueryType:matchTitlesTagsOrDescriptions];
	}
	else if ([settingType isEqualToString:@"PAGE"])
		nextPage = [[[settingDict objectForKey:@"INDEX"] description] intValue];
//	else if ([settingType isEqualToString:@"QUEUED_IMAGE"])
//		[identifierQueue addObject:[[settingDict objectForKey:@"URL"] description]];
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	// TODO: add queued identifier
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


- (void)reset
{
	[identifierQueue removeAllObjects];
	nextPage = 1;
}


- (NSImage *)image;
{
    return flickrIcon;
}


- (id)descriptor
{
    return queryString;
}


- (id)copyWithZone:(NSZone *)zone
{
	FlickrImageSource	*copy = [[FlickrImageSource allocWithZone:zone] init];
	
	[copy setQueryString:queryString];
	[copy setQueryType:queryType];
	
	return copy;
}


// Parser callback prototypes.
void	*createStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info);
void	addChild(CFXMLParserRef parser, void *parent, void *child, void *info);
void	endStructure(CFXMLParserRef parser, void *xmlType, void *info);


- (void)populateImageQueueFromNextPage
{

	/*
		MacOSaiX's flickr API Key: 514c14062bc75c91688dfdeacc6252c7
		
		http://www.flickr.com/services/api/
		
		Sorting: interestingness-desc
	*/
	WSMethodInvocationRef	flickrInvocation = WSMethodInvocationCreate((CFURLRef)[NSURL URLWithString:@"http://www.flickr.com/services/xmlrpc/"],
																		CFSTR("flickr.photos.search"),
																		kWSXMLRPCProtocol);
	NSMutableDictionary		*parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												@"514c14062bc75c91688dfdeacc6252c7", @"api_key", 
												[NSNumber numberWithInt:nextPage], @"page", 
												[NSNumber numberWithInt:100], @"per_page", 
												@"date-posted-desc", @"sort", 
												nil];
	
	if (queryType == matchAllTags)
	{
		[parameters setObject:queryString forKey:@"tags"];
		[parameters setObject:@"all" forKey:@"tagmode"];
	}
	else if (queryType == matchAnyTags)
	{
		[parameters setObject:queryString forKey:@"tags"];
		[parameters setObject:@"any" forKey:@"tagmode"];
	}
	else
		[parameters setObject:queryString forKey:@"text"];
	
	NSDictionary			*wrappedParameters = [NSDictionary dictionaryWithObject:parameters forKey:@"foo"];
	WSMethodInvocationSetParameters(flickrInvocation, (CFDictionaryRef)wrappedParameters, nil);
	CFDictionaryRef			results = WSMethodInvocationInvoke(flickrInvocation);
	
	if (WSMethodResultIsFault(results))
	{
		#ifdef DEBUG
			NSLog(@"Could not talk to flickr: %@ (Error %@)", [(NSDictionary *)results objectForKey:(id)kWSFaultString], 
															  [(NSDictionary *)results objectForKey:(id)kWSFaultCode]);	// TODO: handle error
		#endif
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
// TODO: handle the error
//			NSString	*parserError = (NSString *)CFXMLParserCopyErrorDescription(parser);
//			
//			errorMessage = [NSString stringWithFormat:@"Error at line %d: %@", CFXMLParserGetLineNumber(parser), parserError];
//			
//			[parserError release];
		}
		else
		{
			int		pageCount = [[contextDict objectForKey:@"Page Count"] intValue];
			
			if (pageCount > nextPage)
				nextPage++;
			else
				nextPage = 0;
		}
		
		CFRelease(parser);
	}
	
	CFRelease(results);
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
					NSString	*serverID = [nodeAttributes objectForKey:@"server"], 
								*photoID = [nodeAttributes objectForKey:@"id"], 
								*secret = [nodeAttributes objectForKey:@"secret"], 
								*owner = [nodeAttributes objectForKey:@"owner"];
					
					newObject = [[NSString stringWithFormat:@"%@\t%@\t%@\t%@", serverID, photoID, secret, owner] retain];
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
	return ([identifierQueue count] > 0 || nextPage > 0);
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	NSImage		*image = nil;
    
	do
	{
		if ([identifierQueue count] == 0)
			[self populateImageQueueFromNextPage];
		else
		{
				// Get the image for the first identifier in the queue.
			image = [self imageForIdentifier:[identifierQueue objectAtIndex:0]];
			if (image)
				*identifier = [[[identifierQueue objectAtIndex:0] retain] autorelease];
			[identifierQueue removeObjectAtIndex:0];
		}
	} while (!image && [self hasMoreImages]);
	
	return image;
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
		NSData		*imageData = [[[NSData alloc] initWithContentsOfURL:[self urlForIdentifier:identifier]] autorelease];
		
		if (imageData)
		{
			image = [[[NSImage alloc] initWithData:imageData] autorelease];
			if (image)
				[[self class] cacheImageData:imageData withIdentifier:identifier];
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
	
	return [NSURL URLWithString:[NSString stringWithFormat:@"http://static.flickr.com/%@/%@_%@_m.jpg", 
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
	return nil;
}	


- (void)dealloc
{
	[queryString release];
	
	[identifierQueue release];
	
	[super dealloc];
}


@end

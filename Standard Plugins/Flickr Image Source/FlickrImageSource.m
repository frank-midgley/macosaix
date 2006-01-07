/*
	FlickrImageSource.m
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "FlickrImageSource.h"
#import "FlickrImageSourceController.h"
#import "NSString+MacOSaiX.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <sys/time.h>


	// The image cache is shared between all instances so we need a class level lock.
static NSLock	*imageCacheLock = nil;
static NSString	*imageCachePath = nil;

static NSImage	*fIcon = nil,
				*flickrIcon = nil;


NSString *escapedNSString(NSString *string)
{
	NSString	*escapedString = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, 
																					 NULL, NULL, kCFStringEncodingUTF8);
	return [escapedString autorelease];
}


@implementation FlickrImageSource


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
	
	[pool release];
}


+ (NSString *)name
{
	return @"flickr";
}


+ (NSImage *)image;
{
    return fIcon;
}


+ (Class)editorClass
{
	return [FlickrImageSourceController class];
}


+ (Class)preferencesControllerClass
{
	return nil;
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


- (id)init
{
	if (self = [super init])
	{
		if ([[NSFileManager defaultManager] fileExistsAtPath:imageCachePath])
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


- (NSString *)descriptor
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
		;	//handle error
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
								*secret = [nodeAttributes objectForKey:@"secret"];
					
					newObject = [[NSString stringWithFormat:@"%@\t%@\t%@", serverID, photoID, secret] retain];
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


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	NSImage		*image = nil;
	NSData		*imageData = nil;
	NSArray		*identifierComponents = [identifier componentsSeparatedByString:@"\t"];
	NSString	*serverID = [identifierComponents objectAtIndex:0], 
				*photoID = [identifierComponents objectAtIndex:1],
				*secret = [identifierComponents objectAtIndex:2], 
				*imageName = [NSString stringWithFormat:@"%@-%@.jpg", serverID, photoID], 
				*imagePath = [imageCachePath stringByAppendingPathComponent:imageName];
	
		// First check if we have this image in the disk cache.
	[imageCacheLock lock];
		if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath])
		{
				// Read the image data from the file.
			imageData = [[[NSData alloc] initWithContentsOfFile:imagePath] autorelease];
			
				// Touch the file so it stays in the cache longer.
			utimes([imageCachePath fileSystemRepresentation], NULL);
		}
	[imageCacheLock unlock];
	if (imageData)
		image = [[[NSImage alloc] initWithData:imageData] autorelease];
	
		// If it's not in the cache or couldn't be read from the cache then
		// fetch the image from flickr.
	if (![image isValid])
	{
		NSURL		*imageURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://static.flickr.com/%@/%@_%@_m.jpg", serverID, photoID, secret]];
		
		imageData = [[[NSData alloc] initWithContentsOfURL:imageURL] autorelease];
		if (imageData)
		{
			image = [[[NSImage alloc] initWithData:imageData] autorelease];
			[imageCacheLock lock];
				[imageData writeToFile:imagePath atomically:NO];
			
				// TODO: purge oldest image(s) when cache size limit exceeded.
			[imageCacheLock unlock];
		}
	}
	
    return image;
}


- (void)dealloc
{
	[queryString release];
	
	[identifierQueue release];
	
	[super dealloc];
}


@end

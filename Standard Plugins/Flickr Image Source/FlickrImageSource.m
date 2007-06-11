/*
	FlickrImageSource.m
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "FlickrImageSource.h"
#import "FlickrImageSourcePlugIn.h"
#import "FlickrImageSourceController.h"
#import "FlickrPreferencesController.h"
#import "NSString+MacOSaiX.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>


NSString *escapedNSString(NSString *string)
{
	NSString	*escapedString = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, 
																					 NULL, NULL, kCFStringEncodingUTF8);
	return [escapedString autorelease];
}


@implementation MacOSaiXFlickrImageSource


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


- (id)init
{
	if (self = [super init])
	{
		if ([[NSFileManager defaultManager] fileExistsAtPath:[MacOSaiXFlickrImageSourcePlugIn imageCachePath]])
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


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	NSString		*queryTypeString = nil;
	
	if ([self queryType] == matchAllTags)
		queryTypeString = @"All Tags";
	else if ([self queryType] == matchAllTags)
		queryTypeString = @"Any Tags";
	else
		queryTypeString = @"Titles, Tags or Descriptions";
	
	return [[NSDictionary dictionaryWithObjectsAndKeys:
								[self queryString], @"Query String", 
								queryTypeString, @"Query Type", 
								lastUploadTimeStamp, @"Minimum Upload Date", 
								identifierQueue, @"Identifier Queue", 
								nil] 
				writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	[self setQueryString:[settings objectForKey:@"Query String"]];
	
	NSString	*queryTypeString = [settings objectForKey:@"TYPE"];
	if ([queryTypeString isEqualToString:@"All Tags"])
		[self setQueryType:matchAllTags];
	if ([queryTypeString isEqualToString:@"Any Tag"] || [queryTypeString isEqualToString:@"Any Tags"])
		[self setQueryType:matchAnyTag];
	if ([queryTypeString isEqualToString:@"Titles, Tags or Descriptions"])
		[self setQueryType:matchTitlesTagsOrDescriptions];
	
	lastUploadTimeStamp = [[settings objectForKey:@"Minimum Upload Date"] retain];
	identifierQueue = [[settings objectForKey:@"Identifier Queue"] retain];
	
	return YES;
}


- (void)setQueryString:(NSString *)string
{
	[queryString autorelease];
	queryString = [string copy];
	
	[self reset];
}


- (NSString *)queryString
{
	return queryString;
}


- (void)setQueryType:(FlickrQueryType)type;
{
	queryType = type;
	
	[self reset];
}


- (FlickrQueryType)queryType;
{
	return queryType;
}


- (void)reset
{
	[identifierQueue removeAllObjects];
	
	[lastUploadTimeStamp release];
	lastUploadTimeStamp = nil;
	
	haveMoreImages = YES;
}


- (BOOL)imagesShouldBeRemovedForLastChange
{
	return YES;
}


- (NSImage *)image;
{
    return [MacOSaiXFlickrImageSourcePlugIn flickrIcon];
}


- (id)briefDescription
{
	NSString	*descriptor = nil;
	
	if (queryType == matchTitlesTagsOrDescriptions)
		descriptor = [NSString stringWithFormat:NSLocalizedString(@"Images matching \"%@\"", @""), queryString];
	else
	{
		NSMutableArray	*tags = [[queryString componentsSeparatedByString:@","] mutableCopy];
		NSCharacterSet	*whiteSpaceSet = [NSCharacterSet whitespaceCharacterSet];
		
		if ([tags count] == 1)
			descriptor = [NSString stringWithFormat:NSLocalizedString(@"Images tagged with \"%@\"", @""), 
										[[tags objectAtIndex:0] stringByTrimmingCharactersInSet:whiteSpaceSet]];
		else
		{
			NSEnumerator	*tagEnumerator = [tags objectEnumerator];
			NSString		*tag = nil;
			unsigned		index = 0;
			while (tag = [tagEnumerator nextObject])
				[tags replaceObjectAtIndex:index++ withObject:[tag stringByTrimmingCharactersInSet:whiteSpaceSet]];
			
			descriptor = [NSString stringWithFormat:NSLocalizedString(@"Images tagged with \"%@\" %@ \"%@\"", @""), 
													[[tags subarrayWithRange:NSMakeRange(0, [tags count] - 1)]
														componentsJoinedByString:@"\", \""], 
													NSLocalizedString((queryType == matchAllTags ? @"and" : @"or"), @""), 
													[tags lastObject]];
		}
		
		[tags release];
	}
	
	return descriptor;
}


- (BOOL)settingsAreValid
{
	return ([[self queryString] length] > 0);
}


- (NSNumber *)aspectRatio
{
	return nil;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXFlickrImageSource	*copy = [[MacOSaiXFlickrImageSource allocWithZone:zone] init];
	
	[copy setQueryString:queryString];
	[copy setQueryType:queryType];
	
	return copy;
}


	// XML parser callback prototypes.
void	*createStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info);
void	addChild(CFXMLParserRef parser, void *parent, void *child, void *info);
void	endStructure(CFXMLParserRef parser, void *xmlType, void *info);


- (void)populateImageQueueFromNextPage
{

	/*
		MacOSaiX's flickr API Key: 514c14062bc75c91688dfdeacc6252c7
		
		http://www.flickr.com/services/api/
	*/
	WSMethodInvocationRef	flickrInvocation = WSMethodInvocationCreate((CFURLRef)[NSURL URLWithString:@"http://www.flickr.com/services/xmlrpc/"],
																		CFSTR("flickr.photos.search"),
																		kWSXMLRPCProtocol);
	NSMutableDictionary		*parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												@"514c14062bc75c91688dfdeacc6252c7", @"api_key", 
												[NSNumber numberWithInt:1], @"page", 
												[NSNumber numberWithInt:200], @"per_page", 
												@"date-posted-asc", @"sort", 
												@"date_upload", @"extras", 
												nil];
	
	if (lastUploadTimeStamp)
		[parameters setObject:lastUploadTimeStamp forKey:@"min_upload_date"];
	
	if (queryType == matchAllTags)
	{
		[parameters setObject:queryString forKey:@"tags"];
		[parameters setObject:@"all" forKey:@"tag_mode"];
	}
	else if (queryType == matchAnyTag)
	{
		[parameters setObject:queryString forKey:@"tags"];
		[parameters setObject:@"any" forKey:@"tag_mode"];
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
			NSString	*parserError = (NSString *)CFXMLParserCopyErrorDescription(parser);
			
			NSLog(@"Error (%@) at line %d of:\n\n%@", parserError, CFXMLParserGetLineNumber(parser), xmlString);
			
			[parserError release];
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
					
					#ifdef DEBUG
						NSLog(@"Total pages = %@, count = %@", [nodeAttributes objectForKey:@"pages"], [nodeAttributes objectForKey:@"total"]);
					#endif
					
					newObject = identifierQueue;
				}
				else if ([elementType isEqualToString:@"photo"])
				{
					NSString	*serverID = [nodeAttributes objectForKey:@"server"], 
								*photoID = [nodeAttributes objectForKey:@"id"], 
								*secret = [nodeAttributes objectForKey:@"secret"], 
								*owner = [nodeAttributes objectForKey:@"owner"], 
								*title = [nodeAttributes objectForKey:@"title"], 
								*dateUploaded = [nodeAttributes objectForKey:@"dateupload"];
					
					newObject = [[NSString alloc] initWithFormat:@"%@\t%@\t%@\t%@\t%@", serverID, photoID, secret, owner, title];
					
					[contextDict setObject:dateUploaded forKey:@"Last Upload Timestamp"];
				}
			}
				
			default:
				;
		}
	NS_HANDLER
		CFXMLParserAbort(parser, kCFXMLErrorMalformedStartTag, 
						 (CFStringRef)[NSString stringWithFormat:NSLocalizedString(@"Could not create structure (%@)", @""), 
																 [localException reason]]);
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


- (NSNumber *)imageCount
{
	return nil;
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
			image = [self thumbnailForIdentifier:[identifierQueue objectAtIndex:0]];
			if (!image)
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


- (id<NSCopying>)universalIdentifierForIdentifier:(NSString *)identifier
{
	return [self urlForIdentifier:identifier];
}


- (NSImage *)thumbnailForIdentifier:(NSString *)identifier
{
		// First check if we have this thumbnail in the disk cache.
	NSImage		*image = [MacOSaiXFlickrImageSourcePlugIn cachedImageWithIdentifier:identifier getThumbnail:YES];
	
		// Next go for the full size image in the cache.
	if (!image)
		image = [MacOSaiXFlickrImageSourcePlugIn cachedImageWithIdentifier:identifier getThumbnail:NO];
	
		// If it's not in the cache then fetch the thumbnail from flickr.
	if (!image)
	{
		NSArray		*identifierComponents = [identifier componentsSeparatedByString:@"\t"];
		NSString	*serverID = [identifierComponents objectAtIndex:0], 
					*photoID = [identifierComponents objectAtIndex:1],
					*secret = [identifierComponents objectAtIndex:2];
		NSURL		*thumbnailURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://static.flickr.com/%@/%@_%@_t.jpg", 
															   serverID, photoID, secret]];
		NSData		*imageData = [[[NSData alloc] initWithContentsOfURL:thumbnailURL] autorelease];
		
		if (imageData)
		{
			image = [[[NSImage alloc] initWithData:imageData] autorelease];
			if (image)
				[MacOSaiXFlickrImageSourcePlugIn cacheImageData:imageData withIdentifier:identifier isThumbnail:YES];
		}
	}
	
    return image;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
		// First check if we have this image in the disk cache.
	NSImage		*image = [MacOSaiXFlickrImageSourcePlugIn cachedImageWithIdentifier:identifier getThumbnail:NO];
	
		// If it's not in the cache then fetch the image from flickr.
	if (!image)
	{
		NSData		*imageData = [[[NSData alloc] initWithContentsOfURL:[self urlForIdentifier:identifier]] autorelease];
		
		if (imageData)
		{
			image = [[[NSImage alloc] initWithData:imageData] autorelease];
			if (image)
				[MacOSaiXFlickrImageSourcePlugIn cacheImageData:imageData withIdentifier:identifier isThumbnail:NO];
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
	NSArray		*identifierComponents = [identifier componentsSeparatedByString:@"\t"];
	
	if ([identifierComponents count] > 4)
		return [identifierComponents objectAtIndex:4];
	else
		return nil;
}	


- (void)dealloc
{
	[queryString release];
	
	[identifierQueue release];
	
	[super dealloc];
}


@end

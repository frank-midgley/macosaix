//
//  MacOSaiXFlickrCategory.m
//  MacOSaiX
//
//  Created by Frank Midgley on 4/29/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXFlickrCategory.h"

#import "FlickrImageSource.h"
#import "FlickrPreferencesController.h"
#import "MacOSaiXFlickrGroup.h"


@implementation MacOSaiXFlickrCategory


+ (MacOSaiXFlickrCategory *)categoryWithName:(NSString *)inName catID:(NSString *)inCatID
{
	return [[[self alloc] initWithName:inName catID:inCatID] autorelease];
}


- (id)initWithName:(NSString *)inName catID:(NSString *)inCatID
{
	if (self = [super init])
	{
		name = [inName copy];
		catID = [inCatID copy];
		subCategories = [[NSMutableArray alloc] init];
		groups = [[NSMutableArray alloc] init];
	}
	
	return self;
}


- (NSString *)name
{
	return name;
}


- (NSString *)catID
{
	return catID;
}


void *createGetChildrenStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	volatile id			newObject = nil;
	
	NS_DURING
		if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeElement)
		{
			NSString			*elementType = (NSString *)CFXMLNodeGetString(node);
			CFXMLElementInfo	*nodeInfo = (CFXMLElementInfo *)CFXMLNodeGetInfoPtr(node);
			NSDictionary		*nodeAttributes = (NSDictionary *)nodeInfo->attributes;
			
			if ([elementType isEqualToString:@"subcat"])
			{
				MacOSaiXFlickrCategory	*subCategory = [MacOSaiXFlickrCategory categoryWithName:[nodeAttributes objectForKey:@"name"] 
																						  catID:[nodeAttributes objectForKey:@"id"]];
				[(MacOSaiXFlickrCategory *)info addSubCategory:subCategory];
				
				newObject = subCategory;
			}
			else if ([elementType isEqualToString:@"group"])
			{
				MacOSaiXFlickrGroup	*group = [MacOSaiXFlickrGroup groupWithName:[nodeAttributes objectForKey:@"name"] 
																		groupID:[nodeAttributes objectForKey:@"nsid"]
																	   is18Plus:NO];
				[(MacOSaiXFlickrCategory *)info addGroup:group];
				
				newObject = group;
			}
		}
		NS_HANDLER
			CFXMLParserAbort(parser, kCFXMLErrorMalformedStartTag, 
							 (CFStringRef)[NSString stringWithFormat:@"Could not create structure (%@)", [localException reason]]);
		NS_ENDHANDLER
		
		[pool release];
		
		// Return the object that will be passed to the addChild and endStructure callbacks.
		return (void *)newObject;
}


void addGetChildrenChild(CFXMLParserRef parser, void *parent, void *child, void *info)
{
}


void endGetChildrenStructure(CFXMLParserRef parser, void *newObject, void *info)
{
}


- (NSError *)fetchChildren
{
	NSError					*error = nil;
	WSMethodInvocationRef	getChildrenInvocation = WSMethodInvocationCreate((CFURLRef)[NSURL URLWithString:@"http://www.flickr.com/services/xmlrpc/"],
																			 CFSTR("flickr.groups.browse"),
																			 kWSXMLRPCProtocol);
	NSDictionary			*getChildrenParameters = [FlickrImageSource authenticatedParameters:[NSDictionary dictionaryWithObjectsAndKeys:
																									@"flickr.groups.browse", @"method", 
																									catID, @"cat_id", 
																									nil]];
	WSMethodInvocationSetParameters(getChildrenInvocation, (CFDictionaryRef)[NSDictionary dictionaryWithObject:getChildrenParameters forKey:@"foo"], nil);
	CFDictionaryRef			getChildrenResults = WSMethodInvocationInvoke(getChildrenInvocation);
	
	if (WSMethodResultIsFault(getChildrenResults))
		error = [FlickrImageSource errorFromWSMethodResults:(NSDictionary *)getChildrenResults];
	else
	{
			// Create a parser with the option to skip whitespace.
		NSString				*xmlString = [(NSDictionary *)getChildrenResults objectForKey:(NSString *)kWSMethodInvocationResult];
		NSData					*xmlData = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
		CFXMLParserCallBacks	callbacks = {0, createGetChildrenStructure, addGetChildrenChild, endGetChildrenStructure, NULL, NULL};
		CFXMLParserContext		context = {0, self, NULL, NULL, NULL};
		CFXMLParserRef			getChildrenParser = CFXMLParserCreate(kCFAllocatorDefault, 
																	  (CFDataRef)xmlData, 
																	  NULL, // data source URL for resolving external refs
																	  kCFXMLParserSkipWhitespace, 
																	  kCFXMLNodeCurrentVersion, 
																	  &callbacks, 
																	  &context);
		
			// Invoke the parser.
		if (!CFXMLParserParse(getChildrenParser))
		{
				// An error occurred parsing the XML.
			NSString	*parserError = (NSString *)CFXMLParserCopyErrorDescription(getChildrenParser);
			
			NSString	*errorMessage = [NSString stringWithFormat:@"Error at line %d: %@", CFXMLParserGetLineNumber(getChildrenParser), parserError];
			
			error = [NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				errorMessage, NSLocalizedDescriptionKey, 
				nil]];
			
			[parserError release];
		}
		else
			childrenFetched = YES;
		
		CFRelease(getChildrenParser);
	}
	
	CFRelease(getChildrenResults);
	
	return error;
}


- (void)addSubCategory:(MacOSaiXFlickrCategory *)subCategory
{
	[subCategories addObject:subCategory];
	[subCategories sortUsingSelector:@selector(compare:)];
}


- (NSArray *)subCategories
{
	if (!childrenFetched)
		[self fetchChildren];
	
	return [NSArray arrayWithArray:subCategories];
}


- (void)addGroup:(MacOSaiXFlickrGroup *)group
{
	childrenFetched = YES;
	
	[groups addObject:group];
	[groups sortUsingSelector:@selector(compare:)];
}


- (NSArray *)groups
{
	if (!childrenFetched)
		[self fetchChildren];
	
	return [NSArray arrayWithArray:groups];
}


- (void)removeAllGroups
{
	[groups removeAllObjects];
}


- (NSArray *)children
{
	if (!childrenFetched)
		[self fetchChildren];
	
	return [[subCategories arrayByAddingObjectsFromArray:groups] sortedArrayUsingSelector:@selector(compare:)];
}


- (NSComparisonResult)compare:(id)otherObject
{
	return [[self name] compare:[otherObject name]];
}


- (void)dealloc
{
	[name release];
	[catID release];
	
	[super dealloc];
}


@end

//
//  MacOSaiXFlickrGroup.m
//  MacOSaiX
//
//  Created by Frank Midgley on 4/29/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXFlickrGroup.h"

#import "FlickrImageSource.h"


@implementation MacOSaiXFlickrGroup


+ (MacOSaiXFlickrGroup *)groupWithName:(NSString *)inName groupID:(NSString *)inGroupID is18Plus:(BOOL)flag
{
	return [[[self alloc] initWithName:inName groupID:inGroupID is18Plus:flag] autorelease];
}


- (id)initWithName:(NSString *)inName groupID:(NSString *)inGroupID is18Plus:(BOOL)flag
{
	if (self = [super init])
	{
		name = [inName copy];
		groupID = [inGroupID copy];
		is18Plus = flag;
	}
	
	return self;
}


- (void)setName:(NSString *)inName
{
	[name autorelease];
	name = [inName copy];
}


- (NSString *)name
{
	return name;
}


- (NSString *)groupID
{
	return groupID;
}


- (BOOL)is18Plus
{
	return is18Plus;
}


- (BOOL)isEqual:(id)otherObject
{
	return ((self == otherObject) || 
			([otherObject isKindOfClass:[self class]] && [[self groupID] isEqualToString:[otherObject groupID]]));
}


- (NSComparisonResult)compare:(id)otherObject
{
	return [[self name] caseInsensitiveCompare:[otherObject name]];
}


static void *createStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	volatile id			newObject = nil;
	
	NS_DURING
		MacOSaiXFlickrGroup	*group = info;
		
		switch (CFXMLNodeGetTypeCode(node))
		{
			case kCFXMLNodeTypeElement:
			{
				NSString			*elementType = (NSString *)CFXMLNodeGetString(node);
				
				if ([elementType isEqualToString:@"group"])
					newObject = group;
				else if ([elementType isEqualToString:@"name"])
					newObject = @"name";
				
				break;
			}
				
			case kCFXMLNodeTypeText:
				newObject = (NSString *)CFXMLNodeGetString(node);
				break;
			
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


static void addChild(CFXMLParserRef parser, void *parent, void *child, void *info)
{
	if ([(id)parent isKindOfClass:[NSString class]] && [(NSString *)parent isEqualToString:@"name"])
		[(MacOSaiXFlickrGroup *)info setName:[NSString stringWithString:(NSString *)child]];
}


static void endStructure(CFXMLParserRef parser, void *newObject, void *info)
{
}


- (NSError *)populate
{
	NSError					*error = nil;
	WSMethodInvocationRef	flickrInvocation = WSMethodInvocationCreate((CFURLRef)[NSURL URLWithString:@"http://www.flickr.com/services/xmlrpc/"],
																		CFSTR("flickr.groups.getInfo"),
																		kWSXMLRPCProtocol);
	NSDictionary			*parameters = [NSDictionary dictionaryWithObjectsAndKeys:
												@"flickr.groups.getInfo", @"method", 
												[self groupID], @"group_id", 
												nil], 
							*wrappedParameters = [NSDictionary dictionaryWithObject:[FlickrImageSource authenticatedParameters:parameters] forKey:@"foo"];
	WSMethodInvocationSetParameters(flickrInvocation, (CFDictionaryRef)wrappedParameters, nil);
	CFDictionaryRef			results = WSMethodInvocationInvoke(flickrInvocation);
	
	if (WSMethodResultIsFault(results))
		error = [FlickrImageSource errorFromWSMethodResults:(NSDictionary *)results];
	else
	{
			// Create the parser with the option to skip whitespace.
		NSString				*xmlString = [(NSDictionary *)results objectForKey:(NSString *)kWSMethodInvocationResult];
		NSData					*xmlData = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
		CFXMLParserCallBacks	callbacks = {0, createStructure, addChild, endStructure, NULL, NULL};
		CFXMLParserContext		context = {0, self, NULL, NULL, NULL};
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
			NSString	*parserError = [(NSString *)CFXMLParserCopyErrorDescription(parser) autorelease], 
						*errorMessage = [NSString stringWithFormat:@"Error at line %d: %@", CFXMLParserGetLineNumber(parser), parserError];
			
			error = [NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey]];
		}
		
		CFRelease(parser);
	}
	
	CFRelease(results);
	
	return error;
}


- (void)dealloc
{
	[name release];
	[groupID release];
	
	[super dealloc];
}


@end

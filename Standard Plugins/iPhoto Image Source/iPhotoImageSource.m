/*
	iPhotoImageSource.m
	MacOSaiX

	Created by Frank Midgley on Wed Mar 15 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "iPhotoImageSource.h"
#import "iPhotoDatabase.h"
#import "iPhotoImageSourceController.h"
#import "NSString+MacOSaiX.h"
#import <pthread.h>


@interface MacOSaiXiPhotoImageSource (PrivateMethods)
- (NSString *)pathOfPhotoWithID:(NSString *)photoID;
@end


@implementation MacOSaiXiPhotoImageSource


+ (NSImage *)image;
{
	return [[MacOSaiXiPhotoDatabase sharedDatabase] appImage];
}


+ (Class)editorClass
{
	return [MacOSaiXiPhotoImageSourceController class];
}


+ (Class)preferencesControllerClass
{
	return nil;
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


- (id)initWithAlbumName:(NSString *)aName keywordName:(NSString *)kName eventName:(NSString *)eName
{
	if ((self = [super init]))
	{
		if (aName)
			[self setAlbumName:aName];
		else if (kName)
			[self setKeywordName:kName];
		else if (eName)
			[self setEventName:eName];
	}

    return self;
}


- (NSString *)settingsAsXMLElement
{
	NSMutableString	*settings = [NSMutableString string];
	
	if ([self albumName])
		[settings appendString:[NSString stringWithFormat:@"<ALBUM NAME=\"%@\"/>\n", 
										  [[self albumName] stringByEscapingXMLEntites]]];
	if ([self keywordName])
		[settings appendString:[NSString stringWithFormat:@"<KEYWORD NAME=\"%@\"/>\n", 
										  [[self keywordName] stringByEscapingXMLEntites]]];
	
	[settings appendString:[NSString stringWithFormat:@"<PHOTO_IDS REMAINING=\"%@\"/>", 
													  [remainingPhotoIDs componentsJoinedByString:@","]]];

	return settings;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"ALBUM"])
		[self setAlbumName:[[[settingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites]];
	else if ([settingType isEqualToString:@"KEYWORD"])
		[self setAlbumName:[[[settingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites]];
	else if ([settingType isEqualToString:@"PHOTO_IDS"])
		remainingPhotoIDs = [[[[settingDict objectForKey:@"REMAINING"] description] componentsSeparatedByString:@","] mutableCopy];
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	// not needed
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
	// not needed
}


- (NSString *)albumName
{
	return [[albumName retain] autorelease];
}


- (void)setAlbumName:(NSString *)name
{
	[albumName autorelease];
	albumName = [name copy];
	
	if (name)
	{
		[self setKeywordName:nil];
		[self setEventName:nil];
		
		[sourceDescription autorelease];
		sourceDescription = [[NSString stringWithFormat:@"Photos from \"%@\"", albumName] retain];
		
			// Indicate that the photo ID's need to be retrieved.
		[remainingPhotoIDs autorelease];
		remainingPhotoIDs = nil;
	}
}


- (NSString *)keywordName
{
	return [[keywordName retain] autorelease];
}


- (void)setKeywordName:(NSString *)name
{
	[keywordName autorelease];
	keywordName = [name copy];
	
	if (name)
	{
		[self setAlbumName:nil];
		[self setEventName:nil];
		
		[sourceDescription autorelease];
		sourceDescription = [[NSString stringWithFormat:@"\"%@\" photos", keywordName] retain];
		
			// Indicate that the photo ID's need to be retrieved.
		[remainingPhotoIDs autorelease];
		remainingPhotoIDs = nil;
	}
}


- (NSString *)eventName
{
	return [[eventName retain] autorelease];
}


- (void)setEventName:(NSString *)name
{
	[eventName autorelease];
	eventName = [name copy];
	
	if (name)
	{
		[self setAlbumName:nil];
		[self setKeywordName:nil];
		
		[sourceDescription autorelease];
		sourceDescription = [[NSString stringWithFormat:@"Photos from \"%@\"", eventName] retain];
		
		// Indicate that the photo ID's need to be retrieved.
		[remainingPhotoIDs autorelease];
		remainingPhotoIDs = nil;
	}
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[MacOSaiXiPhotoImageSource allocWithZone:zone] initWithAlbumName:albumName keywordName:keywordName eventName:eventName];
}


- (NSImage *)image;
{
	return [[MacOSaiXiPhotoDatabase sharedDatabase] appImage];
}


- (id)descriptor
{
	if (!sourceDescription)
		sourceDescription = [[NSString stringWithString:@"All photos"] retain];
	
	return [[sourceDescription retain] autorelease];
}


- (BOOL)hasMoreImages
{
	return (!remainingPhotoIDs || [remainingPhotoIDs count] > 0);
}


- (void)getPhotoIDs
{
	NSArray *photoIDs;
	
	if (albumName)
		photoIDs = [[MacOSaiXiPhotoDatabase sharedDatabase] photoIDsFromAlbum:albumName];
	else if (eventName)
		photoIDs = [[MacOSaiXiPhotoDatabase sharedDatabase] photoIDsFromEvent:eventName];
	else if (keywordName)
		photoIDs = [[MacOSaiXiPhotoDatabase sharedDatabase] photoIDsForKeyword:keywordName];
	else
		photoIDs = [[MacOSaiXiPhotoDatabase sharedDatabase] photoIDs];
	
	remainingPhotoIDs = [[NSMutableArray arrayWithArray:photoIDs] retain];
}


- (NSError *)nextImage:(NSImage **)image andIdentifier:(NSString **)identifier
{
	NSError	*error = nil;
	
	*image = nil;
	*identifier = nil;
	
	if (!remainingPhotoIDs)
		[self getPhotoIDs];
	
	if ([remainingPhotoIDs count] > 0)
	{
		NSString		*photoID = [remainingPhotoIDs objectAtIndex:0];
		
		*image = [self imageForIdentifier:photoID];
		
		if (*image)
			*identifier = [[photoID retain] autorelease];
		
		[remainingPhotoIDs removeObjectAtIndex:0];
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
	NSImage		*image = nil;
	NSString	*imagePath = [[MacOSaiXiPhotoDatabase sharedDatabase] pathOfPhotoWithID:identifier];
	
	if (imagePath)
	{
//		NSLog(@"Attempting to load iPhoto image at %@", imagePath);
		NS_DURING
			image = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
			if (!image)
			{
					// The image might have the wrong or a missing file extension so 
					// try init'ing it based on its contents instead.  This requires 
					// more memory so only do this if initWithContentsOfFile fails.
				NSData	*data = [[NSData alloc] initWithContentsOfFile:imagePath];
				image = [[[NSImage alloc] initWithData:data] autorelease];
				[data release];
			}
		NS_HANDLER
			NSLog(@"%@ is not a valid image file.", imagePath);
		NS_ENDHANDLER
	}
	
    return image;
}


- (NSURL *)urlForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (NSURL *)contextURLForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (NSString *)descriptionForIdentifier:(NSString *)identifier
{
	return [[MacOSaiXiPhotoDatabase sharedDatabase] titleOfPhotoWithID:identifier];
}	


- (void)reset
{
		// Indicate that the photo ID's need to be retrieved.
	[remainingPhotoIDs autorelease];
	remainingPhotoIDs = nil;
}


- (void)dealloc
{
	[albumName release];
	[sourceDescription release];
	[remainingPhotoIDs release];
	
	[super dealloc];
}


@end

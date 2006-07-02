/*
	iPhotoImageSource.m
	MacOSaiX

	Created by Frank Midgley on Wed Mar 15 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "iPhotoImageSource.h"
#import "iPhotoImageSourceController.h"
#import "NSString+MacOSaiX.h"
#import <pthread.h>


static NSImage	*iPhotoImage = nil,
				*albumImage = nil;


@interface MacOSaiXiPhotoImageSource (PrivateMethods)
- (NSString *)valueOfProperty:(NSString *)propertyName forPhotoWithID:(NSString *)photoID;
@end


@implementation MacOSaiXiPhotoImageSource


+ (void)initialize
{
	NSURL		*iPhotoAppURL = nil;
	LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.iPhoto"), NULL, NULL, (CFURLRef *)&iPhotoAppURL);
	NSBundle	*iPhotoBundle = [NSBundle bundleWithPath:[iPhotoAppURL path]];
	
	iPhotoImage = [[NSImage alloc] initWithContentsOfFile:[iPhotoBundle pathForImageResource:@"NSApplicationIcon"]];
	albumImage = [[NSImage alloc] initWithContentsOfFile:[iPhotoBundle pathForImageResource:@"album_local"]];
	[albumImage setScalesWhenResized:YES];
	[albumImage setSize:NSMakeSize(16.0, 16.0)];
}


+ (NSImage *)image;
{
	return iPhotoImage;
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


+ (NSImage *)albumImage
{
	return albumImage;
}


+ (NSImage *)keywordImage
{
	return nil;
}


- (id)initWithAlbumName:(NSString *)name
{
	if (self = [super init])
	{
		[self setAlbumName:name];
	}

    return self;
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	NSMutableDictionary	*settings = [NSMutableDictionary dictionaryWithObject:remainingPhotoIDs
																	   forKey:@"Remaining Photo IDs"];
	
	if ([self albumName])
		[settings setObject:[self albumName] forKey:@"Album"];
	if ([self keywordName])
		[settings setObject:[self keywordName] forKey:@"Keyword"];
	
	return [settings writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	[self setAlbumName:[settings objectForKey:@"Album"]];
	[self setKeywordName:[settings objectForKey:@"Keyword"]];
	remainingPhotoIDs = [[settings objectForKey:@"Remaining Photo IDs"] retain];
	
	return YES;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"ALBUM"])
		[self setAlbumName:[[[settingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites]];
	else if ([settingType isEqualToString:@"KEYWORD"])
		[self setKeywordName:[[[settingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites]];
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
		
		[sourceDescription autorelease];
		sourceDescription = [[NSString stringWithFormat:NSLocalizedString(@"Photos from \"%@\"", @""), albumName] retain];
		
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
		
		[sourceDescription autorelease];
		sourceDescription = [[NSString stringWithFormat:NSLocalizedString(@"\"%@\" photos", @""), keywordName] retain];
		
			// Indicate that the photo ID's need to be retrieved.
		[remainingPhotoIDs autorelease];
		remainingPhotoIDs = nil;
	}
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[MacOSaiXiPhotoImageSource allocWithZone:zone] initWithAlbumName:albumName];
}


- (NSImage *)image;
{
	return iPhotoImage;
}


- (id)descriptor
{
	if (!sourceDescription)
		sourceDescription = [[NSString stringWithString:NSLocalizedString(@"All photos", @"")] retain];
	
	return [[sourceDescription retain] autorelease];
}


- (float)aspectRatio
{
	return 0.0;
}


- (BOOL)hasMoreImages
{
	return (!remainingPhotoIDs || [remainingPhotoIDs count] > 0);
}


- (void)getPhotoIDs
{
	if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone:YES];
	else
	{
		NSString		*scriptText = nil;
		if (albumName)
			scriptText = [NSString stringWithFormat:@"tell application \"iPhoto\" to get id of photos of album \"%@\"", 
													albumName];
		else if (keywordName)
			scriptText = [NSString stringWithFormat:@"tell application \"iPhoto\"\r" \
														"set ids to {}\r" \
														 "repeat with thePhoto in (photos whose keywords is not {})\r" \
															 "set kws to name of keywords of thePhoto\r" \
															 "if kws contains \"%@\" then set ids to ids & (id of thePhoto)\r" \
														 "end repeat\r" \
														"ids\r" \
													 "end tell", keywordName];
		else
			scriptText = @"tell application \"iPhoto\" to get id of photos";
			
		NSAppleScript	*getPhotoIDsScript = [[[NSAppleScript alloc] initWithSource:scriptText] autorelease];
		NSDictionary	*scriptError = nil;
		id				getPhotoIDsResult = [getPhotoIDsScript executeAndReturnError:&scriptError];
		
		remainingPhotoIDs = [[NSMutableArray array] retain];
		
		if (!scriptError)
		{
			int	photoIDCount = [(NSAppleEventDescriptor *)getPhotoIDsResult numberOfItems],
				photoIDIndex;
			for (photoIDIndex = 1; photoIDIndex <= photoIDCount; photoIDIndex++)
				[remainingPhotoIDs addObject:[[(NSAppleEventDescriptor *)getPhotoIDsResult descriptorAtIndex:photoIDIndex] stringValue]];
		}
	}
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	NSImage			*image = nil;
	
	if (!remainingPhotoIDs)
		[self getPhotoIDs];
	
	if ([remainingPhotoIDs count] > 0)
	{
		NSString		*photoID = [remainingPhotoIDs objectAtIndex:0];
		
		image = [self thumbnailForIdentifier:photoID];

		if (!image)
			image = [self imageForIdentifier:photoID];
		
		if (image)
			*identifier = [[photoID retain] autorelease];
		
		[remainingPhotoIDs removeObjectAtIndex:0];
	}

    return image;
}


- (void)getValueOfPhotoPropertyWithParameters:(NSMutableDictionary *)parameters
{
	NSString	*value = [self valueOfProperty:[parameters objectForKey:@"Property Name"]
								forPhotoWithID:[parameters objectForKey:@"Photo ID"]];
	
	if (value)
		[parameters setObject:value forKey:@"Property Value"];
}


- (NSString *)valueOfProperty:(NSString *)propertyName forPhotoWithID:(NSString *)photoID
{
	NSString		*value = nil;
	
	if (!pthread_main_np())
	{
		NSMutableDictionary	*parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												photoID, @"Photo ID", 
												propertyName, @"Property Name", 
												nil];
		[self performSelectorOnMainThread:@selector(getValueOfPhotoPropertyWithParameters:) withObject:parameters waitUntilDone:YES];
		value = [parameters objectForKey:@"Property Value"];
	}
	else
	{
		NSString				*getImagePropertyText = [NSString stringWithFormat:@"tell application \"iPhoto\" to " \
																				   @"get @% of first photo whose id is %@", 
																				   propertyName, photoID];
		NSAppleScript			*getImagePropertyScript = [[[NSAppleScript alloc] initWithSource:getImagePropertyText] autorelease];
		NSDictionary			*scriptError = nil;
		NSAppleEventDescriptor	*getImagePropertyResult = [getImagePropertyScript executeAndReturnError:&scriptError];
		
		if (!scriptError)
			value = [(NSAppleEventDescriptor *)getImagePropertyResult stringValue];
	}
	
	return value;
}


- (BOOL)canRefetchImages
{
	return YES;
}


- (NSImage *)thumbnailForIdentifier:(NSString *)identifier
{
	NSImage		*image = nil;
	NSString	*imagePath = [self valueOfProperty:@"thumbnail path" forPhotoWithID:identifier];
	
	if (imagePath)
	{
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


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	NSImage		*image = nil;
	NSString	*imagePath = [self valueOfProperty:@"image path" forPhotoWithID:identifier];
	
	if (imagePath)
	{
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
	return [self valueOfProperty:@"name" forPhotoWithID:identifier];
}	


- (void)reset
{
	[self setAlbumName:albumName];
}


- (void)dealloc
{
	[albumName release];
	[sourceDescription release];
	[remainingPhotoIDs release];
	
	[super dealloc];
}


@end

/*
	iTunesImageSource.m
	MacOSaiX

	Created by Frank Midgley on Thu May 18 2006.
	Copyright (c) 2006 Frank M. Midgley. All rights reserved.
*/

#import "iTunesImageSource.h"
#import "iTunesImageSourceController.h"
#import "NSString+MacOSaiX.h"
#import <pthread.h>


static NSImage	*iTunesImage = nil,
				*playlistImage = nil;


@interface MacOSaiXiTunesImageSource (PrivateMethods)
- (NSString *)pathOfTrackWithID:(NSString *)trackID;
@end


@implementation MacOSaiXiTunesImageSource


+ (void)initialize
{
	NSURL		*iTunesAppURL = nil;
	LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.iTunes"), NULL, NULL, (CFURLRef *)&iTunesAppURL);
	NSBundle	*iTunesBundle = [NSBundle bundleWithPath:[iTunesAppURL path]];
	
	iTunesImage = [[NSImage alloc] initWithContentsOfFile:[iTunesBundle pathForImageResource:@"iTunes"]];
	playlistImage = [[NSImage alloc] initWithContentsOfFile:[iTunesBundle pathForImageResource:@"iTunes-playlist"]];
	[playlistImage setScalesWhenResized:YES];
	[playlistImage setSize:NSMakeSize(16.0, 16.0)];
}


+ (NSImage *)image;
{
	return iTunesImage;
}


+ (Class)editorClass
{
	return [MacOSaiXiTunesImageSourceController class];
}


+ (Class)preferencesControllerClass
{
	return nil;
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


+ (NSImage *)playlistImage
{
	return playlistImage;
}


- (id)initWithPlaylistName:(NSString *)name
{
	if (self = [super init])
	{
		[self setPlaylistName:name];
	}

    return self;
}


- (NSString *)settingsAsXMLElement
{
	NSMutableString	*settings = [NSMutableString string];
	
	if ([self playlistName])
		[settings appendString:[NSString stringWithFormat:@"<PLAYLIST NAME=\"%@\"/>\n", 
										  [[self playlistName] stringByEscapingXMLEntites]]];
	
	[settings appendString:[NSString stringWithFormat:@"<TRACK_IDS REMAINING=\"%@\"/>", 
													  [remainingTrackIDs componentsJoinedByString:@","]]];

	return settings;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"ALBUM"])
		[self setPlaylistName:[[[settingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites]];
	else if ([settingType isEqualToString:@"KEYWORD"])
		[self setPlaylistName:[[[settingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites]];
	else if ([settingType isEqualToString:@"TRACK_IDS"])
		remainingTrackIDs = [[[[settingDict objectForKey:@"REMAINING"] description] componentsSeparatedByString:@","] mutableCopy];
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	// not needed
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
	// not needed
}


- (NSString *)playlistName
{
	return [[playlistName retain] autorelease];
}


- (void)setPlaylistName:(NSString *)name
{
	[playlistName autorelease];
	playlistName = [name copy];
	
	if (name)
	{
		[sourceDescription autorelease];
		sourceDescription = [[NSString stringWithFormat:@"Album artwork from \"%@\"", playlistName] retain];
		
			// Indicate that the track ID's need to be retrieved.
		[remainingTrackIDs autorelease];
		remainingTrackIDs = nil;
	}
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[MacOSaiXiTunesImageSource allocWithZone:zone] initWithPlaylistName:playlistName];
}


- (NSImage *)image;
{
	return ([self playlistName] ? [[self class] playlistImage] : [[self class] image]);
}


- (id)descriptor
{
	if (!sourceDescription)
		sourceDescription = [[NSString stringWithString:@"All album artwork"] retain];
	
	return [[sourceDescription retain] autorelease];
}


- (BOOL)hasMoreImages
{
	return (!remainingTrackIDs || [remainingTrackIDs count] > 0);
}


- (void)getTrackIDs
{
	if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone:YES];
	else
	{
		NSString		*scriptText = nil;
		if (playlistName)
			scriptText = [NSString stringWithFormat:@"tell application \"iTunes\" to get database ID of tracks of user playlist \"%@\"", 
													playlistName];
		else
			scriptText = @"tell application \"iTunes\" to get database ID of tracks of library playlist 1 of (source 1 whose kind is library)";
			
		NSAppleScript	*getTrackIDsScript = [[[NSAppleScript alloc] initWithSource:scriptText] autorelease];
		NSDictionary	*scriptError = nil;
		id				getTrackIDsResult = [getTrackIDsScript executeAndReturnError:&scriptError];
		
		remainingTrackIDs = [[NSMutableArray array] retain];
		
		if (!scriptError)
		{
			int	trackIDCount = [(NSAppleEventDescriptor *)getTrackIDsResult numberOfItems],
				trackIDIndex;
			for (trackIDIndex = 1; trackIDIndex <= trackIDCount; trackIDIndex++)
				[remainingTrackIDs addObject:[[(NSAppleEventDescriptor *)getTrackIDsResult descriptorAtIndex:trackIDIndex] stringValue]];
		}
	}
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	NSImage			*image = nil;
	
	if (!remainingTrackIDs)
		[self getTrackIDs];
	
	if ([remainingTrackIDs count] > 0)
	{
		NSString		*trackID = [remainingTrackIDs objectAtIndex:0];
		
		image = [self imageForIdentifier:trackID];
		
		if (image)
			*identifier = [[trackID retain] autorelease];
		
		[remainingTrackIDs removeObjectAtIndex:0];
	}

    return image;
}


- (BOOL)canRefetchImages
{
	return YES;
}


- (NSImage *)imageForIdentifier:(id)parameter
{
	NSImage		*image = nil;
	
	if (!pthread_main_np())
	{
		NSMutableDictionary	*parameters = [NSMutableDictionary dictionaryWithObject:parameter forKey:@"Track ID"];
		[self performSelectorOnMainThread:_cmd withObject:parameters waitUntilDone:YES];
		image = [parameters objectForKey:@"Image"];
	}
	else
	{
		NSString				*trackID = [(NSDictionary *)parameter objectForKey:@"Track ID"];
		NSString				*getTrackArtworkText = [NSString stringWithFormat:
										@"tell application \"iTunes\" to " \
										@"get data of first artwork of (first track of " \
										@"first library playlist of (first source whose kind is library) " \
										@"whose database ID is %@)", trackID];
		NSAppleScript			*getTrackArtworkScript = [[[NSAppleScript alloc] initWithSource:getTrackArtworkText] autorelease];
		NSDictionary			*scriptError = nil;
		NSAppleEventDescriptor	*getTrackArtworkResult = [getTrackArtworkScript executeAndReturnError:&scriptError];
		
		if (!scriptError)
		{
			NSData	*artworkData = [(NSAppleEventDescriptor *)getTrackArtworkResult data];
		
			if (artworkData)
			{
				NS_DURING
					image = [[[NSImage alloc] initWithData:artworkData] autorelease];
					if (image)
						[(NSMutableDictionary *)parameter setObject:image forKey:@"Image"];
				NS_HANDLER
				NS_ENDHANDLER
				
				if (!image)
					NSLog(@"Track ID %@ does not have valid artwork.", trackID);
			}
		}
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
	return nil;
}	


- (void)reset
{
	[self setPlaylistName:playlistName];
}


- (void)dealloc
{
	[playlistName release];
	[sourceDescription release];
	[remainingTrackIDs release];
	
	[super dealloc];
}


@end

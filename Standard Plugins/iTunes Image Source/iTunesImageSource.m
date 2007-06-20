/*
	iTunesImageSource.m
	MacOSaiX

	Created by Frank Midgley on Thu May 18 2006.
	Copyright (c) 2006 Frank M. Midgley. All rights reserved.
*/

#import "iTunesImageSource.h"

#import "iTunesImageSourceController.h"
#import "iTunesImageSourcePlugIn.h"
#import "NSData+MacOSaiX.h"
#import "NSString+MacOSaiX.h"
#import <pthread.h>


@interface MacOSaiXiTunesImageSource (PrivateMethods)
- (NSString *)pathOfTrackWithID:(NSString *)trackID;
@end


@implementation MacOSaiXiTunesImageSource


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


- (id)initWithPlaylistName:(NSString *)name
{
	if (self = [super init])
	{
		[self setPlaylistName:name];
	}

    return self;
}


- (BOOL)settingsAreValid
{
	return YES;
}


+ (NSString *)settingsExtension
{
	return @"plist";
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	NSMutableDictionary	*settings = [NSMutableDictionary dictionaryWithObject:remainingTrackIDs
																	   forKey:@"Remaining Track IDs"];
	
	if ([self playlistName])
		[settings setObject:[self playlistName] forKey:@"Playlist"];
	if (artworkChecksums)
		[settings setObject:artworkChecksums forKey:@"Artwork Checksums"];
	
	return [settings writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	[self setPlaylistName:[settings objectForKey:@"Playlist"]];
	remainingTrackIDs = [[settings objectForKey:@"Remaining Track IDs"] retain];
	
	return YES;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:@"Element Type"];
	
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
	
	[sourceDescription autorelease];
	
	if (!name)
		sourceDescription = nil;
	else
	{
		sourceDescription = [[NSString stringWithFormat:NSLocalizedString(@"Album artwork from \"%@\"", @""), playlistName] retain];
		
			// Indicate that the track ID's need to be retrieved.
		[remainingTrackIDs autorelease];
		remainingTrackIDs = nil;
	}
	
	[artworkChecksums release];
	artworkChecksums = [[NSMutableDictionary dictionary] retain];
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[MacOSaiXiTunesImageSource allocWithZone:zone] initWithPlaylistName:playlistName];
}


- (NSImage *)image;
{
	return ([self playlistName] ? [MacOSaiXiTunesImageSourcePlugIn playlistImage] : [MacOSaiXiTunesImageSourcePlugIn image]);
}


- (id)briefDescription
{
	if (!sourceDescription)
		sourceDescription = [[NSString stringWithString:NSLocalizedString(@"All album artwork", @"")] retain];
	
	return [[sourceDescription retain] autorelease];
}


- (NSNumber *)aspectRatio
{
	return [NSNumber numberWithFloat:1.0];
}


- (BOOL)hasMoreImages
{
	return (!remainingTrackIDs || [remainingTrackIDs count] > 0);
}


- (NSNumber *)imageCount
{
	return nil;
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


- (NSData *)artworkDataForTrackID:(NSString *)trackID
{
	NSData		*artworkData = nil;
	
	if (!pthread_main_np())
	{
		NSMutableDictionary	*parameters = [NSMutableDictionary dictionaryWithObject:trackID forKey:@"Track ID"];
		[self performSelectorOnMainThread:_cmd withObject:parameters waitUntilDone:YES];
		artworkData = [parameters objectForKey:@"Artwork Data"];
	}
	else
	{
		BOOL					useDict = [trackID isKindOfClass:[NSDictionary class]];
		NSString				*realTrackID = (useDict ? [(NSDictionary *)trackID objectForKey:@"Track ID"] : trackID);
		
		NSString				*getTrackArtworkText = [NSString stringWithFormat:
			@"tell application \"iTunes\" to " \
			@"get data of first artwork of (first track of " \
			@"first library playlist of (first source whose kind is library) " \
			@"whose database ID is %@)", realTrackID];
		NSAppleScript			*getTrackArtworkScript = [[[NSAppleScript alloc] initWithSource:getTrackArtworkText] autorelease];
		NSDictionary			*scriptError = nil;
		NSAppleEventDescriptor	*getTrackArtworkResult = [getTrackArtworkScript executeAndReturnError:&scriptError];
		
		if (!scriptError)
		{
			artworkData = [(NSAppleEventDescriptor *)getTrackArtworkResult data];
			
			if (artworkData && useDict)
				[(NSMutableDictionary *)trackID setObject:artworkData forKey:@"Artwork Data"];
		}
	}
			
	return artworkData;
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	NSImage			*image = nil;
	
	if (!remainingTrackIDs)
		[self getTrackIDs];
	
	while (!image && [remainingTrackIDs count] > 0)
	{
			// Get the artwork data for this track.
		NSString		*trackID = [remainingTrackIDs objectAtIndex:0];
		NSData			*artworkData = [self artworkDataForTrackID:trackID];
		
		if (artworkData)
		{
				// Check if we have already used this artwork.
			NSString		*artworkChecksum = [artworkData checksum];
			NSMutableArray	*possibleDups = [artworkChecksums objectForKey:artworkChecksum];
			NSEnumerator	*dupTrackEnumerator = [possibleDups objectEnumerator];
			NSString		*dupTrackID = nil;
			
			while (dupTrackID = [dupTrackEnumerator nextObject])
			{
				if ([artworkData isEqualToData:[self artworkDataForTrackID:dupTrackID]]);
					break;
			}
			
			if (!dupTrackID)
			{
					// This is new artwork.
				NS_DURING
					image = [[[NSImage alloc] initWithData:[self artworkDataForTrackID:trackID]] autorelease];
					#ifdef DEBUG
						if (!image)
							NSLog(@"Could not create the album image for track ID %@", trackID);
					#endif
				NS_HANDLER
					#ifdef DEBUG
						NSLog(@"Could not create the album image for track ID %@: %@", trackID, [localException reason]);
					#endif
				NS_ENDHANDLER
					
				if (image)
				{
					*identifier = [[trackID retain] autorelease];
					
						// Remember the artwork's checksum and track ID for future comparisons.
					if (!artworkChecksums)
						artworkChecksums = [[NSMutableDictionary dictionary] retain];
					if (!possibleDups)
					{
						possibleDups = [NSMutableArray array];
						[artworkChecksums setObject:possibleDups forKey:artworkChecksum];
					}
					[possibleDups addObject:trackID];
				}
			}
		}
		
		[remainingTrackIDs removeObjectAtIndex:0];
	}

    return image;
}


- (BOOL)canRefetchImages
{
	return YES;
}


- (id<NSCopying>)universalIdentifierForIdentifier:(NSString *)identifier
{
	return identifier;
}


- (NSImage *)thumbnailForIdentifier:(NSString *)identifier
{
	return nil;
}


- (NSImage *)imageForIdentifier:(NSString *)trackID
{
	NSImage		*image = nil;
	
	NS_DURING
		image = [[[NSImage alloc] initWithData:[self artworkDataForTrackID:trackID]] autorelease];
		#ifdef DEBUG
			if (!image)
				NSLog(@"Could not create the album image for track ID %@", trackID);
		#endif
	NS_HANDLER
		#ifdef DEBUG
			NSLog(@"Could not create the album image for track ID %@: %@", trackID, [localException reason]);
		#endif
	NS_ENDHANDLER
	
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


- (NSString *)descriptionForIdentifier:(NSString *)param
{
	NSString	*description = nil;
	
	if (!pthread_main_np())
	{
		NSMutableDictionary	*params = [NSMutableDictionary dictionaryWithObject:param forKey:@"Track ID"];
		[self performSelectorOnMainThread:_cmd withObject:params waitUntilDone:YES];
		description = [NSString stringWithFormat:@"%@: %@", [params objectForKey:@"Artist"], [params objectForKey:@"Album"]];
	}
	else
	{
		BOOL			paramIsDict = [param isKindOfClass:[NSDictionary class]];
		NSString		*trackID = (paramIsDict ? [(NSDictionary *)param objectForKey:@"Track ID"] : param);
		NSString		*scriptText = [NSString stringWithFormat:
											@"tell application \"iTunes\" to " \
											@"get {artist, album} of (first track of first library playlist of " \
											@"(first source whose kind is library) whose database ID is %@)", 
											trackID];
		
		NSAppleScript			*getTrackDescScript = [[[NSAppleScript alloc] initWithSource:scriptText] autorelease];
		NSDictionary			*scriptError = nil;
		NSAppleEventDescriptor	*getTrackDescResult = [getTrackDescScript executeAndReturnError:&scriptError];
		
		if (!scriptError && [getTrackDescResult numberOfItems] == 2)
		{
			NSString	*artist = [[getTrackDescResult descriptorAtIndex:1] stringValue],
						*album = [[getTrackDescResult descriptorAtIndex:2] stringValue];
			
			if (paramIsDict)
			{
				[(NSMutableDictionary *)param setObject:artist forKey:@"Artist"];
				[(NSMutableDictionary *)param setObject:album forKey:@"Album"];
			}
			else
				description = [NSString stringWithFormat:@"%@: %@", artist, album];
		}
	}
	
	return description;
}	


- (void)reset
{
	[self setPlaylistName:playlistName];
}


- (BOOL)imagesShouldBeRemovedForLastChange
{
	return YES;
}


- (void)dealloc
{
	[playlistName release];
	[sourceDescription release];
	[remainingTrackIDs release];
	
	[super dealloc];
}


@end

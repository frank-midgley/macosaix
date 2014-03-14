/*
	iPhotoImageSource.m
	MacOSaiX

	Created by Frank Midgley on Wed Mar 15 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "MacOSaiXiTunesImageSource.h"
#import "MacOSaiXiTunesImageSourceEditor.h"

#import "NSData+MacOSaiX.h"
#import "NSString+MacOSaiX.h"

#import <pthread.h>


static NSImage				*iTunesImage = nil,
							*musicImage = nil, 
							*audiobooksImage = nil, 
							*purchasedImage = nil, 
							*smartPlaylistImage = nil, 
							*playlistImage = nil;

static NSLock				*cachedArtworkLock;
static NSMutableDictionary	*cachedArtworkData;
static NSMutableArray		*cachedArtworkRecency;
static unsigned long		cachedArtworkSize;

@implementation MacOSaiXiTunesImageSource


+ (void)initialize
{
	NSURL		*iTunesAppURL = nil;
	OSStatus	status = LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.iTunes"), NULL, NULL, (CFURLRef *)&iTunesAppURL);
	
	if (status == noErr && iTunesAppURL)
	{
		NSBundle	*iTunesBundle = [NSBundle bundleWithPath:[iTunesAppURL path]];
		
		iTunesImage = [[NSImage alloc] initWithContentsOfFile:[iTunesBundle pathForImageResource:@"iTunes"]];
		
		CFRelease(iTunesAppURL);
	}
		
	NSBundle	*selfBundle = [NSBundle bundleForClass:[self class]];
	musicImage = [[NSImage alloc] initWithContentsOfFile:[selfBundle pathForImageResource:@"Music"]];
	audiobooksImage = [[NSImage alloc] initWithContentsOfFile:[selfBundle pathForImageResource:@"Audiobooks"]];
	purchasedImage = [[NSImage alloc] initWithContentsOfFile:[selfBundle pathForImageResource:@"Purchased"]];
	smartPlaylistImage = [[NSImage alloc] initWithContentsOfFile:[selfBundle pathForImageResource:@"Smart Playlist"]];
	playlistImage = [[NSImage alloc] initWithContentsOfFile:[selfBundle pathForImageResource:@"Playlist"]];
	
	cachedArtworkLock = [[NSLock alloc] init];
	cachedArtworkData = [[NSMutableDictionary alloc] init];
	cachedArtworkRecency = [[NSMutableArray alloc] init];
	cachedArtworkSize = 0;
	
	#if 0
		unsigned long crc_table[256];
		{
			unsigned long c;
			int n, k;
			
			for (n = 0; n < 256; n++) {
				c = (unsigned long) n;
				for (k = 0; k < 8; k++) {
					if (c & 1)
						c = 0xedb88320L ^ (c >> 1);
					else
						c = c >> 1;
				}
				crc_table[n] = c;
			}
		}
		
		unsigned char	tIME_buffer[11] = {'t', 'I', 'M', 'E', 0, 0, 0, 0, 0, 0, 0};
		unsigned long	c = 0xffffffffL;
		unsigned char	*buf = tIME_buffer;
		int				len = 11, 
						n;
		
		for (n = 0; n < len; n++)
			c = crc_table[(c ^ buf[n]) & 0xff] ^ (c >> 8);
		
		unsigned long	crc = c ^ 0xffffffffL;
		NSLog(@"tIME CRC = %ld", crc);
	#endif
	
}


+ (NSImage *)image
{
	return iTunesImage;
}


+ (NSImage *)musicImage
{
	return musicImage;
}


+ (NSImage *)audiobooksImage
{
	return audiobooksImage;
}


+ (NSImage *)purchasedImage
{
	return purchasedImage;
}


+ (NSImage *)smartPlaylistImage
{
	return smartPlaylistImage;
}


+ (NSImage *)playlistImage
{
	return playlistImage;
}


+ (Class)editorClass
{
	return [MacOSaiXiTunesImageSourceEditor class];
}


+ (Class)preferencesControllerClass
{
	return nil;
}


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


- (NSString *)settingsAsXMLElement
{
	NSMutableString	*settings = [NSMutableString string];
	
	if ([self playlistName])
		[settings appendFormat:@"<PLAYLIST NAME=\"%@\"/>\n", [[self playlistName] stringByEscapingXMLEntites]];
	
	[settings appendFormat:@"<TRACK_IDS REMAINING=\"%@\"/>\n", [remainingTrackIDs componentsJoinedByString:@","]];
	
	[settings appendString:@"<ARTWORK_CHECKSUMS>\n"];
	NSEnumerator	*checksumEnumerator = [artworkChecksums keyEnumerator];
	NSString		*checksum = nil;
	while (checksum = [checksumEnumerator nextObject])
	{
		[settings appendFormat:@"\t<ARTWORK CHECKSUM=\"%@\" TRACK_IDS=\"%@\"/>\n", 
								checksum, [[artworkChecksums objectForKey:checksum] componentsJoinedByString:@","]];
		
	}
	[settings appendString:@"</ARTWORK_CHECKSUMS>\n"];
	
	return settings;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:@"Element Type"];
	
	if ([settingType isEqualToString:@"PLAYLIST"])
		[self setPlaylistName:[[[settingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites]];
	else if ([settingType isEqualToString:@"TRACK_IDS"])
		remainingTrackIDs = [[[[settingDict objectForKey:@"REMAINING"] description] componentsSeparatedByString:@","] mutableCopy];
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	NSString	*settingType = [childSettingDict objectForKey:@"Element Type"];

	if ([settingType isEqualToString:@"ARTWORK"])
	{
		NSString	*checksum = [childSettingDict objectForKey:@"CHECKSUM"];
		NSArray		*trackIDs = [[childSettingDict objectForKey:@"TRACK_IDS"] componentsSeparatedByString:@","];
		
		[artworkChecksums setObject:[NSMutableArray arrayWithArray:trackIDs] forKey:checksum];
	}
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
	return iTunesImage;
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


- (NSData *)artworkDataForTrackID:(NSString *)trackID
{
	NSData		*artworkData = nil;
	BOOL		useDict = [trackID isKindOfClass:[NSDictionary class]];
	
	if (!useDict)	// avoid a second lock when the data needs to be fetched
	{
		[cachedArtworkLock lock];
			artworkData = [cachedArtworkData objectForKey:trackID];
		[cachedArtworkLock unlock];
	}
	
	if (!artworkData)
	{
		if (!pthread_main_np())
		{
			NSMutableDictionary	*parameters = [NSMutableDictionary dictionaryWithObject:trackID forKey:@"Track ID"];
			[self performSelectorOnMainThread:_cmd withObject:parameters waitUntilDone:YES];
			artworkData = [parameters objectForKey:@"Artwork Data"];
		}
		else
		{
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
				
				unsigned char	pngChunkLengthAndType[8], 
								tIMELengthAndType[8] = {0, 0, 0, 7, 't', 'I', 'M', 'E'};
				int				offset;
				for (offset = 150; offset < 400; offset++)
				{
					[artworkData getBytes:pngChunkLengthAndType range:NSMakeRange(offset, 8)];
					
					if (memcmp(pngChunkLengthAndType, tIMELengthAndType, 8) == 0)
					{
						NSMutableData	*mutableData = [NSMutableData dataWithData:artworkData];
						unsigned char	tIME_buffer[15] = {'t', 'I', 'M', 'E', 0, 0, 0, 0, 0, 0, 0, 0x09, 0x73, 0x94, 0x2e};
						
						[mutableData replaceBytesInRange:NSMakeRange(offset + 4, 15) withBytes:tIME_buffer];
						artworkData = mutableData;
						
						break;
					}
				}
				
				if (artworkData && useDict)
					[(NSMutableDictionary *)trackID setObject:artworkData forKey:@"Artwork Data"];
			}
		}
	}
	
	return artworkData;
}


- (void)cacheArtworkData:(NSData *)artworkData forTrackID:(NSString *)trackID
{
	[cachedArtworkLock lock];
		if (![cachedArtworkData objectForKey:trackID])
		{
			[cachedArtworkData setObject:artworkData forKey:trackID];
			[cachedArtworkRecency insertObject:trackID atIndex:0];
			cachedArtworkSize += [artworkData length];
			
				// Limit the cache to 32 MB
			while (cachedArtworkSize > 32 * 1024 * 1024)
			{
				NSString	*oldestTrackID = [cachedArtworkRecency lastObject];
				cachedArtworkSize -= [(NSData *)[cachedArtworkData objectForKey:oldestTrackID] length];
				[cachedArtworkData removeObjectForKey:oldestTrackID];
				[cachedArtworkRecency removeLastObject];
			}
		}
	[cachedArtworkLock unlock];
}


- (NSError *)nextImage:(NSImage **)image andIdentifier:(NSString **)identifier
{
	NSError			*error = nil;
	
	*image = nil;
	*identifier = nil;
	
	if (!remainingTrackIDs)
		[self getTrackIDs];
	
	if ([remainingTrackIDs count] > 0)
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
				if ([artworkData isEqualToData:[self artworkDataForTrackID:dupTrackID]])
					break;
			}
			
			if (!dupTrackID)
			{
				// This is new artwork.
//				[artworkData writeToFile:[NSString stringWithFormat:@"/Users/knarf/Pictures/iTunes Album Artwork/%@.pict", trackID] atomically:NO];
				
				NS_DURING
					*image = [[[NSImage alloc] initWithData:artworkData] autorelease];
					#ifdef DEBUG
						if (!*image)
							NSLog(@"Could not create the album image for track ID %@", trackID);
					#endif
				NS_HANDLER
					#ifdef DEBUG
						NSLog(@"Could not create the album image for track ID %@: %@", trackID, [localException reason]);
					#endif
				NS_ENDHANDLER
				
				if (*image)
				{
					[self cacheArtworkData:artworkData forTrackID:trackID];
					
//					[[*image TIFFRepresentation] writeToFile:[NSString stringWithFormat:@"/Users/knarf/Pictures/iTunes Album Artwork/%@.tiff", trackID] atomically:NO];
					
					*identifier = [[trackID retain] autorelease];
					
					// Remember the artwork's checksum and track ID for future comparisons.
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
	NSData		*artworkData = [self artworkDataForTrackID:identifier];
	
	NS_DURING
		image = [[[NSImage alloc] initWithData:artworkData] autorelease];
		#ifdef DEBUG
			if (!image)
				NSLog(@"Could not create the album image for track ID %@", identifier);
		#endif
	NS_HANDLER
		#ifdef DEBUG
			NSLog(@"Could not create the album image for track ID %@: %@", identifier, [localException reason]);
		#endif
	NS_ENDHANDLER
	
	if (image)
		[self cacheArtworkData:artworkData forTrackID:identifier];
		
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
	NSString	*description = nil;
	
	if (!pthread_main_np())
	{
		NSMutableDictionary	*params = [NSMutableDictionary dictionaryWithObject:identifier forKey:@"Track ID"];
		[self performSelectorOnMainThread:_cmd withObject:params waitUntilDone:YES];
		description = [NSString stringWithFormat:@"%@: %@", [params objectForKey:@"Artist"], [params objectForKey:@"Album"]];
	}
	else
	{
		BOOL			paramIsDict = [identifier isKindOfClass:[NSDictionary class]];
		NSString		*trackID = (paramIsDict ? [(NSDictionary *)identifier objectForKey:@"Track ID"] : identifier);
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
				[(NSMutableDictionary *)identifier setObject:artist forKey:@"Artist"];
				[(NSMutableDictionary *)identifier setObject:album forKey:@"Album"];
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


- (void)dealloc
{
	[playlistName release];
	[sourceDescription release];
	[remainingTrackIDs release];
	
	[super dealloc];
}


@end

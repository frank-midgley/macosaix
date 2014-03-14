//
//  iPhotoDatabase.m
//  MacOSaiX
//
//  Created by Frank Midgley on 7/12/11.
//  Copyright 2011 Frank M. Midgley. All rights reserved.
//

#import "iPhotoDatabase.h"
#import "NSString+MacOSaiX.h"
#import <pthread.h>


static MacOSaiXiPhotoDatabase *sharedDatabase = NULL;


@interface MacOSaiXiPhotoDatabase (PrivateMethods)
- (void)loadAlbums;
- (void)loadKeywords;
- (void)loadEvents;
@end


@implementation MacOSaiXiPhotoDatabase


+ (MacOSaiXiPhotoDatabase *)sharedDatabase
{
	if (!sharedDatabase)
		sharedDatabase = [[MacOSaiXiPhotoDatabase alloc] init];
	
	return sharedDatabase;
}


- (id)init
{
	if ((self = [super init]))
	{
		// Try to get current iPhoto icons.
		NSURL		*iPhotoAppURL = nil;
		OSStatus	status = LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.iPhoto"), NULL, NULL, (CFURLRef *)&iPhotoAppURL);
		
		if (status == noErr && iPhotoAppURL)
		{
			NSBundle	*iPhotoBundle = [NSBundle bundleWithPath:[iPhotoAppURL path]];
			
			appImage = [[NSImage alloc] initWithContentsOfFile:[iPhotoBundle pathForImageResource:@"NSApplicationIcon"]];
			
			@try
			{
				albumImage = [[NSImage alloc] initWithContentsOfFile:[iPhotoBundle pathForImageResource:@"sl-icon_album.tiff"]];
			}
			@catch (NSException *e)
			{
				albumImage = [[NSImage alloc] initWithContentsOfFile:[iPhotoBundle pathForImageResource:@"album_local"]];
			}
			[albumImage setScalesWhenResized:YES];
			[albumImage setSize:NSMakeSize(16.0, 16.0)];
			
			keywordImage = [[NSImage alloc] initWithContentsOfFile:[iPhotoBundle pathForImageResource:@"search_keyword-icon.tiff"]];
			[keywordImage setScalesWhenResized:YES];
			[keywordImage setSize:NSMakeSize(16.0, 16.0)];
			
			CFRelease(iPhotoAppURL);
		}
		
		// Try to load the iPhoto Library XML PList.
		NSArray	*directories = NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSAllDomainsMask, YES);
		if ([directories count] > 0)
		{
			NSString	*libraryPListPath = [[[directories objectAtIndex:0] stringByAppendingPathComponent:@"iPhoto Library"] 
											 								stringByAppendingPathComponent:@"AlbumData.xml"];
			NSURL		*libraryPListURL = [NSURL fileURLWithPath:libraryPListPath];
			NSData		*libraryPListData = [NSData dataWithContentsOfURL:libraryPListURL];
			NSString	*error = [NSString string];
			libraryPList = [[NSPropertyListSerialization propertyListFromData:libraryPListData 
															 mutabilityOption:NSPropertyListImmutable 
																	   format:NULL 
															 errorDescription:&error] retain];
			
			// TBD: Set up a watch on the XML file in case the user makes changes in iPhoto?  Would need locking...
		}
		
		[self loadAlbums];
		[self loadKeywords];
		[self loadEvents];
		
		if (libraryPList)
			photos = [[libraryPList objectForKey:@"Master Image List"] retain];
	}
	
	return self;
}


- (NSImage *)appImage
{
	return appImage;
}


- (void)pathOfPhotoWithParameters:(NSMutableDictionary *)parameters
{
	NSString	*photoPath = [self pathOfPhotoWithID:[parameters objectForKey:@"Photo ID"]];
	
	if (photoPath)
		[parameters setObject:photoPath forKey:@"Photo Path"];
}


- (NSString *)pathOfPhotoWithID:(NSString *)photoID
{
	NSString		*imagePath = nil;
	
	if (libraryPList)
		imagePath = [[photos objectForKey:photoID] objectForKey:@"ImagePath"];
	else if (!pthread_main_np())
	{
		NSMutableDictionary	*parameters = [NSMutableDictionary dictionaryWithObject:photoID forKey:@"Photo ID"];
		[self performSelectorOnMainThread:@selector(pathOfPhotoWithParameters:) withObject:parameters waitUntilDone:YES];
		imagePath = [parameters objectForKey:@"Photo Path"];
	}
	else
	{
		NSString				*getImagePathText = [NSString stringWithFormat:@"tell application \"iPhoto\" to " \
													 @"get image path of first photo whose id is %@", 
													 photoID];
		NSAppleScript			*getImagePathScript = [[[NSAppleScript alloc] initWithSource:getImagePathText] autorelease];
		NSDictionary			*scriptError = nil;
		NSAppleEventDescriptor	*getImagePathResult = [getImagePathScript executeAndReturnError:&scriptError];
		
		if (!scriptError)
			imagePath = [(NSAppleEventDescriptor *)getImagePathResult stringValue];
	}
	
	return imagePath;
}


- (void)titleOfPhotoWithParameters:(NSMutableDictionary *)parameters
{
	NSString	*title = [self titleOfPhotoWithID:[parameters objectForKey:@"Photo ID"]];
	
	if (title)
		[parameters setObject:title forKey:@"Photo Title"];
}


- (NSString *)titleOfPhotoWithID:(NSString *)photoID
{
	NSString		*title = nil;
	
	if (libraryPList)
		title = [[photos objectForKey:photoID] objectForKey:@"Caption"];
	else if (!pthread_main_np())
	{
		NSMutableDictionary	*parameters = [NSMutableDictionary dictionaryWithObject:photoID forKey:@"Photo ID"];
		[self performSelectorOnMainThread:@selector(titleOfPhotoWithParameters:) withObject:parameters waitUntilDone:YES];
		title = [parameters objectForKey:@"Photo Title"];
	}
	else
	{
		NSString				*getImageTitleText = [NSString stringWithFormat:@"tell application \"iPhoto\" to get title of first photo whose id is %@", photoID];
		NSAppleScript			*getImageTitleScript = [[[NSAppleScript alloc] initWithSource:getImageTitleText] autorelease];
		NSDictionary			*scriptError = nil;
		NSAppleEventDescriptor	*getImageTitleResult = [getImageTitleScript executeAndReturnError:&scriptError];
		
		if (!scriptError)
		{
			title = [(NSAppleEventDescriptor *)getImageTitleResult stringValue];
			
			if (title && [title length] == 0)
			{
				NSString	*photoPath = [self pathOfPhotoWithID:photoID];
				
				photoPath = [[photoPath lastPathComponent] stringByDeletingPathExtension];
				
				if ([photoPath length] > 0)
					title = photoPath;
				else
					title = nil;
			}
		}
	}
	
	return title;
}	


- (NSArray *)photoIDs
{
	NSArray	*photoIDs = [NSArray array];
	
	if (libraryPList)
		photoIDs = [[libraryPList objectForKey:@"Master Image List"] allKeys];
	else if (!pthread_main_np())
	{
		// TODO: Not sure this is working...
		[self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone:YES];
	}
	else
	{
		NSString		*scriptText = @"tell application \"iPhoto\" to get id of photos";
		NSAppleScript	*getPhotoIDsScript = [[[NSAppleScript alloc] initWithSource:scriptText] autorelease];
		NSDictionary	*scriptError = nil;
		id				getPhotoIDsResult = [getPhotoIDsScript executeAndReturnError:&scriptError];
		
		photoIDs = [NSMutableArray array];
		
		if (!scriptError)
		{
			int	photoIDCount = [(NSAppleEventDescriptor *)getPhotoIDsResult numberOfItems],
			photoIDIndex;
			for (photoIDIndex = 1; photoIDIndex <= photoIDCount; photoIDIndex++)
				[(NSMutableArray *)photoIDs addObject:[[(NSAppleEventDescriptor *)getPhotoIDsResult descriptorAtIndex:photoIDIndex] stringValue]];
		}
	}
	
	return photoIDs;
}





#pragma mark -
#pragma mark Albums


- (NSImage *)albumImage
{
	return albumImage;
}


- (void)loadAlbums
{
	if (libraryPList)
		albums = [[libraryPList objectForKey:@"List of Albums"] retain];
	else
	{
		// Try to get the album names via AppleScript.
		
		albums = [[NSMutableArray array] retain];
		
		NSString				*getAlbumNamesText = @"tell application \"iPhoto\" to get name of albums";
		NSAppleScript			*getAlbumNamesScript = [[[NSAppleScript alloc] initWithSource:getAlbumNamesText] autorelease];
		NSDictionary			*getAlbumNamesError = nil;
		NSAppleEventDescriptor	*getAlbumNamesResult = [getAlbumNamesScript executeAndReturnError:&getAlbumNamesError];
		if (getAlbumNamesResult)
		{
			// Add an item for each album.
			int			albumCount = [getAlbumNamesResult numberOfItems],
			albumIndex = 1;
			for (albumIndex = 1; albumIndex <= albumCount; albumIndex++)
			{
				NSString	*albumName = [[getAlbumNamesResult descriptorAtIndex:albumIndex] stringValue];
				
				[(NSMutableArray *)albums addObject:[NSDictionary dictionaryWithObject:albumName forKey:@"AlbumName"]];
			}
		}
	}
}


- (NSArray *)albumNames
{
	NSMutableArray	*albumNames = [NSMutableArray arrayWithCapacity:[albums count]];
	
	for (NSDictionary *album in albums)
		[albumNames addObject:[album objectForKey:@"AlbumName"]];
	
	return [albumNames sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}


- (NSArray *)photoIDsFromAlbum:(NSString *)albumName
{
	NSArray	*photoIDs = [NSArray array];
	
	if (libraryPList)
	{
		for (NSDictionary *album in albums)
			if ([[album objectForKey:@"AlbumName"] isEqualToString:albumName])
			{
				photoIDs = [album objectForKey:@"KeyList"];
				break;
			}
	}
	else if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone:YES];
	else
	{
		NSString		*scriptText = [NSString stringWithFormat:@"tell application \"iPhoto\" to get id of photos of album \"%@\"", albumName];
		NSAppleScript	*getPhotoIDsScript = [[[NSAppleScript alloc] initWithSource:scriptText] autorelease];
		NSDictionary	*scriptError = nil;
		id				getPhotoIDsResult = [getPhotoIDsScript executeAndReturnError:&scriptError];
		
		photoIDs = [NSMutableArray array];
		
		if (!scriptError)
		{
			int	photoIDCount = [(NSAppleEventDescriptor *)getPhotoIDsResult numberOfItems],
			photoIDIndex;
			for (photoIDIndex = 1; photoIDIndex <= photoIDCount; photoIDIndex++)
				[(NSMutableArray *)photoIDs addObject:[[(NSAppleEventDescriptor *)getPhotoIDsResult descriptorAtIndex:photoIDIndex] stringValue]];
		}
	}
	
	return photoIDs;
}


#pragma mark -
#pragma mark Keywords


- (NSImage *)keywordImage
{
	return keywordImage;
}


- (NSArray *)keywordNames
{
	return [[keywords allValues] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}


- (void)loadKeywords
{
	if (libraryPList)
		keywords = [[libraryPList objectForKey:@"List of Keywords"] retain];
	else
	{
		// Try to get the album names via AppleScript.
		
		keywords = [NSMutableDictionary dictionary];
		
		NSString				*getKeywordNamesText = @"tell application \"iPhoto\" to get name of keywords";
		NSAppleScript			*getKeywordNamesScript = [[[NSAppleScript alloc] initWithSource:getKeywordNamesText] autorelease];
		NSDictionary			*getKeywordNamesError = nil;
		NSAppleEventDescriptor	*getKeywordNamesResult = [getKeywordNamesScript executeAndReturnError:&getKeywordNamesError];
		
		if (getKeywordNamesResult)
		{
			@try
			{
				// Get the name of each keyword.
				int			keywordCount = [getKeywordNamesResult numberOfItems],
				keywordIndex = 1;
				for (keywordIndex = 1; keywordIndex <= keywordCount; keywordIndex++)
				{
					NSAppleEventDescriptor  *keywordDesc = [getKeywordNamesResult descriptorAtIndex:keywordIndex];
					
					if ([keywordDesc stringValue])
						[(NSMutableDictionary *)keywords setObject:[keywordDesc stringValue] 
															forKey:[NSNumber numberWithInt:[keywords count]]];
				}
			}
			@catch (NSException *exception) {
				;
			}
		}
	}	
}


- (NSArray *)photoIDsForKeyword:(NSString *)keywordName
{
	NSMutableArray	*photoIDs = [NSMutableArray array];
	
	if (libraryPList)
	{
		// Loop through every image in the library and see if it has the keyword attached.
		NSDictionary	*keywordList = [libraryPList objectForKey:@"List of Keywords"];
		NSString		*keywordKey = [[keywordList allKeysForObject:keywordName] objectAtIndex:0];
		NSDictionary	*imageList = [libraryPList objectForKey:@"Master Image List"];
		
		for (NSString *imageKey in imageList)
		{
			NSArray *imageKeywordKeys = [[imageList objectForKey:imageKey] objectForKey:@"Keywords"];
			
			if ([imageKeywordKeys containsObject:keywordKey])
				 [photoIDs addObject:imageKey];
		}
	}
	else if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone:YES];
	else
	{
		NSString		*scriptText = [NSString stringWithFormat:@"tell application \"iPhoto\"\r" \
																  "set ids to {}\r" \
																  "repeat with thePhoto in (photos whose keywords is not {})\r" \
																  "set kws to name of keywords of thePhoto\r" \
																  "if kws contains \"%@\" then set ids to ids & (id of thePhoto)\r" \
																  "end repeat\r" \
																  "ids\r" \
																  "end tell", keywordName];
		NSAppleScript	*getPhotoIDsScript = [[[NSAppleScript alloc] initWithSource:scriptText] autorelease];
		NSDictionary	*scriptError = nil;
		id				getPhotoIDsResult = [getPhotoIDsScript executeAndReturnError:&scriptError];
		
		if (!scriptError)
		{
			int	photoIDCount = [(NSAppleEventDescriptor *)getPhotoIDsResult numberOfItems],
			photoIDIndex;
			for (photoIDIndex = 1; photoIDIndex <= photoIDCount; photoIDIndex++)
				[photoIDs addObject:[[(NSAppleEventDescriptor *)getPhotoIDsResult descriptorAtIndex:photoIDIndex] stringValue]];
		}
	}
	
	return photoIDs;
}


#pragma mark -
#pragma mark Events


- (NSImage *)eventImage
{
	return eventImage;
}


- (NSArray *)eventNames
{
	NSMutableArray	*eventNames = [NSMutableArray arrayWithCapacity:[albums count]];
	
	for (NSDictionary *event in events)
		[eventNames addObject:[event objectForKey:@"RollName"]];
	
	return eventNames;
}


- (void)loadEvents
{
	if (libraryPList)
		events = [[libraryPList objectForKey:@"List of Rolls"] retain];
	else
		events = [[NSArray array] retain];
}


- (NSArray *)photoIDsFromEvent:(NSString *)eventName
{
	NSMutableArray	*photoIDs = [NSMutableArray array];
	
	if (libraryPList)
	{
		for (NSDictionary *event in events)
			if ([[event objectForKey:@"RollName"] isEqualToString:eventName])
			{
				photoIDs = [event objectForKey:@"KeyList"];
				break;
			}
	}
	else if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone:YES];
	else
	{
		NSString		*scriptText = nil;
		if (eventName)
			scriptText = [NSString stringWithFormat:@"tell application \"iPhoto\" to get id of photos of events  \"%@\"", eventName];
		else if (eventName)
			// TODO: this is wrong, but can you even do this with older iPhotos that wouldn't be using the XML...
			scriptText = [NSString stringWithFormat:@"tell application \"iPhoto\"\r" \
						  "set ids to {}\r" \
						  "repeat with thePhoto in (photos whose keywords is not {})\r" \
						  "set kws to name of keywords of thePhoto\r" \
						  "if kws contains \"%@\" then set ids to ids & (id of thePhoto)\r" \
						  "end repeat\r" \
						  "ids\r" \
						  "end tell", eventName];
		else
			scriptText = @"tell application \"iPhoto\" to get id of photos";
		
		NSAppleScript	*getPhotoIDsScript = [[[NSAppleScript alloc] initWithSource:scriptText] autorelease];
		NSDictionary	*scriptError = nil;
		id				getPhotoIDsResult = [getPhotoIDsScript executeAndReturnError:&scriptError];
		
		if (!scriptError)
		{
			int	photoIDCount = [(NSAppleEventDescriptor *)getPhotoIDsResult numberOfItems],
			photoIDIndex;
			for (photoIDIndex = 1; photoIDIndex <= photoIDCount; photoIDIndex++)
				[photoIDs addObject:[[(NSAppleEventDescriptor *)getPhotoIDsResult descriptorAtIndex:photoIDIndex] stringValue]];
		}
	}
	
	return photoIDs;
}


@end
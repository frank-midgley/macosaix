/*
	DirectoryImageSource.m
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

#import "DirectoryImageSource.h"
#import "DirectoryImageSourceController.h"
#import "NSString+MacOSaiX.h"
#import "NSFileManager+MacOSaiX.h"


@implementation MacOSaiXDirectoryImageSource


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


+ (id<MacOSaiXImageSource>)imageSourceForUniversalIdentifier:(id<NSObject,NSCoding,NSCopying>)identifier
{
	MacOSaiXDirectoryImageSource	*source = [[self alloc] init];
	
	[source setPath:[[(NSURL *)identifier path]		stringByDeletingLastPathComponent]];
	
	return [source autorelease];
}


- (id)init
{
	if (self = [super init])
	{
		NSString	*initialPath = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] 
																				objectForKey:@"Last Chosen Folder"];
		
		if (!initialPath)
			initialPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"];	// TODO: Use FSFindFolder
		
		[self setPath:initialPath];
		[self setFollowsAliases:YES];
	}

    return self;
}


- (BOOL)settingsAreValid
{
	return ([[self path] length] > 0);
}


+ (NSString *)settingsExtension
{
	return @"plist";
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	return [[NSDictionary dictionaryWithObjectsAndKeys:
								[self path], @"Folder Path", 
								[NSNumber numberWithBool:[self followsAliases]], @"Follow Aliases", 
								lastEnumeratedPath, @"Last Visited Path", 
								[NSNumber numberWithInt:imageCount], @"Image Count", 
								nil] 
				writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	[self setPath:[settings objectForKey:@"Folder Path"]];
	[self setFollowsAliases:[[settings objectForKey:@"Follow Aliases"] boolValue]];
	lastEnumeratedPath = [[settings objectForKey:@"Last Visited Path"] retain];
	imageCount = [[settings objectForKey:@"Image Count"] intValue];
	
	return YES;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:@"Element Type"];
	
	if ([settingType isEqualToString:@"DIRECTORY"])
		[self setPath:[[[settingDict objectForKey:@"PATH"] description] stringByUnescapingXMLEntites]];
	else if ([settingType isEqualToString:@"FOLLOW_ALIASES"])
		[self setFollowsAliases:[[settingDict objectForKey:@"FOLLOW_ALIASES"] isEqualTo:@"Y"]]; 
	else if ([settingType isEqualToString:@"LAST_USED_SUB_PATH"])
		lastEnumeratedPath = [[[[settingDict objectForKey:@"LAST_USED_SUB_PATH"] description] stringByUnescapingXMLEntites] retain];
	else if ([settingType isEqualToString:@"IMAGE_COUNT"])
		imageCount = [[[settingDict objectForKey:@"IMAGECOUNT"] description] intValue];
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	// not needed
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
	// not needed
}


- (NSString *)path
{
	return [[directoryPath retain] autorelease];
}


- (void)setPath:(NSString *)path
{
	[directoryPath autorelease];
	directoryPath = [path copy];
	
		// Get the icon at this path for display in the sources table.
		// The table is refreshed often so we store the image in an ivar to avoid hitting the disk repeatedly.
	[directoryImage autorelease];
	directoryImage = (directoryPath ? [[[NSWorkspace sharedWorkspace] iconForFile:directoryPath] retain] : nil);
	
	[directoryName autorelease];
    directoryName = [[[NSFileManager defaultManager] displayNameAtPath:directoryPath] retain];
	
	pathsHaveBeenEnumerated = NO;
	[directoryEnumerator autorelease];
	directoryEnumerator = nil;
	
	[lastEnumeratedPath autorelease];
	lastEnumeratedPath = nil;
	
	haveMoreImages = YES;
	imageCount = 0;
}


- (BOOL)followsAliases
{
	return followAliases;
}


- (void)setFollowsAliases:(BOOL)flag
{
	followAliases = flag;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXDirectoryImageSource	*copy = [[MacOSaiXDirectoryImageSource allocWithZone:zone] init];
	
	[copy setPath:[self path]];
	[copy setFollowsAliases:[self followsAliases]];
	
	return copy;
}


- (NSImage *)image;
{
	return [[directoryImage retain] autorelease];
}


- (id)briefDescription
{
	return [[directoryName retain] autorelease];
}


- (NSNumber *)aspectRatio
{
	return nil;
}


- (BOOL)hasMoreImages
{
	return haveMoreImages;
}


- (NSNumber *)imageCount
{
	return nil;
}


- (void)updateImageCountInUserDefaults
{
	NSMutableDictionary	*plugInDefaults = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] 
													mutableCopy] autorelease];

	if (plugInDefaults)
	{
		NSMutableArray		*folderDicts = [[[plugInDefaults objectForKey:@"Folders"] mutableCopy] autorelease];
		
			// Check if this path is already in the list
		NSEnumerator		*folderEnumerator = [folderDicts objectEnumerator];
		NSDictionary		*folderDict = nil;
		while (folderDict = [folderEnumerator nextObject])
			if ([[folderDict objectForKey:@"Path"] isEqualToString:[self path]])
				break;
			
			// Update the image count if the user hasn't cleared this path from the list.
		if (folderDict)
		{
			NSMutableDictionary	*updatedFolderDict = [NSMutableDictionary dictionaryWithDictionary:folderDict];
			[updatedFolderDict setObject:[NSString stringWithFormat:@"%d", imageCount] forKey:@"Image Count"];
			
			[folderDicts removeObject:folderDict];
			[folderDicts addObject:updatedFolderDict];
			
			[plugInDefaults setObject:folderDicts forKey:@"Folders"];
			[[NSUserDefaults standardUserDefaults] setObject:plugInDefaults forKey:@"Folder Image Source"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	NSImage			*image = nil;
	NSString		*subPath = nil;
	
	if (!pathsHaveBeenEnumerated)
	{
			// Most importantly set up the enumerator that lets us walk through the directory.
		directoryEnumerator = [[[NSFileManager defaultManager] enumeratorAtPath:directoryPath followAliases:followAliases] retain];
		
		haveMoreImages = (directoryEnumerator != nil);
		
			// Find the closest ancestor of the last file we enumerated that still exists on disk.
		while ([lastEnumeratedPath length] > 0 && 
			   ![[NSFileManager defaultManager] fileExistsAtPath:[directoryPath stringByAppendingPathComponent:lastEnumeratedPath]])
			lastEnumeratedPath = [lastEnumeratedPath stringByDeletingLastPathComponent];
		
			// Enumerate past all of the images that were previously found.
		if ([lastEnumeratedPath length] > 0)
			do
				subPath = [directoryEnumerator nextObject];
			while (![subPath isEqualToString:lastEnumeratedPath]);
			
		pathsHaveBeenEnumerated = YES;
	}
	
		// Enumerate our directory until we find a valid image file or run out of files.
	do
	{
		if (subPath = [directoryEnumerator nextObject])
		{
			[lastEnumeratedPath release];
			lastEnumeratedPath = [subPath retain];
			
			image = [self thumbnailForIdentifier:subPath];
			
			if (!image)
				image = [self imageForIdentifier:subPath];
		}
	}
	while (subPath && !image);
	
	if (subPath)
	{
		*identifier = subPath;
		imageCount++;
	}
	else
	{
		haveMoreImages = NO;	// all done
		[self updateImageCountInUserDefaults];
	}
	
    return image;	// This will still be nil unless we found a valid image file.
}


- (BOOL)canRefetchImages
{
	return YES;
}


- (id<NSCopying>)universalIdentifierForIdentifier:(NSString *)identifier
{
	NSString	*fullPath = [[NSFileManager defaultManager] pathByResolvingAliasesInPath:[directoryPath stringByAppendingPathComponent:identifier]];
	
	return [NSURL fileURLWithPath:fullPath];
}


- (NSString *)identifierForUniversalIdentifier:(id<NSObject,NSCoding,NSCopying>)universalIdentifier
{
	NSString	*imagePath = [(NSURL *)universalIdentifier path];
	
	if ([imagePath hasPrefix:[self path]])
		return [imagePath substringFromIndex:[[self path] length]];
	else
		return nil;
}


- (NSImage *)thumbnailForIdentifier:(NSString *)identifier
{
	NSImage	*thumbnail = nil;

	if (NSClassFromString(@"CIImage"))
	{
			// Use ImageIO to check for a thumbnail in the file.
		NSString			*imagePath = [[NSFileManager defaultManager] pathByResolvingAliasesInPath:
												[directoryPath stringByAppendingPathComponent:identifier]];

		if (imagePath)
		{
			CGImageSourceRef	thumbnailSourceRef = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:imagePath], NULL);
			
			if (thumbnailSourceRef)
			{
				NSDictionary	*options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
																	   forKey:(NSString *)kCGImageSourceCreateThumbnailWithTransform];
				CGImageRef		thumbnailRef = CGImageSourceCreateThumbnailAtIndex(thumbnailSourceRef, 0, (CFDictionaryRef)options);
				
				if (thumbnailRef)
				{
						// There is a thumbnail so create an NSImage from it.
					CIImage	*ciThumbnail = [CIImage imageWithCGImage:thumbnailRef];
					
					if (ciThumbnail)
					{
						NSCIImageRep	*thumbnailRep = [NSCIImageRep imageRepWithCIImage:ciThumbnail];
						
						if (thumbnailRep)
						{
							thumbnail = [[[NSImage alloc] initWithSize:[thumbnailRep size]] autorelease];
							[thumbnail addRepresentation:thumbnailRep];
						}
					}
					
					CFRelease(thumbnailRef);
				}
				
				CFRelease(thumbnailSourceRef);
			}
		}
	}
	
	return thumbnail;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	NSImage		*image = nil;
	NSString	*fullPath = [[NSFileManager defaultManager] pathByResolvingAliasesInPath:
																[directoryPath stringByAppendingPathComponent:identifier]], 
				*fileType = [[[NSFileManager defaultManager] fileAttributesAtPath:fullPath traverseLink:NO] fileType];
	
	if ([fileType isEqualToString:NSFileTypeRegular])
	{
		NS_DURING
			image = [[[NSImage alloc] initWithContentsOfFile:fullPath] autorelease];
			if (!image)
			{
					// The image might have the wrong or a missing file extension so 
					// try init'ing it based on its contents instead.  This requires 
					// more memory so only do this if initWithContentsOfFile fails.
				NSData	*data = [[NSData alloc] initWithContentsOfFile:fullPath];
				image = [[[NSImage alloc] initWithData:data] autorelease];
				[data release];
			}
		NS_HANDLER
			NSLog(@"%@ is not a valid image file.", fullPath);
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
	NSString	*description = nil, 
				*fullPath = [[NSFileManager defaultManager] pathByResolvingAliasesInPath:
								[directoryPath stringByAppendingPathComponent:identifier]];
	
	if (MDItemCreate != nil)
	{
		MDItemRef	itemRef = MDItemCreate(kCFAllocatorDefault, (CFStringRef)fullPath);
		if (itemRef)
		{
			CFTypeRef	valueRef = MDItemCopyAttribute(itemRef, kMDItemFinderComment);
			
			description = [(id)valueRef autorelease];
			CFRelease(itemRef);
		}
	}
	
	if (!description)
		description = [[fullPath lastPathComponent] stringByDeletingPathExtension];
	
	return description;
}	


- (void)reset
{
	[self setPath:directoryPath];
}


- (BOOL)imagesShouldBeRemovedForLastChange
{
	return YES;
}


- (void)dealloc
{
	[directoryPath release];
	[lastEnumeratedPath release];
	[directoryImage release];
	[directoryName release];
	[directoryEnumerator release];
	
	[super dealloc];
}


@end

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

@implementation DirectoryImageSource


+ (NSString *)name
{
	return @"Folder";
}


+ (NSImage *)image
{
	NSImage	*image = [[NSWorkspace sharedWorkspace] iconForFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]];
	
	if (!image)
		image = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
	
	return image;
}


+ (Class)editorClass
{
	return [DirectoryImageSourceController class];
}


+ (Class)preferencesControllerClass
{
	return nil;
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


- (id)init
{
	if (self = [super init])
	{
		[self setPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]];
		[self setFollowsAliases:YES];
	}

    return self;
}


- (NSString *)settingsAsXMLElement
{
	return [NSString stringWithFormat:@"<DIRECTORY PATH=\"%@\" FOLLOW_ALIASES=\"%@\" " \
									  @"LAST_USED_SUB_PATH=\"%@\" IMAGE_COUNT=\"%d\"/>", 
									  [[self path] stringByEscapingXMLEntites],
									  ([self followsAliases] ? @"Y" : @"N"), 
									  [lastEnumeratedPath stringByEscapingXMLEntites], 
									  imageCount];
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
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
	
	[directoryDescriptor autorelease];
    directoryDescriptor = [[[NSFileManager defaultManager] attributedPath:directoryPath] retain];
	
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
	DirectoryImageSource	*copy = [[DirectoryImageSource allocWithZone:zone] init];
	
	[copy setPath:[self path]];
	[copy setFollowsAliases:[self followsAliases]];
	
	return copy;
}


- (NSImage *)image;
{
	return [[directoryImage retain] autorelease];
}


- (id)descriptor
{
	return [[directoryDescriptor retain] autorelease];
}


- (BOOL)hasMoreImages
{
	return haveMoreImages;
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
			NSString	*fullPath = [directoryPath stringByAppendingPathComponent:subPath];
			NSArray		*pathComponents = [fullPath pathComponents];
			unsigned	iPhotoLibraryIndex = [pathComponents indexOfObject:@"iPhoto Library"],
						thumbsIndex = 0,
						originalsIndex = 0;
			
			[lastEnumeratedPath release];
			lastEnumeratedPath = [subPath retain];
			
			if (iPhotoLibraryIndex != NSNotFound && iPhotoLibraryIndex < [pathComponents count] - 1)
			{
				NSArray *iPhotoLibraryPathComponents = [pathComponents subarrayWithRange:
							NSMakeRange(iPhotoLibraryIndex + 1, [pathComponents count] - iPhotoLibraryIndex - 1)];
				thumbsIndex = [iPhotoLibraryPathComponents indexOfObject:@"Thumbs"],
				originalsIndex = [iPhotoLibraryPathComponents indexOfObject:@"Originals"];
			}
			
				// If the path doesn't point to an iPhoto thumb or original then try to open it.
				// Otherwise we get duplicates of iPhoto images in the mosaic.
			if ((iPhotoLibraryIndex == NSNotFound || (thumbsIndex == NSNotFound && originalsIndex == NSNotFound)))
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


- (void)reset
{
	[self setPath:directoryPath];
}


- (void)dealloc
{
	[directoryPath release];
	[lastEnumeratedPath release];
	[directoryImage release];
	[directoryDescriptor release];
	[directoryEnumerator release];
	
	[super dealloc];
}


@end

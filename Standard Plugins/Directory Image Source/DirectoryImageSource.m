/*
	DirectoryImageSource.m
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

#import "DirectoryImageSource.h"
#import "DirectoryImageSourceController.h"


@implementation DirectoryImageSource


+ (NSString *)name
{
	return @"Local Directory";
}


+ (Class)editorClass
{
	return [DirectoryImageSourceController class];
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


- (id)initWithPath:(NSString *)path
{
	if (self = [super init])
	{
		[self setPath:path];
	}

    return self;
}


- (NSString *)settingsAsXMLElement
{
	return [NSString stringWithFormat:@"<DIRECTORY PATH=\"%@\" LAST_USED_SUB_PATH=\"%@\"/>", [self path], lastEnumeratedPath];
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"DIRECTORY"])
		[self setPath:[[settingDict objectForKey:@"PATH"] description]];
	else if ([settingType isEqualToString:@"LAST_USED_SUB_PATH"])
		lastEnumeratedPath = [[[settingDict objectForKey:@"LAST_USED_SUB_PATH"] description] retain];
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	// not needed
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
//	[self updateQueryAndDescriptor];
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
	directoryImage = [[[NSWorkspace sharedWorkspace] iconForFile:directoryPath] retain];
	
		// Create an attributed string containing our path that truncates in the middle so that
		// the path's volume and nearest parent directories are both visible.
	NSMutableParagraphStyle	*style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
	NSDictionary			*attributeDict = [NSDictionary dictionaryWithObject:style forKey:NSParagraphStyleAttributeName];
	[directoryDescriptor autorelease];
    directoryDescriptor = [[NSAttributedString alloc] initWithString:directoryPath attributes:attributeDict];

		// Most importantly set up the enumerator that lets us walk through the directory.
	[directoryEnumerator autorelease];
	directoryEnumerator = [[[NSFileManager defaultManager] enumeratorAtPath:directoryPath] retain];
	haveMoreImages = (directoryEnumerator != nil);
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[DirectoryImageSource allocWithZone:zone] initWithPath:directoryPath];
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


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	NSImage			*image = nil;
	NSString		*subPath = nil;
	NSFileManager	*fileManager = [NSFileManager defaultManager];
	
	if (!pathsHaveBeenEnumerated)
	{
			// Find the closest ancestor of the last file we enumerated that still exists on disk.
		while ([lastEnumeratedPath length] > 0 && 
			   ![fileManager fileExistsAtPath:[directoryPath stringByAppendingPathComponent:lastEnumeratedPath]])
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
			NSString		*fullPath = [directoryPath stringByAppendingPathComponent:subPath];
			NSArray			*pathComponents = [fullPath pathComponents];
			unsigned int	iPhotoLibraryIndex = [pathComponents indexOfObject:@"iPhoto Library"],
							thumbsIndex = [pathComponents indexOfObject:@"Thumbs"],
							originalsIndex = [pathComponents indexOfObject:@"Originals"];
			
			[lastEnumeratedPath release];
			lastEnumeratedPath = [subPath retain];
			
				// If the path doesn't point to an iPhoto thumb or original then try to open it.
				// Otherwise we get duplicates of iPhoto images in the mosaic.
			if ([[[fileManager fileAttributesAtPath:fullPath traverseLink:NO] fileType]	
					isEqualToString:NSFileTypeRegular] && 
				iPhotoLibraryIndex == NSNotFound || thumbsIndex < iPhotoLibraryIndex || originalsIndex < iPhotoLibraryIndex)
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
					}
				NS_HANDLER
					NSLog(@"%@ is not a valid image file.", fullPath);
				NS_ENDHANDLER
			}
		}
	}
	while (subPath && !image);
	
	if (subPath)
		*identifier = subPath;
	else
		haveMoreImages = NO;	// all done
	
    return image;	// This will still be nil unless we found a valid image file.
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	NSImage		*image = nil;
	NSString	*fullPath = [directoryPath stringByAppendingPathComponent:identifier];
	
	NS_DURING
		image = [[[NSImage alloc] initWithContentsOfFile:fullPath] autorelease];
		if (!image)
		{
				// The image might have the wrong or a missing file extension so 
				// try init'ing it based on its contents instead.  This requires 
				// more memory so only do this if initWithContentsOfFile fails.
			NSData	*data = [[NSData alloc] initWithContentsOfFile:fullPath];
			image = [[[NSImage alloc] initWithData:data] autorelease];
		}
	NS_HANDLER
		NSLog(@"%@ is not a valid image file.", [directoryPath stringByAppendingPathComponent:identifier]);
	NS_ENDHANDLER
	
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

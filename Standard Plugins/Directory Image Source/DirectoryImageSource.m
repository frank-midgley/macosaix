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


- (id)initWithPath:(NSString *)path
{
	if (self = [super init])
	{
		[self setPath:path];
	}

    return self;
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
	NSMutableParagraphStyle	*style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	NSDictionary			*attributeDict = [NSDictionary dictionaryWithObject:style forKey:NSParagraphStyleAttributeName];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[directoryDescriptor autorelease];
    directoryDescriptor = [[NSAttributedString alloc] initWithString:directoryPath attributes:attributeDict];

		// Most importantly set up the enumerator that lets us walk through the directory.
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
	NSImage		*image = nil;
	NSString	*subPath = nil;
		
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
				
				// If the path doesn't point to an iPhoto thumb or original then try to open it.
				// Otherwise we get duplicates of iPhoto images in the mosaic.
			if (iPhotoLibraryIndex == NSNotFound || thumbsIndex < iPhotoLibraryIndex || originalsIndex < iPhotoLibraryIndex)
			{
				NS_DURING
					image = [[NSImage alloc] initWithContentsOfFile:fullPath];
				NS_HANDLER
					// should something be logged?
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
	
	NS_DURING
		image = [[NSImage alloc] initWithContentsOfFile:[directoryPath stringByAppendingPathComponent:identifier]];
	NS_HANDLER
		// should something be logged?
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
	[directoryImage release];
	[directoryDescriptor release];
	[directoryEnumerator release];
	
	[super dealloc];
}


@end

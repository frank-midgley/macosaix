//
//  DirectoryImageSourcePlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 1/9/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "DirectoryImageSourcePlugIn.h"

#import "DirectoryImageSource.h"
#import "DirectoryImageSourceController.h"

@implementation MacOSaiXDirectoryImageSourcePlugIn


+ (NSImage *)image
{
	NSImage	*image = [[NSWorkspace sharedWorkspace] iconForFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]];
	
	if (!image)
		image = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
	
	return image;
}


+ (Class)dataSourceClass
{
	return [MacOSaiXDirectoryImageSource class];
}


+ (Class)dataSourceEditorClass
{
	return [MacOSaiXDirectoryImageSourceEditor class];
}


+ (Class)preferencesEditorClass
{
	return nil;
}


@end

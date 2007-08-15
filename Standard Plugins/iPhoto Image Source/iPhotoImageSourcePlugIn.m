//
//  iPhotoImageSourcePlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 7/23/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "iPhotoImageSourcePlugIn.h"

#import "iPhotoImageSource.h"
#import "iPhotoImageSourceController.h"


@implementation MacOSaiXiPhotoImageSourcePlugIn


+ (NSBundle *)iPhotoBundle
{
	NSURL		*iPhotoAppURL = nil;
	
	LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.iPhoto"), NULL, NULL, (CFURLRef *)&iPhotoAppURL);
	
	return [NSBundle bundleWithPath:[iPhotoAppURL path]];
}


+ (NSImage *)image
{
	static	NSImage	*iPhotoImage = nil;
	
	if (!iPhotoImage)
		iPhotoImage = [[NSImage alloc] initWithContentsOfFile:[[self iPhotoBundle] pathForImageResource:@"NSApplicationIcon"]];
	
	return iPhotoImage;
}


+ (NSImage *)albumImage
{
	static	NSImage	*albumImage = nil;
	
	if (!albumImage)
	{
		albumImage = [[NSImage alloc] initWithContentsOfFile:[[self iPhotoBundle] pathForImageResource:@"sl-icon-small_album"]];
		if (!albumImage)
			albumImage = [[NSImage alloc] initWithContentsOfFile:[[self iPhotoBundle] pathForImageResource:@"album_local"]];
		[albumImage setScalesWhenResized:YES];
		[albumImage setSize:NSMakeSize(16.0, 16.0)];
	}
	
	return albumImage;
}


+ (NSImage *)keywordImage
{
	return nil;
}


+ (Class)dataSourceClass
{
	return [MacOSaiXiPhotoImageSource class];
}


+ (Class)editorClass
{
	return [MacOSaiXiPhotoImageSourceEditor class];
}


+ (Class)preferencesEditorClass
{
	return nil;
}


@end

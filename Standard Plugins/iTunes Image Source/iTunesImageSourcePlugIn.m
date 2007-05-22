//
//  iTunesImageSourcePlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/17/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "iTunesImageSourcePlugIn.h"

#import "iTunesImageSource.h"
#import "iTunesImageSourceController.h"


@implementation MacOSaiXiTunesImageSourcePlugIn


+ (NSImage *)image
{
	static	NSImage	*iTunesImage = nil;
	
	if (!iTunesImage)
	{
		NSURL		*iTunesAppURL = nil;
		LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.iTunes"), NULL, NULL, (CFURLRef *)&iTunesAppURL);
		NSBundle	*iTunesBundle = [NSBundle bundleWithPath:[iTunesAppURL path]];
		
		iTunesImage = [[NSImage alloc] initWithContentsOfFile:[iTunesBundle pathForImageResource:@"iTunes"]];
		[iTunesImage setSize:NSMakeSize(32.0, 32.0)];
	}
	
	return iTunesImage;
}


+ (NSImage *)playlistImage
{
	static	NSImage	*playlistImage = nil;
	
	if (!playlistImage)
	{
		NSURL		*iTunesAppURL = nil;
		LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.iTunes"), NULL, NULL, (CFURLRef *)&iTunesAppURL);
		NSBundle	*iTunesBundle = [NSBundle bundleWithPath:[iTunesAppURL path]];
		
		playlistImage = [[NSImage alloc] initWithContentsOfFile:[iTunesBundle pathForImageResource:@"iTunes-playlist"]];
		[playlistImage setSize:NSMakeSize(32.0, 32.0)];
	}
	
	return playlistImage;
}


+ (Class)dataSourceClass
{
	return [MacOSaiXiTunesImageSource class];
}


+ (Class)editorClass
{
	return [MacOSaiXiTunesImageSourceController class];
}


+ (Class)preferencesEditorClass
{
	return nil;
}


@end

//
//  FlickrPreferencesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 1/28/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "FlickrPreferencesController.h"

#import "FlickrImageSourcePlugIn.h"
#import "FlickrImageSource.h"
#import <sys/mount.h>


@implementation MacOSaiXFlickrPreferencesController


- (id)initWithDelegate:(id<MacOSaiXEditorDelegate>)inDelegate;
{
	if (self = [super init])
		delegate = inDelegate;
	
	return self;
}


- (id<MacOSaiXEditorDelegate>)delegate
{
	return delegate;
}


- (NSView *)editorView
{
	if (!mainView)
		[[NSBundle bundleForClass:[self class]] loadNibFile:@"Preferences" 
										  externalNameTable:[NSDictionary dictionaryWithObject:self forKey:@"NSOwner"] 
												   withZone:[self zone]];
	
	return mainView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(392.0, 145.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return maxCacheSizeField;
}


- (void)willSelect
{
		// Make sure the nib is loaded.
	[self editorView];
	
	unsigned long long	maxCacheSize = [MacOSaiXFlickrImageSourcePlugIn maxCacheSize], 
						minFreeSpace = [MacOSaiXFlickrImageSourcePlugIn minFreeSpace];

	NSEnumerator		*magnitudeEnumerator = [[maxCacheSizePopUp itemArray] reverseObjectEnumerator];
	NSMenuItem			*item = nil;
	while (item = [magnitudeEnumerator nextObject])
	{
		float	magnitude = powf(2.0, [item tag]);
		
		if (maxCacheSize >= magnitude)
		{
			[maxCacheSizeField setIntValue:maxCacheSize / magnitude];
			[maxCacheSizePopUp selectItem:item];
			break;
		}
	}
	magnitudeEnumerator = [[minFreeSpacePopUp itemArray] reverseObjectEnumerator];
	item = nil;
	while (item = [magnitudeEnumerator nextObject])
	{
		float	magnitude = powf(2.0, [item tag]);
		
		if (minFreeSpace >= magnitude)
		{
			[minFreeSpaceField setIntValue:minFreeSpace / magnitude];
			[minFreeSpacePopUp selectItem:item];
			break;
		}
	}
	
		// Get the name and icon of the volume the cache lives on.
	struct statfs	fsStruct;
	statfs([[[MacOSaiXFlickrImageSource class] imageCachePath] fileSystemRepresentation], &fsStruct);
	NSString		*volumeRootPath = [NSString stringWithCString:fsStruct.f_mntonname];
	[volumeImageView setImage:[[NSWorkspace sharedWorkspace] iconForFile:volumeRootPath]];
	[volumeNameField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:volumeRootPath]];
}


- (void)didSelect
{
}


- (IBAction)setMaxCacheSizeMagnitude:(id)sender
{
	[MacOSaiXFlickrImageSourcePlugIn setMaxCacheSize:[maxCacheSizeField intValue] * powf(2.0, [[maxCacheSizePopUp selectedItem] tag])];
}


- (IBAction)setMinFreeSpaceMagnitude:(id)sender
{
	[MacOSaiXFlickrImageSourcePlugIn setMinFreeSpace:[minFreeSpaceField intValue] * powf(2.0, [[minFreeSpacePopUp selectedItem] tag])];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == maxCacheSizeField)
		[MacOSaiXFlickrImageSourcePlugIn setMaxCacheSize:[maxCacheSizeField intValue] * powf(2.0, [[maxCacheSizePopUp selectedItem] tag])];
	else if ([notification object] == minFreeSpaceField)
		[MacOSaiXFlickrImageSourcePlugIn setMinFreeSpace:[minFreeSpaceField intValue] * powf(2.0, [[minFreeSpacePopUp selectedItem] tag])];
}


- (IBAction)deleteCachedImages:(id)sender
{
	[MacOSaiXFlickrImageSourcePlugIn purgeCache];
}


- (void)willUnselect
{
}


- (void)didUnselect
{
}


@end

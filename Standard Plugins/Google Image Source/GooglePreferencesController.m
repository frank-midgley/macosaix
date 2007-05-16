//
//  GooglePreferencesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/29/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "GooglePreferencesController.h"
#import "GoogleImageSource.h"
#import "GoogleImageSourcePlugIn.h"
#import <sys/mount.h>


@implementation MacOSaiXGooglePreferencesEditor


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
	if (!editorView)
		[[NSBundle bundleForClass:[self class]] loadNibFile:@"Preferences" 
										  externalNameTable:[NSDictionary dictionaryWithObject:self forKey:@"NSOwner"] 
												   withZone:[self zone]];
	
	return editorView;
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
	
	unsigned long long	maxCacheSize = [MacOSaiXGoogleImageSourcePlugIn maxCacheSize], 
						minFreeSpace = [MacOSaiXGoogleImageSourcePlugIn minFreeSpace];

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
	statfs([[MacOSaiXGoogleImageSourcePlugIn imageCachePath] fileSystemRepresentation], &fsStruct);
	NSString		*volumeRootPath = [NSString stringWithCString:fsStruct.f_mntonname];
	[volumeImageView setImage:[[NSWorkspace sharedWorkspace] iconForFile:volumeRootPath]];
	[volumeNameField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:volumeRootPath]];
}


- (void)didSelect
{
}


- (IBAction)setMaxCacheSizeMagnitude:(id)sender
{
	[MacOSaiXGoogleImageSourcePlugIn setMaxCacheSize:[maxCacheSizeField intValue] * powf(2.0, [[maxCacheSizePopUp selectedItem] tag])];
}


- (IBAction)setMinFreeSpaceMagnitude:(id)sender
{
	[MacOSaiXGoogleImageSourcePlugIn setMinFreeSpace:[minFreeSpaceField intValue] * powf(2.0, [[minFreeSpacePopUp selectedItem] tag])];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == maxCacheSizeField)
		[MacOSaiXGoogleImageSourcePlugIn setMaxCacheSize:[maxCacheSizeField intValue] * powf(2.0, [[maxCacheSizePopUp selectedItem] tag])];
	else if ([notification object] == minFreeSpaceField)
		[MacOSaiXGoogleImageSourcePlugIn setMinFreeSpace:[minFreeSpaceField intValue] * powf(2.0, [[minFreeSpacePopUp selectedItem] tag])];
}


- (IBAction)deleteCachedImages:(id)sender
{
	[MacOSaiXGoogleImageSourcePlugIn purgeCache];
}


- (void)willUnselect
{
}


- (void)didUnselect
{
}


@end

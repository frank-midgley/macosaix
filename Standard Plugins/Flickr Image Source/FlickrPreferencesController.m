//
//  FlickrPreferencesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 1/28/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "FlickrPreferencesController.h"
#import "FlickrImageSource.h"
#import <sys/mount.h>


@implementation FlickrPreferencesController


- (NSView *)mainView
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


- (NSResponder *)firstResponder
{
	return maxCacheSizeField;
}


- (void)willSelect
{
		// Make sure the nib is loaded.
	[self mainView];
	
	unsigned long long	maxCacheSize = [FlickrImageSource maxCacheSize], 
						minFreeSpace = [FlickrImageSource minFreeSpace];

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
	statfs([[[FlickrImageSource class] imageCachePath] fileSystemRepresentation], &fsStruct);
	NSString		*volumeRootPath = [NSString stringWithCString:fsStruct.f_mntonname];
	[volumeImageView setImage:[[NSWorkspace sharedWorkspace] iconForFile:volumeRootPath]];
	[volumeNameField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:volumeRootPath]];
}


- (void)didSelect
{
}


- (IBAction)setMaxCacheSizeMagnitude:(id)sender
{
	[FlickrImageSource setMaxCacheSize:[maxCacheSizeField intValue] * powf(2.0, [[maxCacheSizePopUp selectedItem] tag])];
}


- (IBAction)setMinFreeSpaceMagnitude:(id)sender
{
	[FlickrImageSource setMinFreeSpace:[minFreeSpaceField intValue] * powf(2.0, [[minFreeSpacePopUp selectedItem] tag])];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == maxCacheSizeField)
		[FlickrImageSource setMaxCacheSize:[maxCacheSizeField intValue] * powf(2.0, [[maxCacheSizePopUp selectedItem] tag])];
	else if ([notification object] == minFreeSpaceField)
		[FlickrImageSource setMinFreeSpace:[minFreeSpaceField intValue] * powf(2.0, [[minFreeSpacePopUp selectedItem] tag])];
}


- (IBAction)deleteCachedImages:(id)sender
{
	[FlickrImageSource purgeCache];
}


- (void)willUnselect
{
}


- (void)didUnselect
{
}


@end

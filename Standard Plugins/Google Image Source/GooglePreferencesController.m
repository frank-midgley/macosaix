//
//  GooglePreferencesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/29/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GooglePreferencesController.h"
#import "GoogleImageSource.h"
#import <sys/mount.h>


@implementation GooglePreferencesController


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
	
	unsigned long long	maxCacheSize = [GoogleImageSource maxCacheSize], 
						minFreeSpace = [GoogleImageSource minFreeSpace];

	NSEnumerator		*magnitudeEnumerator = [[maxCacheSizePopUp itemArray] reverseObjectEnumerator];
	NSMenuItem			*item = nil;
	while (item = [magnitudeEnumerator nextObject])
	{
		float	magnitude = pow(2.0, [item tag]);
		
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
		float	magnitude = pow(2.0, [item tag]);
		
		if (minFreeSpace >= magnitude)
		{
			[minFreeSpaceField setIntValue:minFreeSpace / magnitude];
			[minFreeSpacePopUp selectItem:item];
			break;
		}
	}
	
		// Get the name and icon of the volume the cache lives on.
	struct statfs	fsStruct;
	statfs([[[GoogleImageSource class] imageCachePath] fileSystemRepresentation], &fsStruct);
	NSString		*volumeRootPath = [NSString stringWithCString:fsStruct.f_mntonname];
	[volumeImageView setImage:[[NSWorkspace sharedWorkspace] iconForFile:volumeRootPath]];
	[volumeNameField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:volumeRootPath]];
}


- (void)didSelect
{
}


- (IBAction)setMaxCacheSizeMagnitude:(id)sender
{
	[GoogleImageSource setMaxCacheSize:[maxCacheSizeField intValue] * pow(2.0, [[maxCacheSizePopUp selectedItem] tag])];
}


- (IBAction)setMinFreeSpaceMagnitude:(id)sender
{
	[GoogleImageSource setMinFreeSpace:[minFreeSpaceField intValue] * pow(2.0, [[minFreeSpacePopUp selectedItem] tag])];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == maxCacheSizeField)
		[GoogleImageSource setMaxCacheSize:[maxCacheSizeField intValue] * pow(2.0, [[maxCacheSizePopUp selectedItem] tag])];
	else if ([notification object] == minFreeSpaceField)
		[GoogleImageSource setMinFreeSpace:[minFreeSpaceField intValue] * pow(2.0, [[minFreeSpacePopUp selectedItem] tag])];
}


- (IBAction)deleteCachedImages:(id)sender
{
	[GoogleImageSource purgeCache];
}


- (void)willUnselect
{
}


- (void)didUnselect
{
}


@end

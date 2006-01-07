//
//  GooglePreferencesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/29/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GooglePreferencesController.h"
#import "GoogleImageSource.h"


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
	
		// Find the root of the volume the cache lives on.
	NSString	*path = [[GoogleImageSource class] imageCachePath];
	while (![[NSWorkspace sharedWorkspace] getFileSystemInfoForPath:path isRemovable:NULL isWritable:NULL isUnmountable:NULL description:NULL type:NULL])
		path = [path stringByDeletingLastPathComponent];
	
	[volumeImageView setImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];
	[volumeNameField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:path]];
}


- (void)didSelect
{
}


- (IBAction)setMaxCacheSizeMagnitude:(id)sender
{
}


- (IBAction)setMinFreeSpaceMagnitude:(id)sender
{
}


- (IBAction)deleteCachedImages:(id)sender
{
}


- (void)willUnselect
{
}


- (void)didUnselect
{
}


@end

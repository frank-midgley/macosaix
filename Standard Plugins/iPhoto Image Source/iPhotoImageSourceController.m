//
//  MacOSaiXiPhotoImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Mar 15 2005.
//  Copyright (c) 2005 Frank M. Midgley. All rights reserved.
//

#import "iPhotoImageSourceController.h"
#import "iPhotoImageSource.h"


@implementation MacOSaiXiPhotoImageSourceController


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"iPhoto Image Source" owner:self];
	
	return editorView;
}


- (NSSize)editorViewMinimumSize
{
	return NSMakeSize(269.0, 65.0);
}


- (NSResponder *)editorViewFirstResponder
{
	return albumsPopUp;
}


- (void)setOKButton:(NSButton *)button
{
	okButton = button;
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[iconView setImage:[imageSource image]];
	
		// Populate the pop-up menu with the names of all albums.
	[albumsPopUp removeAllItems];
	NSString		*albumsPath = [MacOSaiXiPhotoImageSource albumsPath];
	NSFileManager	*fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath:albumsPath])
	{
		[albumsPopUp addItemWithTitle:@"iPhoto not available"];
		[albumsPopUp setEnabled:NO];
		[okButton setEnabled:NO];
	}
	else
	{
			// Add an item that allows using all images.
		NSMenuItem	*item = [[[NSMenuItem alloc] init] autorelease];
		NSImage		*smallIPhoto = [[[imageSource image] copy] autorelease];
		[smallIPhoto setScalesWhenResized:YES];
		[smallIPhoto setSize:NSMakeSize(16.0, 16.0)];
		[item setTitle:@"All photos"];
		[item setImage:smallIPhoto];
		[[albumsPopUp menu] addItem:item];
		
			// Add an item for each album.
		NSDirectoryEnumerator	*albumNameEnumerator = [fileManager enumeratorAtPath:albumsPath];
		NSString				*albumName = nil;
		while (albumName = [albumNameEnumerator nextObject])
		{
			NSString	*fullPath = [albumsPath stringByAppendingPathComponent:albumName];
			
			if ([[[fileManager fileAttributesAtPath:fullPath traverseLink:NO] fileType] isEqualToString:NSFileTypeDirectory])
			{
				item = [[[NSMenuItem alloc] init] autorelease];
				[item setTitle:albumName];
				[item setImage:[MacOSaiXiPhotoImageSource albumImage]];
				[[albumsPopUp menu] addItem:item];
			}
		}
	}
	
	if (![(MacOSaiXiPhotoImageSource *)imageSource albumName])
		[albumsPopUp selectItemAtIndex:0];
	else
		[albumsPopUp selectItemWithTitle:[(MacOSaiXiPhotoImageSource *)imageSource albumName]];
	
	currentImageSource = (MacOSaiXiPhotoImageSource *)imageSource;
}


- (IBAction)chooseAlbum:(id)sender
{
		// Update the current image source instance.
	if ([albumsPopUp indexOfSelectedItem] == 0)
		[currentImageSource setAlbumName:nil];
	else
		[currentImageSource setAlbumName:[albumsPopUp titleOfSelectedItem]];
}


@end

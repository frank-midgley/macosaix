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


- (NSSize)minimumSize
{
	return NSMakeSize(460.0, 66.0);
}


- (NSResponder *)firstResponder
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
	
		// Populate the albums pop-up with the names of all albums.
	NSString				*getAlbumNamesText = @"tell application \"iPhoto\" to get name of albums";
	NSAppleScript			*getAlbumNamesScript = [[[NSAppleScript alloc] initWithSource:getAlbumNamesText] autorelease];
	NSDictionary			*getAlbumNamesError = nil;
	NSAppleEventDescriptor	*getAlbumNamesResult = [getAlbumNamesScript executeAndReturnError:&getAlbumNamesError];
	[albumsPopUp removeAllItems];
	if (!getAlbumNamesResult)
	{
		[albumsPopUp addItemWithTitle:@"No albums available"];
		[albumsPopUp setEnabled:NO];
		[[matrix cellAtRow:1 column:0] setEnabled:NO];
	}
	else
	{
			// Add an item for each album.
		int			albumCount = [getAlbumNamesResult numberOfItems],
					albumIndex = 1;
		for (albumIndex = 1; albumIndex <= albumCount; albumIndex++)
		{
			NSMenuItem	*item = [[[NSMenuItem alloc] init] autorelease];
			[item setTitle:[[getAlbumNamesResult descriptorAtIndex:albumIndex] stringValue]];
			[item setImage:[MacOSaiXiPhotoImageSource albumImage]];
			[[albumsPopUp menu] addItem:item];
		}
		[albumsPopUp setEnabled:YES];
		[[matrix cellAtRow:1 column:0] setEnabled:YES];
	}
	
		// Populate the keywords pop-up with the names of all keywords.
	NSString				*getKeywordNamesText = @"tell application \"iPhoto\" to get name of keywords";
	NSAppleScript			*getKeywordNamesScript = [[[NSAppleScript alloc] initWithSource:getKeywordNamesText] autorelease];
	NSDictionary			*getKeywordNamesError = nil;
	NSAppleEventDescriptor	*getKeywordNamesResult = [getKeywordNamesScript executeAndReturnError:&getKeywordNamesError];
	[keywordsPopUp removeAllItems];
	if (!getKeywordNamesResult)
	{
		[keywordsPopUp addItemWithTitle:@"No keywords available"];
		[keywordsPopUp setEnabled:NO];
		[[matrix cellAtRow:2 column:0] setEnabled:NO];
	}
	else
	{
			// Add an item for each keyword.
		int			keywordCount = [getKeywordNamesResult numberOfItems],
					keywordIndex = 1;
		for (keywordIndex = 1; keywordIndex <= keywordCount; keywordIndex++)
		{
			NSMenuItem	*item = [[[NSMenuItem alloc] init] autorelease];
			[item setTitle:[[getKeywordNamesResult descriptorAtIndex:keywordIndex] stringValue]];
			[item setImage:[MacOSaiXiPhotoImageSource keywordImage]];
			[[keywordsPopUp menu] addItem:item];
		}
		[keywordsPopUp setEnabled:YES];
		[[matrix cellAtRow:2 column:0] setEnabled:YES];
	}
	
	NSString	*albumName = [(MacOSaiXiPhotoImageSource *)imageSource albumName],
				*keywordName = [(MacOSaiXiPhotoImageSource *)imageSource keywordName];
	if (albumName && [albumsPopUp indexOfItemWithTitle:albumName] >= 0)
	{
		[albumsPopUp selectItemWithTitle:albumName];
		[matrix selectCellAtRow:1 column:0];
	}
	else if (keywordName && [keywordsPopUp indexOfItemWithTitle:keywordName] >= 0)
	{
		[keywordsPopUp selectItemWithTitle:keywordName];
		[matrix selectCellAtRow:2 column:0];
	}
	else
		[matrix selectCellAtRow:0 column:0];
	
	currentImageSource = (MacOSaiXiPhotoImageSource *)imageSource;
}


- (void)editingComplete
{
}


- (IBAction)setSourceType:(id)sender
{
	if ([matrix selectedRow] == 0)
		[self chooseAllPhotos:sender];
	else if ([matrix selectedRow] == 1)
		[self chooseAlbum:sender];
	else if ([matrix selectedRow] == 2)
		[self chooseKeyword:sender];
}


- (IBAction)chooseAllPhotos:(id)sender
{
	[currentImageSource setAlbumName:nil];
	[currentImageSource setKeywordName:nil];
	[matrix selectCellAtRow:0 column:0];
}


- (IBAction)chooseAlbum:(id)sender
{
		// Update the current image source instance.
	[currentImageSource setAlbumName:[albumsPopUp titleOfSelectedItem]];
	[matrix selectCellAtRow:1 column:0];
}


- (IBAction)chooseKeyword:(id)sender
{
		// Update the current image source instance.
	[currentImageSource setKeywordName:[keywordsPopUp titleOfSelectedItem]];
	[matrix selectCellAtRow:2 column:0];
}


@end

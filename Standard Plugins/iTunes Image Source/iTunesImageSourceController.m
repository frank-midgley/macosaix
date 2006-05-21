//
//  iTunesImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on May 18 2006.
//  Copyright (c) 2006 Frank M. Midgley. All rights reserved.
//

#import "iTunesImageSourceController.h"
#import "iTunesImageSource.h"


@implementation MacOSaiXiTunesImageSourceController


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"iTunes Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(460.0, 66.0);
}


- (NSResponder *)firstResponder
{
	return playlistsPopUp;
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[iconView setImage:[imageSource image]];
	
		// Populate the playlists pop-up with the names of all playlists.
	NSString				*getPlaylistNamesText = @"tell application \"iTunes\" to get name of user playlists where (special kind of it is not Party Shuffle and special kind of it is not Videos)";
	NSAppleScript			*getPlaylistNamesScript = [[[NSAppleScript alloc] initWithSource:getPlaylistNamesText] autorelease];
	NSDictionary			*getPlaylistNamesError = nil;
	NSAppleEventDescriptor	*getPlaylistNamesResult = [getPlaylistNamesScript executeAndReturnError:&getPlaylistNamesError];
	[playlistsPopUp removeAllItems];
	if (!getPlaylistNamesResult)
	{
		[playlistsPopUp addItemWithTitle:@"No playlists available"];
		[playlistsPopUp setEnabled:NO];
		[[matrix cellAtRow:1 column:0] setEnabled:NO];
	}
	else
	{
			// Add an item for each playlist.
		int			playlistCount = [getPlaylistNamesResult numberOfItems],
					playlistIndex = 1;
		for (playlistIndex = 1; playlistIndex <= playlistCount; playlistIndex++)
		{
			NSMenuItem	*item = [[[NSMenuItem alloc] init] autorelease];
			[item setTitle:[[getPlaylistNamesResult descriptorAtIndex:playlistIndex] stringValue]];
			[item setImage:[MacOSaiXiTunesImageSource playlistImage]];
			[[playlistsPopUp menu] addItem:item];
		}
		[playlistsPopUp setEnabled:YES];
		[[matrix cellAtRow:1 column:0] setEnabled:YES];
	}
	
	NSString	*playlistName = [(MacOSaiXiTunesImageSource *)imageSource playlistName];
	if (playlistName && [playlistsPopUp indexOfItemWithTitle:playlistName] >= 0)
	{
		[playlistsPopUp selectItemWithTitle:playlistName];
		[matrix selectCellAtRow:1 column:0];
	}
	else
		[matrix selectCellAtRow:0 column:0];
	
	currentImageSource = (MacOSaiXiTunesImageSource *)imageSource;
}


- (BOOL)settingsAreValid
{
	return YES;
}


- (void)editingComplete
{
}


- (IBAction)setSourceType:(id)sender
{
	if ([matrix selectedRow] == 0)
		[self chooseAllTracks:sender];
	else if ([matrix selectedRow] == 1)
		[self choosePlaylist:sender];
}


- (IBAction)chooseAllTracks:(id)sender
{
	[currentImageSource setPlaylistName:nil];
	[matrix selectCellAtRow:0 column:0];
}


- (IBAction)choosePlaylist:(id)sender
{
		// Update the current image source instance.
	[currentImageSource setPlaylistName:[playlistsPopUp titleOfSelectedItem]];
	[matrix selectCellAtRow:1 column:0];
}


@end

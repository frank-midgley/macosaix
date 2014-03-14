//
//  MacOSaiXiTunesImageSourceEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on Mar 15 2005.
//  Copyright (c) 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXiTunesImageSourceEditor.h"

#import "MacOSaiXiTunesImageSource.h"


@interface MacOSaiXiTunesImageSourceEditor (PrivateMethods)
- (void)loadPlaylists;
@end


@implementation MacOSaiXiTunesImageSourceEditor


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"iTunes Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(380.0, 90.0);
}


- (NSResponder *)firstResponder
{
	return sourceTypeMatrix;
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[iconView setImage:[imageSource image]];
	
	[self loadPlaylists];
	
	NSString	*playlistName = [(MacOSaiXiTunesImageSource *)imageSource playlistName];
	if (playlistName && [playlistPopUp indexOfItemWithTitle:playlistName] != NSNotFound)
	{
		[sourceTypeMatrix selectCellAtRow:1 column:0];
		[playlistPopUp selectItemWithTitle:playlistName];
	}
	else
	{
		[sourceTypeMatrix selectCellAtRow:0 column:0];
		[playlistPopUp selectItemAtIndex:0];
	}
	
	currentImageSource = (MacOSaiXiTunesImageSource *)imageSource;
}


- (BOOL)settingsAreValid
{
	return YES;
}


- (void)editingComplete
{
	currentImageSource = nil;
}


- (IBAction)setSourceType:(id)sender
{
	if ([sourceTypeMatrix selectedRow] == 0)
		[currentImageSource setPlaylistName:nil];
	else if ([sourceTypeMatrix selectedRow] == 1)
		[currentImageSource setPlaylistName:[playlistPopUp titleOfSelectedItem]];
}


- (IBAction)setPlaylist:(id)sender
{
		// Update the current image source instance.
	[currentImageSource setPlaylistName:[playlistPopUp titleOfSelectedItem]];
	[sourceTypeMatrix selectCellAtRow:1 column:0];
}


- (void)loadPlaylists
{
	if (!playlistNames)
		playlistNames = [[NSMutableArray array] retain];
	else
		[playlistNames removeAllObjects];
	
		// Get the names of all user playlists.
	NSString				*getPlaylistNamesText = @"tell application \"iTunes\" to get {name, special kind, smart} of (user playlists "\
													 "    where (special kind of it is not Movies and "\
													 "           special kind of it is not Party Shuffle and "\
													 "           special kind of it is not Podcasts and "\
													 "           special kind of it is not TV Shows and "\
													 "           special kind of it is not Videos))";
	NSAppleScript			*getPlaylistNamesScript = [[[NSAppleScript alloc] initWithSource:getPlaylistNamesText] autorelease];
	NSDictionary			*getPlaylistNamesError = nil;
	NSAppleEventDescriptor	*getPlaylistNamesResult = [getPlaylistNamesScript executeAndReturnError:&getPlaylistNamesError];
	if (!getPlaylistNamesResult)
	{
		[playlistPopUp setEnabled:NO];
		[[sourceTypeMatrix cellAtRow:1 column:0] setEnabled:NO];
	}
	else
	{
		[playlistPopUp removeAllItems];
		
		// Add an item for each playlist.
		NSAppleEventDescriptor	*nameDescriptors = [getPlaylistNamesResult descriptorAtIndex:1], 
								*kindDescriptors = [getPlaylistNamesResult descriptorAtIndex:2], 
								*smartDescriptors = [getPlaylistNamesResult descriptorAtIndex:3];
		int			playlistCount = [nameDescriptors numberOfItems],
					playlistIndex = 1;
		for (playlistIndex = 1; playlistIndex <= playlistCount; playlistIndex++)
		{
			NSString	*playlistName = [[nameDescriptors descriptorAtIndex:playlistIndex] stringValue], 
						*playlistKind = [[kindDescriptors descriptorAtIndex:playlistIndex] stringValue];
			BOOL		playlistIsSmart = [[smartDescriptors descriptorAtIndex:playlistIndex] booleanValue];
			
			[playlistNames addObject:playlistName];
			
			NSMenuItem	*item = [[[NSMenuItem alloc] init] autorelease];
			[item setTitle:playlistName];
			
			if ([playlistKind isEqualToString:@"kSpZ"])
				[item setImage:[MacOSaiXiTunesImageSource musicImage]];
			else if ([playlistKind isEqualToString:@"kSpA"])
				[item setImage:[MacOSaiXiTunesImageSource audiobooksImage]];
			else if ([playlistKind isEqualToString:@"kSpM"])
				[item setImage:[MacOSaiXiTunesImageSource purchasedImage]];
			else if (playlistIsSmart)
				[item setImage:[MacOSaiXiTunesImageSource smartPlaylistImage]];
			else
				[item setImage:[MacOSaiXiTunesImageSource playlistImage]];
			[[playlistPopUp menu] addItem:item];
		}
		[playlistPopUp setEnabled:YES];
		[playlistPopUp selectItemWithTitle:[currentImageSource playlistName]];
		[[sourceTypeMatrix cellAtRow:1 column:0] setEnabled:YES];
	}
}


- (void)dealloc
{
	[editorView release];
	
	[super dealloc];
}


@end

//
//  iTunesImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on May 18 2006.
//  Copyright (c) 2006 Frank M. Midgley. All rights reserved.
//

#import "iTunesImageSourceController.h"

#import "iTunesImageSource.h"
#import "iTunesImageSourcePlugIn.h"


@implementation MacOSaiXiTunesImageSourceController


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
		[NSBundle loadNibNamed:@"iTunes Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(186.0, 120.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return playlistTable;
}


- (void)editDataSource:(id<MacOSaiXDataSource>)dataSource
{
	MacOSaiXiTunesImageSource	*imageSource = (MacOSaiXiTunesImageSource *)dataSource;
	
	if (!playlistNames)
		playlistNames = [[NSMutableArray array] retain];
	else
		[playlistNames removeAllObjects];
	
		// Get the names of all user playlists.
	NSString				*getPlaylistNamesText = @"tell application \"iTunes\" to get name of user playlists "\
													 "    where (special kind of it is not Party Shuffle and "\
													 "           special kind of it is not Videos)";
	NSAppleScript			*getPlaylistNamesScript = [[[NSAppleScript alloc] initWithSource:getPlaylistNamesText] autorelease];
	NSDictionary			*getPlaylistNamesError = nil;
	NSAppleEventDescriptor	*getPlaylistNamesResult = [getPlaylistNamesScript executeAndReturnError:&getPlaylistNamesError];
	if (getPlaylistNamesResult)
	{
			// Add an item for each playlist.
		int			playlistCount = [getPlaylistNamesResult numberOfItems],
					playlistIndex = 1;
		for (playlistIndex = 1; playlistIndex <= playlistCount; playlistIndex++)
			[playlistNames addObject:[[getPlaylistNamesResult descriptorAtIndex:playlistIndex] stringValue]];
	}
	
	[playlistTable reloadData];
	
	NSString	*playlistName = [(MacOSaiXiTunesImageSource *)imageSource playlistName];
	int			playlistIndex = [playlistNames indexOfObject:playlistName];
	if (playlistIndex == NSNotFound)
		[playlistTable selectRow:0 byExtendingSelection:NO];
	else
		[playlistTable selectRow:playlistIndex + 1 byExtendingSelection:NO];
	
	currentImageSource = imageSource;
}


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [playlistNames count] + 1;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id	object = nil;
	
	if ([[tableColumn identifier] isEqualToString:@"Icon"])
	{
		if (row == 0)
			object = [MacOSaiXiTunesImageSourcePlugIn image];
		else
			object = [MacOSaiXiTunesImageSourcePlugIn playlistImage];
	}
	else
	{
		if (row == 0)
			object = NSLocalizedString(@"Entire Library", @"");
		else
			object = [playlistNames objectAtIndex:row - 1];
	}
	
	return object;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	int	selectedRow = [playlistTable selectedRow];
	
	if (selectedRow == 0)
		[currentImageSource setPlaylistName:nil];
	else
		[currentImageSource setPlaylistName:[playlistNames objectAtIndex:selectedRow - 1]];
	
	[[self delegate] dataSource:currentImageSource settingsDidChange:NSLocalizedString(@"Change Playlist", @"")];
}


- (BOOL)mouseDownInMosaic:(NSEvent *)event
{
	return NO;
}


- (BOOL)mouseDraggedInMosaic:(NSEvent *)event
{
	return NO;
}


- (BOOL)mouseUpInMosaic:(NSEvent *)event
{
	return NO;
}


- (void)editingDidComplete
{
	delegate = nil;
}


@end

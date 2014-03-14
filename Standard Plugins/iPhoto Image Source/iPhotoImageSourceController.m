//
//  MacOSaiXiPhotoImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Mar 15 2005.
//  Copyright (c) 2005 Frank M. Midgley. All rights reserved.
//

#import "iPhotoImageSourceController.h"
#import "iPhotoImageSource.h"
#import "iPhotoDatabase.h"


@implementation MacOSaiXiPhotoImageSourceController


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"iPhoto Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(460.0, 94.0);
}


- (NSResponder *)firstResponder
{
	return albumsPopUp;
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[iconView setImage:[imageSource image]];

	// TODO: can't bindings handle all of this?

	// Populate the albums pop-up with the names of all albums.
	NSArray	*albumNames = [[MacOSaiXiPhotoDatabase sharedDatabase] albumNames];
	[albumsPopUp removeAllItems];
	if ([albumNames count] == 0)
	{
		[albumsPopUp addItemWithTitle:@"No albums available"];
		[albumsPopUp setEnabled:NO];
		[[matrix cellAtRow:1 column:0] setEnabled:NO];
	}
	else
	{
		// Add an item for each album.
		for (NSString *albumName in albumNames)
		{
			NSMenuItem	*item = [[[NSMenuItem alloc] init] autorelease];
			[item setTitle:albumName];
			[item setImage:[[MacOSaiXiPhotoDatabase sharedDatabase] albumImage]];
			[[albumsPopUp menu] addItem:item];
		}
		[albumsPopUp setEnabled:YES];
		[[matrix cellAtRow:1 column:0] setEnabled:YES];
	}
	
	// Populate the keywords pop-up with the names of all keywords.
	NSArray	*keywordNames = [[MacOSaiXiPhotoDatabase sharedDatabase] keywordNames];
	[keywordsPopUp removeAllItems];
    if ([keywordNames count] == 0)
	{
		[keywordsPopUp addItemWithTitle:@"No keywords available"];
		[keywordsPopUp setEnabled:NO];
		[[matrix cellAtRow:2 column:0] setEnabled:NO];
	}
    else
    {
        // Add a menu item for each keyword.
        for (NSString *keywordName in keywordNames)
        {
            NSMenuItem	*item = [[[NSMenuItem alloc] init] autorelease];
			[item setTitle:keywordName];
            [item setImage:[[MacOSaiXiPhotoDatabase sharedDatabase] keywordImage]];
            [[keywordsPopUp menu] addItem:item];
        }
        [keywordsPopUp setEnabled:YES];
        [[matrix cellAtRow:2 column:0] setEnabled:YES];
    }
	
	// Populate the events pop-up with the names of all events.
	NSArray	*eventNames = [[MacOSaiXiPhotoDatabase sharedDatabase] eventNames];
	[eventsPopUp removeAllItems];
    if ([eventNames count] == 0)
	{
		[eventsPopUp addItemWithTitle:@"No events available"];
		[eventsPopUp setEnabled:NO];
		[[matrix cellAtRow:3 column:0] setEnabled:NO];
	}
    else
    {
        // Add a menu item for each event.
        for (NSString *eventName in eventNames)
        {
            NSMenuItem	*item = [[[NSMenuItem alloc] init] autorelease];
			[item setTitle:eventName];
            [item setImage:[[MacOSaiXiPhotoDatabase sharedDatabase] eventImage]];
            [[eventsPopUp menu] addItem:item];
        }
        [eventsPopUp setEnabled:YES];
        [[matrix cellAtRow:3 column:0] setEnabled:YES];
    }
	
	// Default the UI to existing values if available.
	NSString	*albumName = [(MacOSaiXiPhotoImageSource *)imageSource albumName],
				*keywordName = [(MacOSaiXiPhotoImageSource *)imageSource keywordName],
				*eventName = [(MacOSaiXiPhotoImageSource *)imageSource eventName];
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
	else if (eventName && [eventsPopUp indexOfItemWithTitle:eventName] >= 0)
	{
		[eventsPopUp selectItemWithTitle:eventName];
		[matrix selectCellAtRow:3 column:0];
	}
	else
		[matrix selectCellAtRow:0 column:0];
	
	currentImageSource = (MacOSaiXiPhotoImageSource *)imageSource;
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
	if ([matrix selectedRow] == 0)
		[self chooseAllPhotos:sender];
	else if ([matrix selectedRow] == 1)
		[self chooseAlbum:sender];
	else if ([matrix selectedRow] == 2)
		[self chooseKeyword:sender];
	else if ([matrix selectedRow] == 3)
		[self chooseEvent:sender];
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


- (IBAction)chooseEvent:(id)sender
{
	// Update the current image source instance.
	[currentImageSource setEventName:[eventsPopUp titleOfSelectedItem]];
	[matrix selectCellAtRow:3 column:0];
}


- (void)dealloc
{
	[editorView release];
	
	[super dealloc];
}


@end

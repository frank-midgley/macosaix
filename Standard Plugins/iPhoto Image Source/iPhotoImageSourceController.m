//
//  MacOSaiXiPhotoImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Mar 15 2005.
//  Copyright (c) 2005 Frank M. Midgley. All rights reserved.
//

#import "iPhotoImageSourceController.h"

#import "iPhotoImageSource.h"
#import "iPhotoImageSourcePlugIn.h"


@implementation MacOSaiXiPhotoImageSourceEditor


- (id)initWithDelegate:(id<MacOSaiXEditorDelegate>)inDelegate;
{
	if (self = [super init])
	{
		delegate = inDelegate;
		
		albumNames = [[NSMutableArray array] retain];
		keywordNames = [[NSMutableArray array] retain];
	}
	
	return self;
}


- (id<MacOSaiXEditorDelegate>)delegate
{
	return delegate;
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"iPhoto Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(242.0, 130.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return sourceTypePopUp;
}


- (void)getAlbumNames
{
	NSString				*getAlbumNamesText = @"tell application \"iPhoto\" to get name of albums";
	NSAppleScript			*getAlbumNamesScript = [[[NSAppleScript alloc] initWithSource:getAlbumNamesText] autorelease];
	NSDictionary			*getAlbumNamesError = nil;
	NSAppleEventDescriptor	*getAlbumNamesResult = [getAlbumNamesScript executeAndReturnError:&getAlbumNamesError];
	
	[albumNames removeAllObjects];
	
	if (getAlbumNamesResult)
	{
		int			albumCount = [getAlbumNamesResult numberOfItems],
					albumIndex = 1;
		
		for (albumIndex = 1; albumIndex <= albumCount; albumIndex++)
			[albumNames addObject:[[getAlbumNamesResult descriptorAtIndex:albumIndex] stringValue]];
		
		[albumNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
	}
}


- (void)getKeywordNames
{
	NSString				*getKeywordNamesText = @"tell application \"iPhoto\" to get name of keywords";
	NSAppleScript			*getKeywordNamesScript = [[[NSAppleScript alloc] initWithSource:getKeywordNamesText] autorelease];
	NSDictionary			*getKeywordNamesError = nil;
	NSAppleEventDescriptor	*getKeywordNamesResult = [getKeywordNamesScript executeAndReturnError:&getKeywordNamesError];
	
	[keywordNames removeAllObjects];
	
	if (getKeywordNamesResult)
	{
		int			keywordCount = [getKeywordNamesResult numberOfItems],
					keywordIndex = 1;
		
		for (keywordIndex = 1; keywordIndex <= keywordCount; keywordIndex++)
			[keywordNames addObject:[[getKeywordNamesResult descriptorAtIndex:keywordIndex] stringValue]];
		
		[keywordNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
	}
}


- (void)editDataSource:(id<MacOSaiXDataSource>)imageSource
{
	currentImageSource = (MacOSaiXiPhotoImageSource *)imageSource;
	
	[self refresh];
}


- (IBAction)setSourceType:(id)sender
{
	if ([sourceTypePopUp selectedTag] == 0 && ([currentImageSource albumName] || [currentImageSource keywordName]))
	{
		NSString	*previousValue = ([currentImageSource albumName] ? [currentImageSource albumName] : [currentImageSource keywordName]), 
					*key = ([currentImageSource albumName] ? @"albumName" : @"keywordName");
		
		[[previousValue retain] autorelease];
		
		[currentImageSource setAlbumName:nil];
		[currentImageSource setKeywordName:nil];
		
		[[self delegate] dataSource:currentImageSource 
					   didChangeKey:key 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Use All Photos", @"")];
	}
	else if ([sourceTypePopUp selectedTag] == 1 && ![currentImageSource albumName])
	{
		NSString	*previousValue = ([currentImageSource keywordName] ? [currentImageSource keywordName] : [currentImageSource albumName]), 
					*key = ([currentImageSource keywordName] ? @"keywordName" : @"albumName");
		
		[[previousValue retain] autorelease];
		
		[self getAlbumNames];
		
			// TODO: remember the last used album?
		if ([albumNames count] > 0)
			[currentImageSource setAlbumName:[albumNames objectAtIndex:0]];
		
		[[self delegate] dataSource:currentImageSource 
					   didChangeKey:key 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Use iPhoto Album", @"")];
	}
	else if ([sourceTypePopUp selectedTag] == 2 && ![currentImageSource keywordName])
	{
		NSString	*previousValue = ([currentImageSource albumName] ? [currentImageSource albumName] : [currentImageSource keywordName]), 
					*key = ([currentImageSource albumName] ? @"albumName" : @"keywordName");
		
		[[previousValue retain] autorelease];
		
		[self getKeywordNames];
		
			// TODO: remember the last used keyword?
		if ([keywordNames count] > 0)
			[currentImageSource setKeywordName:[keywordNames objectAtIndex:0]];
		
		[[self delegate] dataSource:currentImageSource 
					   didChangeKey:key 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Use iPhoto Keyword", @"")];
	}
	
	[self refresh];
}


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	if ([sourceTypePopUp selectedTag] == 0)
		return 0;
	else if ([sourceTypePopUp selectedTag] == 1)
		return [albumNames count];
	else
		return [keywordNames count];
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id	object = nil;
	
	if ([[tableColumn identifier] isEqualToString:@"Icon"])
	{
		if ([sourceTypePopUp selectedTag] == 1)
			object = [MacOSaiXiPhotoImageSourcePlugIn albumImage];
		else
			object = [MacOSaiXiPhotoImageSourcePlugIn keywordImage];
	}
	else
	{
		if ([sourceTypePopUp selectedTag] == 1)
			object = [albumNames objectAtIndex:row];
		else
			object = [keywordNames objectAtIndex:row];
	}
	
	return object;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([sourceTypePopUp selectedTag] == 1)
	{
		NSString	*previousValue = [[[currentImageSource albumName] retain] autorelease];
		int			selectedRow = [tableView selectedRow];
	
		[currentImageSource setAlbumName:[albumNames objectAtIndex:selectedRow]];
	
		[[self delegate] dataSource:currentImageSource 
					   didChangeKey:@"albumName" 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Change iPhoto Album", @"")];
	}
	else
	{
		NSString	*previousValue = [[[currentImageSource keywordName] retain] autorelease];
		int			selectedRow = [tableView selectedRow];
	
		[currentImageSource setKeywordName:[keywordNames objectAtIndex:selectedRow]];
	
		[[self delegate] dataSource:currentImageSource 
					   didChangeKey:@"keywordName" 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Change iPhoto Keyword", @"")];
	}
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


- (void)refresh
{
	NSString	*albumName = [currentImageSource albumName],
				*keywordName = [currentImageSource keywordName];
	
	if (albumName)
	{
		int	row = [albumNames indexOfObject:albumName];
		
		[sourceTypePopUp selectItemAtIndex:1];
		[tableView reloadData];
		[tableView selectRow:row byExtendingSelection:NO];
		if ([[tableView enclosingScrollView] respondsToSelector:@selector(setHidden:)])
			[[tableView enclosingScrollView] setHidden:NO];
	}
	else if (keywordName)
	{
		int	row = [keywordNames indexOfObject:keywordName];
		
		[sourceTypePopUp selectItemAtIndex:2];
		[tableView reloadData];
		[tableView selectRow:row byExtendingSelection:NO];
		if ([[tableView enclosingScrollView] respondsToSelector:@selector(setHidden:)])
			[[tableView enclosingScrollView] setHidden:NO];
	}
	else
	{
		[sourceTypePopUp selectItemAtIndex:0];
		if ([[tableView enclosingScrollView] respondsToSelector:@selector(setHidden:)])
			[[tableView enclosingScrollView] setHidden:YES];
		else
			[tableView reloadData];
	}
}


- (void)editingDidComplete
{
}


- (void)dealloc
{
	[albumNames release];
	[keywordNames release];
	
	[super dealloc];
}


@end

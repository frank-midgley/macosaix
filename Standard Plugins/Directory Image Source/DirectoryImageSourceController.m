//
//  DirectoryImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "DirectoryImageSourceController.h"
#import "DirectoryImageSource.h"
#import "NSFileManager+MacOSaiX.h"


@implementation NSDictionary (MacOSaiXDirectoryImageSourceController)

- (NSComparisonResult)compareFolderPaths:(NSDictionary *)otherDict
{
	return [[self objectForKey:@"Path"] caseInsensitiveCompare:[otherDict objectForKey:@"Path"]];
}

@end


@implementation DirectoryImageSourceController


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"Directory Image Source" owner:self];
	
	return editorView;
}


- (NSSize)editorViewMinimumSize
{
	return NSMakeSize(367.0, 217.0);
}


- (NSResponder *)editorViewFirstResponder
{
	return folderTableView;
}


- (void)setOKButton:(NSButton *)button
{
	okButton = button;
}


- (int)rowOfCurrentFolder
{
	int					row = 0;
	NSEnumerator		*folderEnumerator = [folderList objectEnumerator];
	NSMutableDictionary	*folderDict = nil;
	NSString			*currentPath = [currentImageSource path];
	while (folderDict = [folderEnumerator nextObject])
	{
		if ([[folderDict objectForKey:@"Path"] isEqualToString:currentPath])
			break;
		
		row++;
	}
	
	return (folderDict ? row : -1);
}

- (void)updateGUI
{
	NSArray			*knownFolders = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] 
																				objectForKey:@"Folders"];
	
	[folderList release];
	if (knownFolders)
		folderList = (NSMutableArray *)CFPropertyListCreateDeepCopy(kCFAllocatorDefault, 
																	knownFolders, 
																	kCFPropertyListMutableContainers);
	else
	{
		NSString	*defaultFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"];
		
		folderList = [[NSMutableArray arrayWithObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
														defaultFolder, @"Path", 
														@"--", @"Image Count", 
														nil]] retain];
	}
	
	NSEnumerator		*folderEnumerator = [[NSArray arrayWithArray:folderList] objectEnumerator];
	NSMutableDictionary	*folderDict = nil;
	NSString			*currentPath = [currentImageSource path];
	while (folderDict = [folderEnumerator nextObject])
	{
		NSString	*folderPath = [folderDict objectForKey:@"Path"];
		
		BOOL		isFolder;
		if (![[NSFileManager defaultManager] fileExistsAtPath:folderPath isDirectory:&isFolder] || !isFolder)
			[folderList removeObject:folderDict];
		else
			[folderDict setObject:[[NSFileManager defaultManager] attributedPath:folderPath] forKey:@"Attributed Path"];
	}
	
	if (currentPath && [self rowOfCurrentFolder] == -1)
	{
		[folderList addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
									currentPath, @"Path", 
									[[NSFileManager defaultManager] attributedPath:currentPath], @"Attributed Path", 
									@"--", @"Image Count", 
									nil]];
	}
	
	[folderList sortUsingSelector:@selector(compareFolderPaths:)];
	
	[folderTableView selectRow:[self rowOfCurrentFolder] byExtendingSelection:NO];
	[folderTableView reloadData];
	
	[followsAliasesButton setState:([currentImageSource followsAliases] ? NSOnState : NSOffState)];
}


- (void)setCurrentImageSource:(DirectoryImageSource *)imageSource
{
	[currentImageSource autorelease];
	currentImageSource = [imageSource retain];
	
	BOOL	isDirectory;
	if (![[NSFileManager defaultManager] fileExistsAtPath:[currentImageSource path] isDirectory:&isDirectory] || !isDirectory)
		[currentImageSource setPath:NSHomeDirectory()];
	
	[self updateGUI];
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	if (![(DirectoryImageSource *)imageSource path])
	{
			// Default to the last directory chosen by the user.
		NSString	*lastChosenDirectory = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] 
																					objectForKey:@"Last Chosen Directory"];
		
			// Default to the user's home directory if the value from the defaults is not valid.
		BOOL	isDirectory;
		if (![lastChosenDirectory isKindOfClass:[NSString class]] || 
			![[NSFileManager defaultManager] fileExistsAtPath:lastChosenDirectory isDirectory:&isDirectory] || 
			!isDirectory)
			lastChosenDirectory = NSHomeDirectory();
		
		[(DirectoryImageSource *)imageSource setPath:lastChosenDirectory];
	}
	
	[self setCurrentImageSource:(DirectoryImageSource *)imageSource];
}


- (IBAction)chooseFolder:(id)sender
{
	NSWindow		*window = [editorView window];
	// TODO: use parent if in drawer, but not if in sheet
	
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    [oPanel setCanChooseFiles:NO];
    [oPanel setCanChooseDirectories:YES];
    [oPanel beginSheetForDirectory:[currentImageSource path]
							  file:nil
							 types:nil
					modalForWindow:window
					 modalDelegate:self
					didEndSelector:@selector(chooseFolderDidEnd:returnCode:contextInfo:)
					   contextInfo:nil];
}


- (void)chooseFolderDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
	{
		NSString		*newPath = [[sheet filenames] objectAtIndex:0];
		
			// Remember this path for the next time the user creates a new source.
		NSMutableDictionary	*plugInDefaults = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] 
														mutableCopy] autorelease];
		if (!plugInDefaults)
			plugInDefaults = [NSMutableDictionary dictionary];
		[plugInDefaults setObject:newPath forKey:@"Last Chosen Directory"];
		[[NSUserDefaults standardUserDefaults] setObject:plugInDefaults forKey:@"Folder Image Source"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
			// Update the current image source instance.
		[currentImageSource setPath:newPath];
		
			// Display the new path in the GUI.
		[self updateGUI];
	}
}


- (IBAction)clearFolderList:(id)sender
{
	NSMutableDictionary	*plugInDefaults = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] 
													mutableCopy] autorelease];
	if (plugInDefaults)
	{
		[plugInDefaults setObject:[NSArray array] forKey:@"Folders"];
		[[NSUserDefaults standardUserDefaults] setObject:plugInDefaults forKey:@"Folder Image Source"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	[currentImageSource setPath:nil];
	
	[self updateGUI];
}


- (IBAction)setFollowsAliases:(id)sender
{
	[currentImageSource setFollowsAliases:([followsAliasesButton state] == NSOnState)];
}


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [folderList count];
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	return [[folderList objectAtIndex:row] objectForKey:[tableColumn identifier]];
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[okButton setEnabled:([folderTableView selectedRow] != -1)];
}


- (void)dealloc
{
	[currentImageSource release];
	
	[super dealloc];
}


@end

//
//  DirectoryImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "DirectoryImageSourceController.h"

#import "DirectoryImageSource.h"
#import "DirectoryImageSourceDirectory.h"
#import "NSFileManager+MacOSaiX.h"


@interface MacOSaiXDirectoryImageSourceEditor (PrivateMethods)
- (void)populateGUI;
@end


@implementation MacOSaiXDirectoryImageSourceEditor


+ (void)initialize
{
	if (![[[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] objectForKey:@"Folders"])
	{
			// Use the images in the user's "Pictures" folder by default.
		NSMutableDictionary	*plugInDefaults = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] 
														mutableCopy] autorelease];
		NSString			*defaultPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"];
		NSArray				*folderDicts = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
																		defaultPath, @"Path", 
																		@"", @"Image Count", 
																		nil]];

		if (plugInDefaults && [plugInDefaults isKindOfClass:[NSDictionary class]])
			[plugInDefaults setObject:folderDicts forKey:@"Folders"];
		else
			plugInDefaults = [NSDictionary dictionaryWithObject:folderDicts forKey:@"Folders"];
		
		[[NSUserDefaults standardUserDefaults] setObject:plugInDefaults forKey:@"Folder Image Source"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}


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
		[NSBundle loadNibNamed:@"Directory Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(236.0, 107.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return folderPopUp;
}


- (DirectoryImageSourceDirectory *)currentDirectory
{
	NSString						*currentPath = [currentImageSource path];
	NSEnumerator					*folderEnumerator = [[folderPopUp itemArray] objectEnumerator];
	NSMenuItem						*menuItem = nil;
	DirectoryImageSourceDirectory	*directory = nil;
	
	while (!directory && (menuItem = [folderEnumerator nextObject]))
	{
		if ([[[menuItem representedObject] path] isEqualToString:currentPath])
			directory = [menuItem representedObject];
	}
	
	return directory;
}


- (void)populatePopUpFromDefaults
{
	NSMutableDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] ;
	NSArray				*knownFolders = [plugInDefaults objectForKey:@"Folders"];
	NSMutableArray		*directories = [NSMutableArray array];
	NSFileManager		*fileManager = [NSFileManager defaultManager];
	
		// Only use the directories that still exist.
	NSEnumerator		*folderEnumerator = [knownFolders objectEnumerator];
	NSMutableDictionary	*folderDict = nil;
	while (folderDict = [folderEnumerator nextObject])
	{
		NSString	*folderPath = [folderDict objectForKey:@"Path"];
		BOOL		isFolder;
		
		if ([fileManager fileExistsAtPath:folderPath isDirectory:&isFolder] && isFolder)
		{
			int imageCount = [[folderDict objectForKey:@"Image Count"] intValue];
			
			[directories addObject:[DirectoryImageSourceDirectory directoryWithPath:folderPath imageCount:imageCount]];
		}
	}
	
		// Add the folder of the current source if it's not already in the list.
		// TBD: should it also be added to the prefs?
	NSString			*currentPath = [currentImageSource path];
	if (currentPath && ![self currentDirectory])
		[directories addObject:[DirectoryImageSourceDirectory directoryWithPath:currentPath imageCount:0]];
	
		// Sort the folders by their display name.
	[directories sortUsingSelector:@selector(compare:)];
	
		// Remove any previous folders in the pop-up.
	while ([[folderPopUp itemAtIndex:0] representedObject])
		[folderPopUp removeItemAtIndex:0];
	
		// Add an item to the pop-up menu for each folder.
	NSEnumerator					*directoryEnumerator = [directories reverseObjectEnumerator];
	DirectoryImageSourceDirectory	*directory = nil;
	while (directory = [directoryEnumerator nextObject])
	{
		[folderPopUp insertItemWithTitle:[directory displayName] atIndex:0];
		NSMenuItem	*menuItem = [folderPopUp itemAtIndex:0];
		[menuItem setTarget:self];
		[menuItem setAction:@selector(chooseFolder:)];
		[menuItem setRepresentedObject:directory];
		[menuItem setImage:[directory icon]];
	}		
	
	[self populateGUI];	// populate the other views
	
	[followsAliasesButton setState:([currentImageSource followsAliases] ? NSOnState : NSOffState)];
}


- (void)populateGUI
{
	DirectoryImageSourceDirectory	*directory = [self currentDirectory];
	
	if (directory)
	{
		[folderPopUp selectItemAtIndex:[folderPopUp indexOfItemWithRepresentedObject:directory]];
		[locationImageView setImage:[directory locationIcon]];
		[locationTextField setStringValue:[directory locationDisplayName]];
		if ([directory imageCount] == 0)
			[imageCountTextField setStringValue:@"unknown"];
		else
			[imageCountTextField setIntValue:[directory imageCount]];
	}
	else
		[self populatePopUpFromDefaults];	// add this folder to the pop-up
}


- (void)editDataSource:(id<MacOSaiXDataSource>)dataSource
{
	MacOSaiXDirectoryImageSource	*imageSource = (MacOSaiXDirectoryImageSource *)dataSource;
	
	if (![imageSource path])
	{
			// Default to the last directory chosen by the user.
		NSString	*lastChosenDirectory = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] 
																					objectForKey:@"Last Chosen Folder"];
		
			// Default to the user's home directory if the value from the defaults is not valid.
		BOOL	isDirectory;
		if (![lastChosenDirectory isKindOfClass:[NSString class]] || 
			![[NSFileManager defaultManager] fileExistsAtPath:lastChosenDirectory isDirectory:&isDirectory] || 
			!isDirectory)
			lastChosenDirectory = NSHomeDirectory();
		
		[imageSource setPath:lastChosenDirectory];
	}
	
	[currentImageSource autorelease];
	currentImageSource = [imageSource retain];
	
	BOOL	isDirectory;
	if (![[NSFileManager defaultManager] fileExistsAtPath:[currentImageSource path] isDirectory:&isDirectory] || !isDirectory)
		[currentImageSource setPath:NSHomeDirectory()];
	
	[self populateGUI];
}


- (void)editingDidComplete
{
	delegate = nil;
}


- (IBAction)chooseFolder:(id)sender
{
	DirectoryImageSourceDirectory	*directory = [sender representedObject];
	
	if (directory)
	{
		[currentImageSource setPath:[directory path]];
		[self populateGUI];
		[[self delegate] dataSource:currentImageSource settingsDidChange:NSLocalizedString(@"Change Folder", @"")];
	}
	else
	{
		// The user wants to choose a new folder.
		
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
}


- (void)chooseFolderDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
	{
		NSString		*newPath = [[sheet filenames] objectAtIndex:0];
		
			// Update the model.
		[currentImageSource setPath:newPath];
		
			// Remember this path for the next time the user creates a new source.
		NSMutableDictionary	*plugInDefaults = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] 
														mutableCopy] autorelease];

		if (!plugInDefaults)
			plugInDefaults = [NSMutableDictionary dictionary];
		
		[plugInDefaults setObject:newPath forKey:@"Last Chosen Folder"];
			
			// Add the chosen path if it wasn't there.
		if (![self currentDirectory])
		{
			NSMutableArray		*folderDicts = [[[plugInDefaults objectForKey:@"Folders"] mutableCopy] autorelease];
			
			if (!folderDicts)
			{
				folderDicts = [NSMutableArray array];
				[plugInDefaults setObject:folderDicts forKey:@"Folders"];
			}
			
			[folderDicts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										newPath, @"Path", 
										[NSNumber numberWithInt:0], @"Image Count", 
										nil]];
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:plugInDefaults forKey:@"Folder Image Source"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
		[self populateGUI];
		
		[[self delegate] dataSource:currentImageSource settingsDidChange:NSLocalizedString(@"Change Folder", @"")];
	}
}


- (IBAction)clearFolderList:(id)sender
{
	NSMutableDictionary	*plugInDefaults = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Folder Image Source"] 
													mutableCopy] autorelease];
	NSString			*picturesPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"];
	
	if (plugInDefaults)
	{
		[plugInDefaults setObject:[NSArray arrayWithObject:picturesPath] forKey:@"Folders"];
		[[NSUserDefaults standardUserDefaults] setObject:plugInDefaults forKey:@"Folder Image Source"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	[currentImageSource setPath:picturesPath];
	
	[self populateGUI];
}


- (IBAction)setFollowsAliases:(id)sender
{
	[currentImageSource setFollowsAliases:([followsAliasesButton state] == NSOnState)];
	
	[[self delegate] dataSource:currentImageSource settingsDidChange:NSLocalizedString(@"Set Follows Aliases", @"")];
}


- (void)dealloc
{
	[currentImageSource release];
	
	[super dealloc];
}


@end

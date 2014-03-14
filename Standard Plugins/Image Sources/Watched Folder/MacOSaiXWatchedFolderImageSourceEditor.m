//
//  MacOSaiXWatchedFolderImageSourceEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXWatchedFolderImageSourceEditor.h"

#import "MacOSaiXWatchedFolderImageSource.h"


@implementation MacOSaiXWatchedFolderImageSourceEditor


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"Watched Folder Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(300.0, 96.0);
}


- (NSResponder *)firstResponder
{
	return chooseFolderButton;
}


- (void)updateGUI
{
	// TODO: update the message view
}


- (void)setCurrentImageSource:(MacOSaiXWatchedFolderImageSource *)imageSource
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
	if (![(MacOSaiXWatchedFolderImageSource *)imageSource path])
	{
			// Default to the last directory chosen by the user.
		NSString	*lastChosenDirectory = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Watched Folder Image Source"] 
																					objectForKey:@"Last Chosen Folder"];
		
			// Default to the user's home directory if the value from the defaults is not valid.
		BOOL	isDirectory;
		if (![lastChosenDirectory isKindOfClass:[NSString class]] || 
			![[NSFileManager defaultManager] fileExistsAtPath:lastChosenDirectory isDirectory:&isDirectory] || 
			!isDirectory)
			lastChosenDirectory = NSHomeDirectory();
		
		[(MacOSaiXWatchedFolderImageSource *)imageSource setPath:lastChosenDirectory];
	}
	
	[self setCurrentImageSource:(MacOSaiXWatchedFolderImageSource *)imageSource];
}


- (BOOL)settingsAreValid
{
	return ([currentImageSource path] != nil);
}


- (void)editingComplete
{
	[self setCurrentImageSource:nil];
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
		NSMutableDictionary	*plugInDefaults = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Watched Folder Image Source"] 
														mutableCopy] autorelease];

		if (!plugInDefaults)
			plugInDefaults = [NSMutableDictionary dictionary];
		
		[plugInDefaults setObject:newPath forKey:@"Last Chosen Folder"];
		[[NSUserDefaults standardUserDefaults] setObject:plugInDefaults forKey:@"Watched Folder Image Source"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
			// Update the current image source instance.
		[currentImageSource setPath:newPath];
	}
}


- (void)dealloc
{
	[currentImageSource release];
	
	[editorView release];
	
	[super dealloc];
}


@end

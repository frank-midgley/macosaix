//
//  DirectoryImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "DirectoryImageSourceController.h"
#import "DirectoryImageSource.h"


@implementation DirectoryImageSourceController


- (BOOL)allowMultipleImageSources
{
	return YES;
}


- (NSView *)imageSourceView
{
	if (!imageSourceView)
		[NSBundle loadNibNamed:@"Directory Image Source" owner:self];
	return imageSourceView;
}


- (void)setOKButton:(NSButton *)button
{
	// No need to remember this, we are always in a valid state.
}


- (void)updateGUI
{
		// Clear any previous entries out of the GUI
	[pathComponent1ImageView setImage:nil];
	[pathComponent2ImageView setImage:nil];
	[pathComponent3ImageView setImage:nil];
	[pathComponent4ImageView setImage:nil];
	[pathComponent5ImageView setImage:nil];
	[pathComponent1TextField setStringValue:@""];
	[pathComponent2TextField setStringValue:@""];
	[pathComponent3TextField setStringValue:@""];
	[pathComponent4TextField setStringValue:@""];
	[pathComponent5TextField setStringValue:@""];
	
		// Root the display at the user's home folder if that's what we're in.
	NSString		*sourcePath = [[currentImageSource path] stringByAbbreviatingWithTildeInPath];
	NSMutableArray	*pathComponents = [[[sourcePath pathComponents] mutableCopy] autorelease];
	NSString		*currentPath = [NSString string];
	
		// Root the display at a volume's root if the directory is not on the boot volume.
	if ([pathComponents count] > 1 && [[pathComponents objectAtIndex:1] isEqualTo:@"Volumes"])
	{
		[pathComponents removeObjectAtIndex:0];
		[pathComponents removeObjectAtIndex:0];
		currentPath = @"/Volumes";
	}
	
		// Loop through each path component and fill it into the GUI if appropriate.
	int				componentCount = [pathComponents count],
					index;
	for (index = 0; index < componentCount; index++)
	{
		NSString	*component = [pathComponents objectAtIndex:index];
		currentPath = [currentPath stringByAppendingPathComponent:component];
		NSImage		*pathIcon = [[NSWorkspace sharedWorkspace] iconForFile:[currentPath stringByExpandingTildeInPath]];
		
		component = [[NSFileManager defaultManager] displayNameAtPath:[currentPath stringByExpandingTildeInPath]];
//		if ([component isEqualTo:@"~"])
//			component = [NSHomeDirectory() lastPathComponent];
		
		if (index == 0)
		{
			[pathComponent1ImageView setImage:pathIcon];
			[pathComponent1TextField setStringValue:component];
		}
		else if (index == 1)
		{
			[pathComponent2ImageView setImage:pathIcon];
			[pathComponent2TextField setStringValue:component];
		}
		else if (index == 2)
		{
			if (componentCount > 5)
				[pathComponent3TextField setStringValue:@"..."];
			else
			{
				[pathComponent3ImageView setImage:pathIcon];
				[pathComponent3TextField setStringValue:component];
			}
		}
		else
		{
			if ((index == componentCount - 1 && componentCount == 4) || 
				(index == componentCount - 2 && componentCount > 4))
			{
				[pathComponent4ImageView setImage:pathIcon];
				[pathComponent4TextField setStringValue:component];
			}
			else if (index == componentCount - 1 && componentCount > 4)
			{
				[pathComponent5ImageView setImage:pathIcon];
				[pathComponent5TextField setStringValue:component];
			}
		}
	}
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
		NSString	*lastChosenDirectory = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Directory Image Source"] 
																					objectForKey:@"Last Chosen Directory"];
		
			// Default to the user's home directory if the value from the defaults is not valid.
		BOOL	isDirectory;
		if (![lastChosenDirectory isKindOfClass:[NSString class]] || 
			![[NSFileManager defaultManager] fileExistsAtPath:[currentImageSource path] isDirectory:&isDirectory] || 
			!isDirectory)
			lastChosenDirectory = NSHomeDirectory();
		
		[(DirectoryImageSource *)imageSource setPath:lastChosenDirectory];
	}
	
	[self setCurrentImageSource:(DirectoryImageSource *)imageSource];
}


- (IBAction)chooseDirectory:(id)sender
{
	NSWindow		*window = [imageSourceView window];
	// TODO: use parent if in drawer, but not if in sheet
	
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    [oPanel setCanChooseFiles:NO];
    [oPanel setCanChooseDirectories:YES];
    [oPanel beginSheetForDirectory:[currentImageSource path]
							  file:nil
							 types:nil
					modalForWindow:window
					 modalDelegate:self
					didEndSelector:@selector(chooseDirectoryDidEnd:returnCode:contextInfo:)
					   contextInfo:nil];
}


- (void)chooseDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
	{
		NSString		*newPath = [[sheet filenames] objectAtIndex:0];
		
			// Remember this path for the next time the user creates a new source.
		NSMutableDictionary	*plugInDefaults = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Directory Image Source"] 
														mutableCopy] autorelease];
		[plugInDefaults setObject:newPath forKey:@"Last Chosen Directory"];
		[[NSUserDefaults standardUserDefaults] setObject:plugInDefaults forKey:@"Directory Image Source"];
		
			// Update the current image source instance.
		[currentImageSource setPath:newPath];
		
			// Display the new path in the GUI.
		[self updateGUI];
	}
}


- (void)dealloc
{
	[currentImageSource release];
	
	[super dealloc];
}


@end

//
//  MacOSaiXKioskSetupController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/8/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXKioskSetupController.h"


@implementation MacOSaiXKioskSetupController


- (NSString *)windowNibName
{
	return @"Kiosk Setup";
}


- (void)updateWarningField
{
		// Check the original images.
	BOOL	atLeastOneImage = NO;
	int		column = 0;
	for (column = 0; column < [originalImageMatrix numberOfColumns]; column++)
		if ([[originalImageMatrix cellAtRow:0 column:column] imagePosition] == NSImageOnly)
			atLeastOneImage = YES;
	if (!atLeastOneImage)
	{
		[warningField setStringValue:@"Please choose at least one original image."];
		[startButton setEnabled:NO];
	}
	else
	{
		NSString	*password = [passwordField stringValue];
		
		if ([requirePasswordButton state] == NSOnState && [password length] == 0)
		{
			[warningField setStringValue:@"Please enter a password."];
			[startButton setEnabled:NO];
		}
		else
		{
			NSString	*repeatedPassword = [repeatedPasswordField stringValue];
			
			if ([requirePasswordButton state] == NSOnState && [repeatedPassword length] == 0)
			{
				[warningField setStringValue:@"Please enter the repeated password."];
				[startButton setEnabled:NO];
			}
			else
			{
				if ([requirePasswordButton state] == NSOnState && ![password isEqualToString:repeatedPassword])
				{
					[warningField setStringValue:@"The passwords do not match."];
					[startButton setEnabled:NO];
				}
				else
				{
					// TODO: make sure at least one screen is set to show the kiosk window
					
					[warningField setStringValue:@""];
					[startButton setEnabled:YES];
				}
			}
		}
	}
}


- (void)awakeFromNib
{
		// Populate the original image buttons
	NSArray	*originalImagePaths = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Original Image Paths"];
	int		column = 0;
	for (column = 0; column < [originalImageMatrix numberOfColumns]; column++)
	{
		NSButtonCell	*buttonCell = [originalImageMatrix cellAtRow:0 column:column];
		NSString		*imagePath = (column < [originalImagePaths count] ? [originalImagePaths objectAtIndex:column] : nil);
		NSImage			*image = nil;
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath] &&
			(image = [[NSImage alloc] initWithContentsOfFile:imagePath]))
		{
			[image setScalesWhenResized:YES];
			[image setSize:[originalImageMatrix cellSize]];
			[buttonCell setTitle:imagePath];
			[buttonCell setImage:image];
			[buttonCell setImagePosition:NSImageOnly];
			[image release];
		}
		else
		{
			[buttonCell setTitle:@"No Image"];
			[buttonCell setImage:nil];
			[buttonCell setImagePosition:NSNoImage];
		}
	}
	
	[self updateWarningField];
}


- (IBAction)chooseOriginalImage:(id)sender
{
		// Get the path of the button's current image.
	NSButtonCell	*buttonCell = [originalImageMatrix selectedCell];
	NSString		*imagePath = ([buttonCell imagePosition] == NSImageOnly ? [buttonCell title] : nil);
	
		// Drop an open panel.
	NSOpenPanel		*openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel beginSheetForDirectory:[imagePath stringByDeletingLastPathComponent] 
								 file:[imagePath lastPathComponent]
								types:[NSImage imageFileTypes] 
					   modalForWindow:[self window] 
					    modalDelegate:self 
					   didEndSelector:@selector(chooseOriginalImagePanelDidEnd:returnCode:contextInfo:) 
						  contextInfo:(void *)[originalImageMatrix selectedColumn]];
}


- (void)chooseOriginalImagePanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		int				column = (int)contextInfo;
		NSButtonCell	*buttonCell = [originalImageMatrix cellAtRow:0 column:column];
		NSString		*imagePath = [[openPanel filenames] lastObject];
		NSImage			*image = [[NSImage alloc] initWithContentsOfFile:imagePath];
		
		if ([image isValid])
		{
				// Update the GUI.
			[image setScalesWhenResized:YES];
			[image setSize:[originalImageMatrix cellSize]];
			[buttonCell setTitle:imagePath];
			[buttonCell setImage:image];
			[buttonCell setImagePosition:NSImageOnly];
			[image release];
			
				// Update the user defaults.
			NSMutableArray	*originalImagePaths = [[[[NSUserDefaults standardUserDefaults] arrayForKey:@"Original Image Paths"] mutableCopy] autorelease];
			if (!originalImagePaths)
				originalImagePaths = [NSMutableArray array];
			while ([originalImagePaths count] < [originalImageMatrix numberOfColumns])
				[originalImagePaths addObject:@""];
			[originalImagePaths replaceObjectAtIndex:column withObject:imagePath];
			[[NSUserDefaults standardUserDefaults] setObject:originalImagePaths forKey:@"Original Image Paths"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
		else
		{
			[buttonCell setTitle:@"Not An Image"];
			[buttonCell setImage:nil];
			[buttonCell setImagePosition:NSNoImage];
		}
		
		[self updateWarningField];
	}
}


- (IBAction)setWindowType:(id)sender
{
	;	// TODO
	
	[self updateWarningField];
}


- (IBAction)setPasswordRequired:(id)sender
{
	BOOL	passwordRequired = ([requirePasswordButton state] == NSOnState);
	
	[passwordField setEditable:passwordRequired];
	[repeatedPasswordField setEditable:passwordRequired];
	
	if (!passwordRequired)
	{
		[passwordField setStringValue:@""];
		[repeatedPasswordField setStringValue:@""];
	}
	
	// TODO: set app level global
	
	[self updateWarningField];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	[self updateWarningField];
}


- (IBAction)quit:(id)sender
{
	[NSApp stopModalWithCode:NSCancelButton];
}


- (IBAction)start:(id)sender
{
	[NSApp stopModal];
}


@end

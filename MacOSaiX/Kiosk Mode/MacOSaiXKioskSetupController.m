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
	NSString	*warningString = @"";
	
	if (!NSClassFromString(@"MacOSaiXRectangularTileShapes"))
		warningString = @"The Rectangular Tile Shapes plug-in is missing.";
	if (!NSClassFromString(@"GoogleImageSource"))
		warningString = @"The Google Image Source plug-in is missing.";
	else
	{
			// Make sure there is at least one original image chosen.
		BOOL	atLeastOneImage = NO;
		int		column = 0;
		for (column = 0; column < [originalImageMatrix numberOfColumns]; column++)
			if ([[originalImageMatrix cellAtRow:0 column:column] imagePosition] == NSImageOnly)
				atLeastOneImage = YES;
		if (!atLeastOneImage)
			warningString = @"Please choose at least one original image.";
		else
		{
			NSString	*password = [passwordField stringValue];
			
			if ([requirePasswordButton state] == NSOnState && [password length] == 0)
				warningString = @"Please enter a password.";
			else
			{
				NSString	*repeatedPassword = [repeatedPasswordField stringValue];
				
				if ([requirePasswordButton state] == NSOnState && [repeatedPassword length] == 0)
					warningString = @"Please enter the repeated password.";
				else if ([requirePasswordButton state] == NSOnState && ![password isEqualToString:repeatedPassword])
					warningString = @"The passwords do not match.";
				else
				{
					// TODO: make sure at least one screen is set to show the kiosk window
				}
			}
		}
	}
	
	[warningField setStringValue:warningString];
	[startButton setEnabled:([warningString length] == 0)];
}


- (void)awakeFromNib
{
	NSDictionary	*kioskSettings = [[NSUserDefaults standardUserDefaults] objectForKey:@"Kiosk Settings"];
	
		// Populate the original image buttons
	NSArray			*originalImagePaths = [kioskSettings objectForKey:@"Original Image Paths"];
	if (!originalImagePaths)
	{
		originalImagePaths = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Original Image Paths"];
		if (originalImagePaths)
		{
				// Move the original paths to the new key path.
			NSMutableDictionary	*newSettings = [NSMutableDictionary dictionary];
			if (kioskSettings)
				[newSettings addEntriesFromDictionary:kioskSettings];
			[newSettings setObject:originalImagePaths forKey:@"Original Image Paths"];
			[[NSUserDefaults standardUserDefaults] setObject:newSettings forKey:@"Kiosk Settings"];
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Original Image Paths"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}
	int				column = 0;
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
	
	NSAttributedString	*message = nil;
	NSData				*archivedMessage = [kioskSettings objectForKey:@"Archived Message"];
	if (archivedMessage)
		message = [NSUnarchiver unarchiveObjectWithData:archivedMessage];
	if (!message)
	{
		NSFont					*font = [[NSFontManager sharedFontManager] fontWithFamily:@"Helvetica" 
																				   traits:NSItalicFontMask | NSBoldFontMask 
																				   weight:9 
																					 size:24.0];
		NSMutableParagraphStyle	*style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		[style setAlignment:NSCenterTextAlignment];
		NSDictionary			*attributes = [NSDictionary dictionaryWithObjectsAndKeys:
													font, NSFontAttributeName, 
													[[NSColor greenColor] shadowWithLevel:0.5], NSForegroundColorAttributeName, 
													style, NSParagraphStyleAttributeName, 
													nil];
		message = [[[NSAttributedString alloc] initWithString:@"Sample\nMessage" attributes:attributes] autorelease];
	}
	[messageView setMessage:message];
	
	NSColor				*messageBackgroundColor = nil;
	NSData				*archivedColor = [kioskSettings objectForKey:@"Archived Message Background Color"];
	if (archivedColor)
		messageBackgroundColor = [NSUnarchiver unarchiveObjectWithData:archivedColor];
	if (!messageBackgroundColor)
		messageBackgroundColor = [[NSColor yellowColor] highlightWithLevel:0.75];
	[messageView setBackgroundColor:messageBackgroundColor];
	[messageBackgroundColorWell setColor:messageBackgroundColor];
	
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
			NSMutableDictionary	*kioskSettings = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Kiosk Settings"] mutableCopy] autorelease];
			if (!kioskSettings)
				kioskSettings = [NSMutableDictionary dictionary];
			NSMutableArray		*originalImagePaths = [[[kioskSettings objectForKey:@"Original Image Paths"] mutableCopy] autorelease];
			if (!originalImagePaths)
				originalImagePaths = [[[[NSUserDefaults standardUserDefaults] arrayForKey:@"Original Image Paths"] mutableCopy] autorelease];
			if (!originalImagePaths)
				originalImagePaths = [NSMutableArray array];
			while ([originalImagePaths count] < [originalImageMatrix numberOfColumns])
				[originalImagePaths addObject:@""];
			[originalImagePaths replaceObjectAtIndex:column withObject:imagePath];
			[kioskSettings setObject:originalImagePaths forKey:@"Original Image Paths"];
			[[NSUserDefaults standardUserDefaults] setObject:kioskSettings forKey:@"Kiosk Settings"];
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


- (NSAttributedString *)message
{
	return [messageView message];
}


- (IBAction)setMessageBackgroundColor:(id)sender
{
	if ([sender isKindOfClass:[NSColor class]])
		[messageView setBackgroundColor:sender];
	else if ([sender isKindOfClass:[NSColorWell class]])
		[messageView setBackgroundColor:[(NSColorWell *)sender color]];
}


- (NSColor *)messageBackgroundColor
{
	return [messageView backgroundColor];
}


- (IBAction)quit:(id)sender
{
	[NSApp stopModalWithCode:NSCancelButton];
}


- (IBAction)start:(id)sender
{
		// Remember the message for next time.
	NSMutableDictionary	*kioskSettings = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Kiosk Settings"] mutableCopy] autorelease];
	
	if (!kioskSettings)
		kioskSettings = [NSMutableDictionary dictionary];
	
	[kioskSettings setObject:[NSArchiver archivedDataWithRootObject:[messageView message]]
					  forKey:@"Archived Message"];
	[kioskSettings setObject:[NSArchiver archivedDataWithRootObject:[messageView backgroundColor]]
					  forKey:@"Archived Message Background Color"];
	
	[[NSUserDefaults standardUserDefaults] setObject:kioskSettings forKey:@"Kiosk Settings"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[NSApp stopModal];
}


@end

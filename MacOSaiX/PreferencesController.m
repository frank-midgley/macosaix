//
//  PreferencesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 Frank M. Midgley. All rights reserved.
//

#import "PreferencesController.h"

#import "MacOSaiX.h"
#import "MacOSaiXDisallowedImage.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXEditor.h"
#import "MacOSaiXPlugIn.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXWarningController.h"


@implementation MacOSaiXPreferencesController


+ (MacOSaiXPreferencesController *)sharedController
{
    static MacOSaiXPreferencesController	*controller = nil;
	
	if (!controller)
		controller = [[self alloc] initWithWindow:nil];
    
	return controller;
}


- (NSString *)windowNibName
{
	return @"Preferences";
}


- (void)awakeFromNib
{
		// Retain the main prefs view so we can swap it out for plug-in's views.
	mainPreferencesView = [[preferenceBox contentView] retain];
	
	mainViewMinSize = [[preferenceBox contentView] frame].size;
	minSizeBase = [[self window] minSize];
	minSizeBase.width -= mainViewMinSize.width;
	minSizeBase.height -= mainViewMinSize.height;
	
	NSImageCell		*imageCell = [[[NSImageCell alloc] initImageCell:nil] autorelease];
	[[preferenceTable tableColumnWithIdentifier:@"Icon"] setDataCell:imageCell];
	
	[[[preferenceTable tableColumnWithIdentifier:@"Name"] dataCell] setWraps:YES];
	
		// Populate the main prefs view from the user defaults.
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	[updateCheckBox setState:([defaults boolForKey:@"Perform Update Check at Launch"] ? NSOnState : NSOffState)];
	[reportCrashesCheckBox setState:([defaults boolForKey:@"Check For Crash at Launch"] ? NSOnState : NSOffState)];
	[autoStartCheckBox setState:([defaults boolForKey:@"Automatically Start Mosaics"] ? NSOnState : NSOffState)];
	[autoSaveCheckBox setState:([defaults boolForKey:@"Automatically Save Mosaics"] ? NSOnState : NSOffState)];
    int				frequency = [defaults integerForKey:@"Autosave Frequency"];
	if (frequency < 1)
		frequency = 1;
    [autoSaveFrequencyField setIntValue:frequency];
	[showTooltipsCheckBox setState:([defaults boolForKey:@"Show Tile Tooltips"] ? NSOnState : NSOffState)];
	
		// Get the list of plug-ins that have prefs.
	plugInClasses = [[NSMutableArray array] retain];
	plugInControllers = [[NSMutableDictionary dictionary] retain];
	MacOSaiX		*appDelegate = [NSApp delegate];
	NSArray			*allPlugInClasses = [appDelegate allPlugIns];
	NSEnumerator	*plugInEnumerator = [allPlugInClasses objectEnumerator];
	Class			plugInClass = nil;
	while (plugInClass = [plugInEnumerator nextObject])
		if ([[plugInClass preferencesEditorClass] conformsToProtocol:@protocol(MacOSaiXPlugInPreferencesEditor)])
			[plugInClasses addObject:plugInClass];
	// TODO: sort by plug-in name
	
	disallowedImagesViewMinSize = NSMakeSize(352.0, 192.0);
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disallowedImagesDidChange:) name:MacOSaiXDisallowedImagesDidChangeNotification object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsDidChange:) name:NSUserDefaultsDidChangeNotification object:nil];
}


#pragma mark -
#pragma mark General preferences


- (void)showGeneralPreferences:(id)sender
{
	if (mainPreferencesView)
	{
		[currentController willUnselect];
		
		[preferenceBox setContentView:mainPreferencesView];
		
		[[self window] setMinSize:NSMakeSize(minSizeBase.width + mainViewMinSize.width, 
											 minSizeBase.height + mainViewMinSize.height)];
		
		[currentController didUnselect];
		
		currentController = nil;
		
		[preferenceTable selectRow:0 byExtendingSelection:NO];
		
		[self showWindow:self];
	}
	// else we're waking up from the nib and the main pref view is already set
}


- (IBAction)setUpdateCheck:(id)sender
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setBool:([updateCheckBox state] == NSOnState) forKey:@"Perform Update Check at Launch"];
    [defaults synchronize];
}


- (IBAction)setReportCrashes:(id)sender;
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setBool:([reportCrashesCheckBox state] == NSOnState) forKey:@"Check For Crash at Launch"];
    [defaults synchronize];
}


- (IBAction)setAutoStart:(id)sender
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setBool:([autoStartCheckBox state] == NSOnState) forKey:@"Automatically Start Mosaics"];
    [defaults synchronize];
}


- (IBAction)setAutoSave:(id)sender
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setBool:([autoSaveCheckBox state] == NSOnState) forKey:@"Automatically Save Mosaics"];
    [defaults synchronize];
}


- (IBAction)setShowTileTooltips:(id)sender
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setBool:([showTooltipsCheckBox state] == NSOnState) forKey:@"Show Tile Tooltips"];
    [defaults synchronize];
}


- (IBAction)resetWarnings:(id)sender
{
	[MacOSaiXWarningController enableAllWarnings];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == autoSaveFrequencyField)
	{
		NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
		
		[defaults setInteger:[autoSaveFrequencyField intValue] forKey:@"Autosave Frequency"];
		[defaults synchronize];
	}
}


#pragma mark -
#pragma mark Visible Editors


- (void)showVisibleEditors:(id)sender
{
	[currentController willUnselect];
	
	[preferenceBox setContentView:editorsPreferencesView];
	
	[[self window] setMinSize:NSMakeSize(minSizeBase.width + editorsViewMinSize.width, 
										 minSizeBase.height + editorsViewMinSize.height)];
	
	[currentController didUnselect];
	
	currentController = nil;
	
	[preferenceTable selectRow:1 byExtendingSelection:NO];
	
	[self showWindow:self];
}


- (IBAction)setEditorVisible:(id)sender
{
	int		row = [editorsTable selectedRow];
	
	if (row == -1)
		NSBeep();
	else
	{
		NSString		*editorClassName = NSStringFromClass([[MacOSaiXMosaicEditor editorClasses] objectAtIndex:row]);
		NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
		NSMutableArray	*visibleEditors = [[[defaults objectForKey:@"Default Additional Editors"] mutableCopy] autorelease];
		
		if (!visibleEditors)
			visibleEditors = [NSMutableArray arrayWithObject:editorClassName];
		else if ([visibleEditors containsObject:editorClassName])
			[visibleEditors removeObject:editorClassName];
		else
			[visibleEditors addObject:editorClassName];
		
		[defaults setObject:visibleEditors forKey:@"Default Additional Editors"];
		[defaults synchronize];
		
		[editorsTable reloadData];
	}
}


- (IBAction)showEditorDescription:(id)sender
{
	int		row = [editorsTable selectedRow];
	
	if (row == -1)
		NSBeep();
	else
	{
		Class			editorClass = [[MacOSaiXMosaicEditor editorClasses] objectAtIndex:row];
		
		[editorClass showDescriptionNearPoint:[NSEvent mouseLocation]];
	}
}


- (void)defaultsDidChange:(NSNotification *)notification
{
	[editorsTable reloadData];
}


#pragma mark -
#pragma mark Disallowed images


- (void)showDisallowedImages:(id)sender
{
	[currentController willUnselect];
	
	[preferenceBox setContentView:disallowedImagesView];
	
	[[self window] setMinSize:NSMakeSize(minSizeBase.width + disallowedImagesViewMinSize.width, 
										 minSizeBase.height + disallowedImagesViewMinSize.height)];
	
	[currentController didUnselect];
	
	currentController = nil;
	
	[preferenceTable selectRow:2 byExtendingSelection:NO];
	
	[self showWindow:self];
}


- (void)disallowedImagesDidChange:(NSNotification *)notification
{
	[disallowedImagesTable reloadData];
}


- (IBAction)showImages:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:([showDisallowedImagesButton state] == NSOnState)
											forKey:@"Show Disallowed Images"];
	[disallowedImagesTable reloadData];
}


- (IBAction)allowSelectedImages:(id)sender
{
	MacOSaiX		*appDelegate = (MacOSaiX *)[NSApp delegate];
	NSArray			*disallowedImages = [NSArray arrayWithArray:[appDelegate disallowedImages]];
	NSEnumerator	*selectedRowEnumerator = [disallowedImagesTable selectedRowEnumerator];
	NSNumber		*selectedRow = nil;
	
	while (selectedRow = [selectedRowEnumerator nextObject])
		[appDelegate allowImage:[disallowedImages objectAtIndex:[selectedRow intValue]]];
}


#pragma mark -
#pragma mark Table view delegation


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (tableView == preferenceTable)
		return [plugInClasses count] + 3;
	else if (tableView == editorsTable)
		return [[MacOSaiXMosaicEditor editorClasses] count];
	else if (tableView == disallowedImagesTable)
		return [[(MacOSaiX *)[NSApp delegate] disallowedImages] count];
	else
		return 0;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id	object = nil;
	
	if (tableView == preferenceTable)
	{
		if ([[tableColumn identifier] isEqualToString:@"Icon"])
		{
			if (row == 0)
				object = [NSApp applicationIconImage];
			else if (row == 1)
				object = nil;
			else if (row == 2)
				object = [NSImage imageNamed:@"Don't Use"];
			else
				object = [[plugInClasses objectAtIndex:row - 3] image];
		}
		else
		{
			if (row == 0)
				object = NSLocalizedString(@"General", @"");
			else if (row == 1)
				object = NSLocalizedString(@"Additional Settings", @"");
			else if (row == 2)
				object = NSLocalizedString(@"\"Don't Use\" Images", @"");
			else
			{
				Class		plugInClass = [plugInClasses objectAtIndex:row - 3];
				NSBundle	*plugInBundle = [NSBundle bundleForClass:plugInClass];
				
				object = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
				
				if ([plugInClass conformsToProtocol:@protocol(MacOSaiXTileShapes)])
					object = [NSString stringWithFormat:NSLocalizedString(@"%@ Tile Shapes", @""), object];
			}
		}
	}
	else if (tableView == editorsTable)
	{
		Class	editorClass = [[MacOSaiXMosaicEditor editorClasses] objectAtIndex:row];
		
		if ([[tableColumn identifier] isEqualToString:@"Visible"])
		{
			NSArray	*visibleEditors = [[NSUserDefaults standardUserDefaults] objectForKey:@"Default Additional Editors"];
			
			object = [NSNumber numberWithBool:(![editorClass isAdditional] || [visibleEditors containsObject:NSStringFromClass(editorClass)])];
		}
		else if ([[tableColumn identifier] isEqualToString:@"Image"])
			return [editorClass image];	
		else if ([[tableColumn identifier] isEqualToString:@"Title"])
			return [editorClass title];	
	}
	else if (tableView == disallowedImagesTable)
	{
		MacOSaiX				*appDelegate = (MacOSaiX *)[NSApp delegate];
		MacOSaiXSourceImage		*disallowedImage = [[appDelegate disallowedImages] objectAtIndex:row];
		id<MacOSaiXImageSource>	imageSource = [[disallowedImage imageSourceClass] imageSourceForUniversalIdentifier:[disallowedImage universalIdentifier]];
		NSString				*imageIdentifier = [imageSource identifierForUniversalIdentifier:[disallowedImage universalIdentifier]];
		
		if ([[tableColumn identifier] isEqualToString:@"Source Icon"])
			object = [[appDelegate plugInForDataSourceClass:[imageSource class]] image];
		else if ([[tableColumn identifier] isEqualToString:@"Image"] && [showDisallowedImagesButton state] == NSOnState)
		{
			NSImageRep	*imageRep = [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:NSMakeSize(64.0, 32.0) 
																						forIdentifier:imageIdentifier 
																						   fromSource:imageSource];
			NSImage		*image = [[[NSImage alloc] initWithSize:[imageRep size]] autorelease];
			[image addRepresentation:imageRep];
			
			object = image;
		}
		else if ([[tableColumn identifier] isEqualToString:@"Image Description"])
			object = [imageSource descriptionForIdentifier:imageIdentifier];
	}
	
	return object;
}


- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if (tableView == editorsTable && [[tableColumn identifier] isEqualToString:@"Visible"])
	{
		Class	editorClass = [[MacOSaiXMosaicEditor editorClasses] objectAtIndex:row];
		
		[cell setEnabled:[editorClass isAdditional]];
	}
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == preferenceTable)
	{
		// TODO: call -willUnselect and -didUnselect on the current controller
		
		int									selectedRow = [preferenceTable selectedRow];
		id<MacOSaiXPlugInPreferencesEditor>	newPrefsEditor = nil;
		
		[currentController willUnselect];
		if (selectedRow == 0)
			[self showGeneralPreferences:self];
		else if (selectedRow == 1)
			[self showVisibleEditors:self];
		else if (selectedRow == 2)
			[self showDisallowedImages:self];
		else
		{
			Class	plugInClass = [plugInClasses objectAtIndex:selectedRow - 3];
			
				// Lookup or create the preferences editor for this plug-in.
			newPrefsEditor = [plugInControllers objectForKey:plugInClass];
			if (!newPrefsEditor)
			{
					// Create and cache an editor.
				newPrefsEditor = [[[[plugInClass preferencesEditorClass] alloc] init] autorelease];
				[plugInControllers setObject:newPrefsEditor forKey:plugInClass];
			}
			
				// Enlarge the window if needed.
			NSSize	currentViewSize = [[preferenceBox contentView] frame].size, 
					minViewSize = [newPrefsEditor minimumSize];
			minViewSize.width = MAX(mainViewMinSize.width, minViewSize.width);
			minViewSize.height = MAX(mainViewMinSize.height, minViewSize.height);
			float	widthDiff = MAX(0.0, minViewSize.width - currentViewSize.width), 
					heightDiff = MAX(0.0, minViewSize.height - currentViewSize.height);
			if (widthDiff > 0 || heightDiff > 0)
			{
				NSRect	currentFrame = [[self window] frame], 
						newFrame = NSMakeRect(NSMinX(currentFrame), 
											  NSMinY(currentFrame) - heightDiff, 
											  NSWidth(currentFrame) + widthDiff, 
											  NSHeight(currentFrame) + heightDiff);
				
				// TODO: make sure the window doesn't grow off the bottom or right of the screen
				
				[[self window] setFrame:newFrame display:YES animate:YES];
			}
			
				// Set the minimum window size based on the new view.
			[[self window] setMinSize:NSMakeSize(minSizeBase.width + minViewSize.width, 
												 minSizeBase.height + minViewSize.height)];
				
				// Swap in the new view.
			[newPrefsEditor willSelect];
			[preferenceBox setContentView:[newPrefsEditor editorView]];
			[newPrefsEditor didSelect];
		}
		[currentController didUnselect];
		
		currentController = newPrefsEditor;
	}
	else if ([notification object] == disallowedImagesTable)
		[allowImagesButton setEnabled:([disallowedImagesTable numberOfSelectedRows] > 0)];
}


- (void)windowWillClose:(NSNotification *)notification
{
	if ([notification object] == [self window])
		[self showGeneralPreferences:self];
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[plugInClasses release];
	[plugInControllers release];
	[mainPreferencesView release];
	
    [super dealloc];
}


@end

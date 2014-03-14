//
//  PreferencesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 Frank M. Midgley. All rights reserved.
//

#import "PreferencesController.h"

#import "MacOSaiX.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXWarningController.h"


@implementation MacOSaiXPreferencesController


+ (MacOSaiXPreferencesController *)sharedController
{
	static MacOSaiXPreferencesController	*sharedController = 0;
	
	if (!sharedController)
	{
		sharedController = [[MacOSaiXPreferencesController alloc] initWithWindow:nil];
	}
	
	return sharedController;
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
	[autoStartCheckBox setState:([defaults boolForKey:@"Automatically Start Mosaics"] ? NSOnState : NSOffState)];
	[autoSaveCheckBox setState:([defaults boolForKey:@"Automatically Save Mosaics"] ? NSOnState : NSOffState)];
    int				frequency = [defaults integerForKey:@"Autosave Frequency"];
	if (frequency < 1)
		frequency = 1;
    [autoSaveFrequencyField setIntValue:frequency];
	
		// Get the list of plug-ins that have prefs.
	plugInClasses = [[NSMutableArray array] retain];
	plugInControllers = [[NSMutableDictionary dictionary] retain];
	MacOSaiX		*appDelegate = [NSApp delegate];
	NSArray			*allPlugInClasses = [[appDelegate tileShapesClasses] arrayByAddingObjectsFromArray:
											[appDelegate imageSourceClasses]];
	NSEnumerator	*plugInEnumerator = [allPlugInClasses objectEnumerator];
	Class			plugInClass = nil;
	while (plugInClass = [plugInEnumerator nextObject])
		if ([plugInClass preferencesControllerClass])
			[plugInClasses addObject:plugInClass];
	// TODO: sort by plug-in name
	[preferenceTable reloadData];
}


- (void)selectPaneForPlugInClass:(Class)plugInClass
{
	[currentController willUnselect];
	
		// Lookup or create the preference controller for this plug-in.
	id<MacOSaiXPreferencesController>	newController = [plugInControllers objectForKey:plugInClass];
	if (!newController)
	{
			// Create and cache a controller.
		newController = [[[[plugInClass preferencesControllerClass] alloc] init] autorelease];
		[plugInControllers setObject:newController forKey:plugInClass];
	}
	
		// Enlarge the window if needed.
	NSSize	currentViewSize = [[preferenceBox contentView] frame].size, 
			minViewSize = [newController minimumSize];
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
	[newController willSelect];
	[preferenceBox setContentView:[newController mainView]];
	[newController didSelect];
	
	[currentController didUnselect];
}


- (IBAction)setUpdateCheck:(id)sender
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setBool:([updateCheckBox state] == NSOnState) forKey:@"Perform Update Check at Launch"];
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


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [plugInClasses count] + 1;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id	object = nil;
	
	if (tableView == preferenceTable)
	{
		if ([[tableColumn identifier] isEqualToString:@"Icon"])
			object = (row == 0) ? [NSApp applicationIconImage] : [[plugInClasses objectAtIndex:row - 1] image];
		else
		{
			if (row == 0)
				object = @"General Preferences";
			else
			{
				Class		plugInClass = [plugInClasses objectAtIndex:row - 1];
				NSBundle	*plugInBundle = [NSBundle bundleForClass:plugInClass];
				
				object = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
				
				if ([plugInClass conformsToProtocol:@protocol(MacOSaiXTileShapes)])
					object = [NSString stringWithFormat:@"%@ Tile Shapes", object];
			}
		}
	}
	
	return object;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	int									selectedRow = [preferenceTable selectedRow];
	
	if (selectedRow == 0)
	{
		if (mainPreferencesView)
		{
			[currentController willUnselect];
			
			[preferenceBox setContentView:mainPreferencesView];
		
			[[self window] setMinSize:NSMakeSize(minSizeBase.width + mainViewMinSize.width, 
												 minSizeBase.height + mainViewMinSize.height)];
			
			[currentController didUnselect];
		}
		// else we're waking up from the nib and the main pref view is already set
		
		currentController = nil;
	}
	else
	{
		Class	plugInClass = [plugInClasses objectAtIndex:selectedRow - 1];
		
		[self selectPaneForPlugInClass:plugInClass];
		
		currentController = [plugInControllers objectForKey:plugInClass];
	}
}


- (void)windowWillClose:(NSNotification *)notification
{
	if ([notification object] == [self window])
	{
		[currentController willUnselect];
		[preferenceBox setContentView:mainPreferencesView];
		[currentController didUnselect];
	}
}


- (void)dealloc
{
	[plugInClasses release];
	[plugInControllers release];
	[mainPreferencesView release];
	
    [super dealloc];
}

@end

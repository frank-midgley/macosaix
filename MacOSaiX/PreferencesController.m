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
#import "MacOSaiXPreferencesController.h"


@implementation MacOSaiXPreferencesController


- (void)awakeFromNib
{
		// Retain the main prefs view so we can swap it out for plug-in's views.
	mainPreferencesView = [[preferenceBox contentView] retain];
	
	NSImageCell		*imageCell = [[[NSImageCell alloc] initImageCell:nil] autorelease];
	[[preferenceTable tableColumnWithIdentifier:@"Icon"] setDataCell:imageCell];
	
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


- (void)windowWillClose:(NSNotification *)notification
{
	if ([notification object] == [self window])
		[self autorelease];
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
				object = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
			else
			{
				Class	plugInClass = [plugInClasses objectAtIndex:row - 1];
				
				if ([plugInClass conformsToProtocol:@protocol(MacOSaiXTileShapes)])
					object = [NSString stringWithFormat:@"%@ Tile Shapes", [plugInClass name]];
				else
					object = [plugInClass name];
			}
		}
	}
	
	return object;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	// TODO: call -willUnselect and -didUnselect on the current controller
	
	int		selectedRow = [preferenceTable selectedRow];
	
	if (selectedRow == 0)
	{
		if (mainPreferencesView)
			[preferenceBox setContentView:mainPreferencesView];
	}
	else
	{
		Class								plugInClass = [plugInClasses objectAtIndex:selectedRow - 1];
		id<MacOSaiXPreferencesController>	controller = [plugInControllers objectForKey:plugInClass];
			
		if (!controller)
		{
			controller = [[[[plugInClass preferencesControllerClass] alloc] init] autorelease];
			[plugInControllers setObject:controller forKey:plugInClass];
		}
		
		[controller willSelect];
		[preferenceBox setContentView:[controller mainView]];
		[controller didSelect];
	}
}


- (void)dealloc
{
	[plugInClasses release];
	
    [super dealloc];
}

@end

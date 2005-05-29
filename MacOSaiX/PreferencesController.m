//
//  PreferencesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 Frank M. Midgley. All rights reserved.
//

#import "PreferencesController.h"


@implementation MacOSaiXPreferencesController


- (void)windowDidLoad
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];

    int				frequency = [defaults integerForKey:@"Autosave Frequency"];
	if (frequency < 1)
		frequency = 1;
    [autosaveFrequencyField setIntValue:frequency];
	
	[updateCheckBox setState:([defaults boolForKey:@"Perform Update Check at Launch"] ? NSOnState : NSOffState)];
	[autoStartCheckBox setState:([defaults boolForKey:@"Automatically Start Mosaics"] ? NSOnState : NSOffState)];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setInteger:[autosaveFrequencyField intValue] forKey:@"Autosave Frequency"];
    [defaults synchronize];
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


- (void)windowWillClose:(NSNotification *)notification
{
	if ([notification object] == [self window])
		[self autorelease];
}


- (void)dealloc
{
    [super dealloc];
}

@end

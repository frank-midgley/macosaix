//
//  PreferencesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "PreferencesController.h"


@implementation MacOSaiXPreferencesController


- (void)windowDidLoad
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
    int				frequency = [[[defaults objectForKey:@"Autosave Frequency"] description] intValue];
	
	if (frequency < 1)
		frequency = 1;
	
    [autosaveFrequencyField setIntValue:frequency];
}


- (void)userCancelled:(id)sender
{
    [self close];
}


- (void)savePreferences:(id)sender
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:[autosaveFrequencyField stringValue] forKey:@"Autosave Frequency"];
    [defaults synchronize];
    
    [self close];
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

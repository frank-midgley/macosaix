//
//  MacOSaiXUpdateAvailableController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 2/14/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXUpdateAvailableController.h"


@implementation MacOSaiXUpdateAvailableController

- (id)initWithMacPADSocket:(MacPADSocket *)inMacPAD
{
	if (self = [super initWithWindow:nil])
	{
		macPAD = [inMacPAD retain];
	}
	
	return self;
}


- (NSString *)windowNibName
{
	return @"Update Available";
}


- (void)awakeFromNib
{
	[newVersionTextField setStringValue:[NSString stringWithFormat:[newVersionTextField stringValue], [macPAD newVersion]]];
	[releaseNotesTextView setString:[macPAD releaseNotes]];
}


- (IBAction)download:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[macPAD productDownloadURL]];
	[self close];
}


- (IBAction)skipVersion:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[macPAD newVersion] forKey:@"Update Check Version to Skip"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self close];
}


- (IBAction)askAgainLater:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDate dateWithTimeIntervalSinceNow:60*60*24*7] 
											  forKey:@"Update Check After Date"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self close];
}


- (void)windowWillClose:(NSNotification *)notification
{
	[self autorelease];
}


- (void)dealloc
{
	[macPAD release];
	
	[super dealloc];
}


@end

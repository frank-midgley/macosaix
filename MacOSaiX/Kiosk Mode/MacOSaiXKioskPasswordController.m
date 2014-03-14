//
//  MacOSaiXKioskPasswordController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/18/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXKioskPasswordController.h"


@implementation MacOSaiXKioskPasswordController


- (NSString *)windowNibName
{
	return @"Kiosk Password";
}


- (IBAction)okPassword:(id)sender
{
	[passwordEntered release];
	passwordEntered = [[passwordField stringValue] copy];
	
	[NSApp stopModal];
}


- (IBAction)cancelPassword:(id)sender
{
	[passwordEntered release];
	passwordEntered = nil;
	
	[NSApp stopModalWithCode:NSCancelButton];
}


- (NSString *)passwordEntered
{
	return passwordEntered;
}


- (void)dealloc
{
	[passwordEntered release];
	
	[super dealloc];
}


@end

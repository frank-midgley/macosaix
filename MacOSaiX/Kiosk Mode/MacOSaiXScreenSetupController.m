//
//  MacOSaiXScreenSetupController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/8/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXScreenSetupController.h"


@implementation MacOSaiXScreenSetupController


- (NSString *)windowNibName
{
	return @"Screen Setup";
}


- (IBAction)setScreenType:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXKioskScreenTypeDidChangeNotification 
														object:self];
}


- (BOOL)shouldDisplayMosaicAndSettings
{
	return ([screenTypeMatrix selectedRow] == 0);
}


- (BOOL)shouldDisplayMosaicOnly
{
	return ([screenTypeMatrix selectedRow] == 1);
}


@end

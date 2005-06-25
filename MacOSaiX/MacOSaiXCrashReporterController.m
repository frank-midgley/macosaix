//
//  MacOSaiXCrashReporterController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXCrashReporterController.h"


@implementation MacOSaiXCrashReporterController


+ (void)checkForCrash
{
	if (YES)
	{
		MacOSaiXCrashReporterController	*controller = [[self alloc] initWithWindow:nil];
		
		[controller showWindow:self];
	}
}


- (NSString *)windowNibName
{
	return @"Crash Reporter";
}


- (void)awakeFromNib
{
}


- (IBAction)toggleReportDetails:(id)sender
{
}


- (IBAction)cancelReport:(id)sender
{
}


- (IBAction)submitReport:(id)sender
{
}


@end

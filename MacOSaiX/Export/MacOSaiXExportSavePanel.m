//
//  MacOSaiXExportSavePanel.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/1/07.
//  Copyright 2007 Frank M. Midgley.  All rights reserved.
//

#import "MacOSaiXExportSavePanel.h"

#import "MacOSaiXExportController.h"


@implementation MacOSaiXExportSavePanel


- (IBAction)ok:(id)sender
{
	BOOL	saveTheImage = YES;
	
	if ([[self delegate] exportCouldCrash])
	{
		int	result = NSRunCriticalAlertPanel(@"Saving an image that is this large may cause MacOSaiX to crash.", 
											 @"Make sure your mosaic project is saved before you continue.\n\nYou can reduce the image size by making the width or height smaller or by reducing the resolution.\n\nVisit the MacOSaiX web site for tips on creating larger images.", 
											 @"Save Image", @"Visit Web Page", @"Cancel");
		
		if (result != NSAlertDefaultReturn)
			saveTheImage = NO;
		
		if (result == NSAlertAlternateReturn)
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://homepage.mac.com/knarf/MacOSaiX/Questions.html"]];
	}
	
	if (saveTheImage)
		[super ok:sender];
}


@end

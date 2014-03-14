//
//  MacOSaiXKioskPasswordController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 6/18/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXKioskPasswordController : NSWindowController
{
	IBOutlet NSTextField	*passwordField;
	
	NSString				*passwordEntered;
}

- (IBAction)okPassword:(id)sender;
- (IBAction)cancelPassword:(id)sender;

- (NSString *)passwordEntered;

@end

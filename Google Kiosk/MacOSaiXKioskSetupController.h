//
//  MacOSaiXKioskSetupController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/8/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXKioskSetupController : NSWindowController
{
	IBOutlet NSMatrix			*originalImageMatrix,
								*windowTypeMatrix;
	IBOutlet NSSecureTextField	*passwordField,
								*repeatedPasswordField;
	IBOutlet NSTextField		*warningField;
	IBOutlet NSButton			*startButton;
}

- (IBAction)chooseOriginalImage:(id)sender;
- (IBAction)chooseWindowType:(id)sender;
- (IBAction)quit:(id)sender;
- (IBAction)start:(id)sender;

@end

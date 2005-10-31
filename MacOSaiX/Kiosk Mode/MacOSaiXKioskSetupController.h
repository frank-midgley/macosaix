//
//  MacOSaiXKioskSetupController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/8/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacOSaiXKioskMessageView.h"


@interface MacOSaiXKioskSetupController : NSWindowController
{
	IBOutlet NSMatrix					*originalImageMatrix,
										*windowTypeMatrix;
	IBOutlet NSButton					*requirePasswordButton;
	IBOutlet NSSecureTextField			*passwordField,
										*repeatedPasswordField;
	IBOutlet MacOSaiXKioskMessageView	*messageView;
	IBOutlet NSColorWell				*messageBackgroundColorWell;
	IBOutlet NSTextField				*warningField;
	IBOutlet NSButton					*startButton;
}

- (IBAction)chooseOriginalImage:(id)sender;
- (IBAction)setWindowType:(id)sender;
- (IBAction)setPasswordRequired:(id)sender;

- (NSAttributedString *)message;
- (IBAction)setMessageBackgroundColor:(id)sender;
- (NSColor *)messageBackgroundColor;

- (IBAction)quit:(id)sender;
- (IBAction)start:(id)sender;

@end

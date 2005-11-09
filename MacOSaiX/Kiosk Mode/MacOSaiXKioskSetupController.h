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
	IBOutlet NSSlider					*tileCountSlider;
	IBOutlet NSTextField				*tileCountTextField;
	IBOutlet MacOSaiXKioskMessageView	*messageView;
	IBOutlet NSColorWell				*messageBackgroundColorWell;
	IBOutlet NSTextField				*warningField;
	IBOutlet NSButton					*startButton;

	NSArray								*nonMainSetupControllers;
}

- (void)setNonMainSetupControllers:(NSArray *)array;

- (IBAction)chooseOriginalImage:(id)sender;

- (IBAction)setWindowType:(id)sender;
- (BOOL)shouldDisplayMosaicAndSettings;
- (BOOL)shouldDisplayMosaicOnly;

- (IBAction)setPasswordRequired:(id)sender;

- (IBAction)setTileCount:(id)sender;
- (int)tileCount;

- (NSAttributedString *)message;
- (IBAction)setMessageBackgroundColor:(id)sender;
- (NSColor *)messageBackgroundColor;

- (IBAction)quit:(id)sender;
- (IBAction)start:(id)sender;

@end

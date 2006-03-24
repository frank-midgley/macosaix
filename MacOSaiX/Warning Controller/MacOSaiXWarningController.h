//
//  MacOSaiXWarningController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 3/12/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXWarningController : NSWindowController
{
	IBOutlet NSTextField	*titleField, 
							*messageField;
	IBOutlet NSButton		*dontShowAgainButton, 
							*otherButton, 
							*alternateButton, 
							*defaultButton;
	
	NSString				*warningName;
}

+ (void)setWarning:(NSString *)name isEnabled:(BOOL)enabled;
+ (BOOL)warningIsEnabled:(NSString *)name;
+ (void)enableAllWarnings;

+ (int)runAlertForWarning:(NSString *)name 
					title:(NSString *)title 
				  message:(NSString *)message 
			 buttonTitles:(NSArray *)buttonTitles;	// default(, alternate(, other))

+ (void)beginSheetForWarning:(NSString *)name 
					   title:(NSString *)title 
					 message:(NSString *)message 
				buttonTitles:(NSArray *)buttonTitles	// default(, alternate(, other))
			  modalForWindow:(NSWindow *)window 
			   modalDelegate:(id)delegate
		  didDismissSelector:(SEL)didEndSelector 
				 contextInfo:(void *)contextInfo;

- (IBAction)setWarningIsEnabled:(id)sender;

@end


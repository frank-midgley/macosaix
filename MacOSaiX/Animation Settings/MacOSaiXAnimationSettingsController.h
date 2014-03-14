//
//  MacOSaiXAnimationSettingsController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/23/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MacOSaiXMosaic;


@interface MacOSaiXAnimationSettingsController : NSWindowController
{
	MacOSaiXMosaic					*mosaic;
	id								delegate;
	SEL								didEndSelector;
	
	IBOutlet NSMatrix				*animateAllImagesMatrix;
	IBOutlet NSPopUpButton			*fullSizedDisplayDurationPopUp;
	IBOutlet NSTextField			*messageField;
	IBOutlet NSButton				*includeSourceImageButton, 
									*insertDescriptionButton;
	IBOutlet NSPopUpButton			*animationDelayPopUp;
	IBOutlet NSButton				*cancelButton,
									*okButton;
}

+ (NSString *)imageDescriptionPlaceholder;

- (void)showAnimationSettingsForMosaic:(MacOSaiXMosaic *)mosaic 
						modalForWindow:(NSWindow *)window 
						 modalDelegate:(id)delegate
						didEndSelector:(SEL)didEndSelector;

- (IBAction)insertImageDescriptionPlaceholder:(id)sender;

- (IBAction)cancel:(id)sender;
- (IBAction)ok:(id)sender;

@end

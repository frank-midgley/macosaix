//
//  PreferencesController.h
//  MacOSaiX.app
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MacOSaiXPreferencesController : NSWindowController
{
    IBOutlet NSTextField	*autosaveFrequencyField;
	IBOutlet NSButton		*updateCheckBox;
}

- (IBAction)setUpdateCheck:(id)sender;

@end

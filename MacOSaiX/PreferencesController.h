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
    IBOutlet id		autosaveFrequencyField;
    IBOutlet id		okButton;
    BOOL		_userCancelled;
}

- (void)userCancelled:(id)sender;
- (void)savePreferences:(id)sender;

@end

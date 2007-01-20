//
//  MacOSaiXImageOrientationsEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"


@interface MacOSaiXImageOrientationsEditor : MacOSaiXEditor
{
	IBOutlet NSButton		*saveChangesButton, 
							*discardChangesButton;
}

- (IBAction)saveChanges:(id)sender;
- (IBAction)discardChanges:(id)sender;

@end

//
//  MacOSaiXUpdateAvailableController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 2/14/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacPADSocket.h"


@interface MacOSaiXUpdateAvailableController : NSWindowController
{
	MacPADSocket			*macPAD;

	IBOutlet NSTextField	*newVersionTextField;
	IBOutlet NSTextView		*releaseNotesTextView;
}

- (id)initWithMacPADSocket:(MacPADSocket *)updateInfo;
- (IBAction)download:(id)sender;
- (IBAction)skipVersion:(id)sender;
- (IBAction)askAgainLater:(id)sender;

@end

//
//  MacOSaiXScreenSetupController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/8/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXScreenSetupController : NSWindowController
{
	IBOutlet NSMatrix	*screenTypeMatrix;
}

- (IBAction)setScreenType:(id)sender;

@end

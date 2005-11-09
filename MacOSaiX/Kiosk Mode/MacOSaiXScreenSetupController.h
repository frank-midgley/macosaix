//
//  MacOSaiXScreenSetupController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/8/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#define MacOSaiXKioskScreenTypeDidChangeNotification	@"MacOSaiXKioskScreenTypeDidChangeNotification"


@interface MacOSaiXScreenSetupController : NSWindowController
{
	IBOutlet NSMatrix	*screenTypeMatrix;
}

- (IBAction)setScreenType:(id)sender;
- (BOOL)shouldDisplayMosaicAndSettings;
- (BOOL)shouldDisplayMosaicOnly;

@end

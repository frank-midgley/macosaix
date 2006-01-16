//
//  GooglePreferencesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/29/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXPreferencesController.h"


@interface GooglePreferencesController : NSObject <MacOSaiXPreferencesController>
{
	IBOutlet NSView			*mainView;
	
	IBOutlet NSTextField	*maxCacheSizeField, 
							*minFreeSpaceField;
	IBOutlet NSPopUpButton	*maxCacheSizePopUp, 
							*minFreeSpacePopUp;
	IBOutlet NSImageView	*volumeImageView;
	IBOutlet NSTextField	*volumeNameField;
}

- (IBAction)setMaxCacheSizeMagnitude:(id)sender;
- (IBAction)setMinFreeSpaceMagnitude:(id)sender;

- (IBAction)deleteCachedImages:(id)sender;

@end

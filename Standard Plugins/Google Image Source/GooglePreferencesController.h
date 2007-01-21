//
//  GooglePreferencesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/29/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//


@interface MacOSaiXGooglePreferencesEditor : NSObject <MacOSaiXPlugInPreferencesEditor>
{
	IBOutlet NSView			*editorView;
	
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

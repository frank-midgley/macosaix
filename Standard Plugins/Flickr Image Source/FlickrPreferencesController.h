//
//  FlickrPreferencesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 1/28/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//


@interface MacOSaiXFlickrPreferencesController : NSObject <MacOSaiXPlugInPreferencesEditor>
{
	id<MacOSaiXEditorDelegate>	delegate;
	
	IBOutlet NSView				*mainView;
	
	IBOutlet NSTextField		*maxCacheSizeField, 
								*minFreeSpaceField;
	IBOutlet NSPopUpButton		*maxCacheSizePopUp, 
								*minFreeSpacePopUp;
	IBOutlet NSImageView		*volumeImageView;
	IBOutlet NSTextField		*volumeNameField;
}

- (IBAction)setMaxCacheSizeMagnitude:(id)sender;
- (IBAction)setMinFreeSpaceMagnitude:(id)sender;

- (IBAction)deleteCachedImages:(id)sender;

@end

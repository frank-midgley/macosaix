/*
	MacOSaiXDocument.h
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import <Cocoa/Cocoa.h>

#import "MacOSaiXMosaic.h"
#import "MacOSaiXWindowController.h"


@class MacOSaiXWindowController, MacOSaiXProgressController;


@interface MacOSaiXDocument : NSDocument 
{
	MacOSaiXMosaic				*mosaic;
	MacOSaiXWindowController	*mainWindowController;
	MacOSaiXProgressController	*progressController;
	
		// Document state
    BOOL						documentIsClosing,	// flag set to true when document is closing
								autoSaveEnabled,
								missedAutoSave;
		
		// Saving
    NSDate						*lastSaved;
    NSTimer						*autosaveTimer;
	BOOL						saving, 
								loadCancelled;
}

- (void)setMosaic:(MacOSaiXMosaic *)inMosaic;
- (MacOSaiXMosaic *)mosaic;

- (BOOL)isSaving;
- (BOOL)isClosing;

- (void)setAutoSaveEnabled:(BOOL)flag;
- (BOOL)autoSaveEnabled;

@end

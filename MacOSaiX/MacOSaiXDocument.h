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
	
	NSString					*targetImagePath;
	
		// Document state
    BOOL						documentIsClosing,	// flag set to true when document is closing
								autoSaveEnabled,
								missedAutoSave;
		
		// Saving
    NSDate						*lastSaved;
    NSTimer						*autosaveTimer;
	BOOL						saving, 
								loading, 
								loadCancelled;
}

- (void)setMosaic:(MacOSaiXMosaic *)inMosaic;
- (MacOSaiXMosaic *)mosaic;

- (void)setTargetImagePath:(NSString *)path;
- (NSString *)targetImagePath;

- (BOOL)isSaving;
- (BOOL)isClosing;

- (void)setAutoSaveEnabled:(BOOL)flag;
- (BOOL)autoSaveEnabled;

@end

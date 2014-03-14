/*
	MacOSaiXDocument.h
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import <Cocoa/Cocoa.h>

#import "MacOSaiXMosaic.h"
#import "MacOSaiXWindowController.h"


@class MacOSaiXWindowController;


@interface MacOSaiXDocument : NSDocument 
{
	MacOSaiXMosaic				*mosaic;
	MacOSaiXWindowController	*mainWindowController;
	
	NSString					*originalImagePath;
	
		// Document state
    BOOL						documentIsClosing,	// flag set to true when document is closing
								autoSaveEnabled,
								missedAutoSave;
		
		// Saving
    NSDate						*lastSaved;
    NSTimer						*autosaveTimer;
	BOOL						loading;
}

- (void)setMosaic:(MacOSaiXMosaic *)inMosaic;
- (MacOSaiXMosaic *)mosaic;

- (void)setOriginalImagePath:(NSString *)path;
- (NSString *)originalImagePath;

- (BOOL)isClosing;

- (void)setAutoSaveEnabled:(BOOL)flag;
- (BOOL)autoSaveEnabled;

@end

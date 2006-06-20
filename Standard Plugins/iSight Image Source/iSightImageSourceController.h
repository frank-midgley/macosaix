//
//  QuickTimeImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MacOSaiXImageSource.h"
#import "QuickTimeImageSource.h"


@interface QuickTimeImageSourceController : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView				*editorView;
	
	IBOutlet NSArrayController	*moviesController;
	IBOutlet NSTableView		*moviesTable;
	IBOutlet NSButton			*chooseAnotherMovieButton, 
								*clearMovieListButton, 
								*saveFramesCheckBox;
	
	IBOutlet NSBox				*movieBox;
	IBOutlet NSMovieView		*movieView;
	IBOutlet NSTextField		*movieNameTextField;
	
	QuickTimeImageSource		*currentImageSource;
}

- (IBAction)chooseAnotherMovie:(id)sender;
- (IBAction)clearMovieList:(id)sender;
- (IBAction)setSaveFrames:(id)sender;

@end

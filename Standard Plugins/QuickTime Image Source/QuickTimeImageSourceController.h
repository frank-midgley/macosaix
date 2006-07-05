//
//  QuickTimeImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "QuickTimeImageSource.h"


@interface QuickTimeImageSourceController : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView				*editorView;
	
	IBOutlet NSArrayController	*moviesController;
	IBOutlet NSTableView		*moviesTable;
	
	IBOutlet NSMatrix			*samplingRateMatrix;
	IBOutlet NSTextField		*samplingRateField;
	IBOutlet NSSlider			*samplingRateSlider;
	
	IBOutlet NSButton			*saveFramesCheckBox;
	
	IBOutlet NSMovieView		*movieView;
	
	QuickTimeImageSource		*currentImageSource;
}

- (IBAction)chooseAnotherMovie:(id)sender;
- (IBAction)removeMovie:(id)sender;

- (IBAction)setSamplingRateType:(id)sender;
- (IBAction)setConstantSamplingRate:(id)sender;
- (IBAction)setSaveFrames:(id)sender;

@end

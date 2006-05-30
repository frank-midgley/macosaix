//
//  MacOSaiXImageSourceEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 5/23/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSource.h"

@class MacOSaiXMosaic;


@interface MacOSaiXImageSourceEditor : NSWindowController
{
	IBOutlet NSBox						*editorBox;
	IBOutlet NSButton					*cancelButton, 
										*okButton;
	
	id<MacOSaiXImageSourceController>	editor;
	
	MacOSaiXMosaic						*mosaic;
	
	id<MacOSaiXImageSource>				originalImageSource, 
										editedImageSource;
	
	id									delegate;
	SEL									didEndSelector;
}

- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
				 mosaic:(MacOSaiXMosaic *)inMosaic
		 modalForWindow:(NSWindow *)window 
		  modalDelegate:(id)inDelegate
		 didEndSelector:(SEL)inDidEndSelector;

- (IBAction)cancel:(id)sender;
- (IBAction)save:(id)sender;

@end

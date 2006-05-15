//
//  MacOSaiXTilesSetupController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 2/11/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXMosaic.h"
#import "MacOSaiXTileShapes.h"


@interface MacOSaiXTilesSetupController : NSWindowController
{
	MacOSaiXMosaic					*mosaic;
	id								delegate;
	SEL								didEndSelector;
	
		// Tile shapes
	IBOutlet NSPopUpButton			*plugInsPopUp;
	IBOutlet NSBox					*editorBox;
	id<MacOSaiXTileShapesEditor>	editor;
	id<MacOSaiXTileShapes>			tileShapesBeingEdited;
	
	IBOutlet NSImageView			*previewImageView;
	IBOutlet NSTextField			*countField,
									*tileSizeField;
	
		// Image rules
	IBOutlet NSPopUpButton			*imageUseCountPopUp,
									*imageReuseDistancePopUp;
	IBOutlet NSSlider				*imageCropLimitSlider;
	IBOutlet NSButton				*cancelButton,
									*okButton;
}

- (void)setupTilesForMosaic:(MacOSaiXMosaic *)mosaic 
			 modalForWindow:(NSWindow *)window 
			  modalDelegate:(id)delegate
			 didEndSelector:(SEL)didEndSelector;

- (IBAction)setPlugIn:(id)sender;

- (IBAction)setImageUseCount:(id)sender;

- (IBAction)cancel:(id)sender;
- (IBAction)ok:(id)sender;

@end

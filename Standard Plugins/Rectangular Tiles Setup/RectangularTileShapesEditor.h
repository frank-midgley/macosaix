
//
//  RectangularTileShapesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXRectangularTileShapes;


@interface MacOSaiXRectangularTileShapesEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXDataSourceEditorDelegate>	delegate;
	
	IBOutlet NSView							*editorView;
	
		// Freeform controls
	IBOutlet NSSlider						*tilesAcrossSlider,
											*tilesDownSlider;
    IBOutlet NSTextField					*tilesAcrossTextField,
											*tilesDownTextField;
	IBOutlet NSStepper						*tilesAcrossStepper, 
											*tilesDownStepper;

		// Fixed Size controls
	IBOutlet NSPopUpButton					*tilesSizePopUp;
	IBOutlet NSSlider						*tilesSizeSlider,
											*tilesCountSlider;
	
	NSSize									targetImageSize;
	float									minAspectRatio,
											maxAspectRatio;
	MacOSaiXRectangularTileShapes			*currentTileShapes;
}

- (IBAction)setTilesAcross:(id)sender;
- (IBAction)setTilesDown:(id)sender;

- (IBAction)setTilesSize:(id)sender;
- (IBAction)setTilesCount:(id)sender;

@end

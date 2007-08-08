
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
	id<MacOSaiXEditorDelegate>		delegate;
	
	IBOutlet NSView					*editorView;
	
	IBOutlet NSMatrix				*tilesSizeMatrix;
	IBOutlet NSTabView				*tilesSizeTabView;
	
		// Freeform size pieces
    IBOutlet NSTextField			*tilesAcrossTextField,
									*tilesDownTextField;
	IBOutlet NSSlider				*tilesAcrossSlider,
									*tilesDownSlider;
	IBOutlet NSStepper				*tilesAcrossStepper, 
									*tilesDownStepper;
	
		// Fixed size pieces
	IBOutlet NSSlider				*tilesSizeSlider, 
									*tilesCountSlider;
	IBOutlet NSPopUpButton			*tilesSizePopUp;
	
		// Other size panel
	IBOutlet NSPanel				*otherSizePanel;
	IBOutlet NSTextField			*otherSizeField;
	IBOutlet NSButton				*okButton;
	
	NSSize							targetImageSize;
	float							minAspectRatio,
									maxAspectRatio;
	MacOSaiXRectangularTileShapes	*currentTileShapes;
}

- (IBAction)setTilesSizeType:(id)sender;

	// Freeform size pieces
- (IBAction)setTilesAcross:(id)sender;
- (IBAction)setTilesDown:(id)sender;

	// Fixed size pieces
- (IBAction)setTilesSize:(id)sender;
- (IBAction)setTilesCount:(id)sender;

	// Other size panel
- (IBAction)setOtherSize:(id)sender;
- (IBAction)cancelOtherSize:(id)sender;

@end

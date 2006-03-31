
//
//  RectangularTileShapesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapes.h"
#import "RectangularTileShapes.h"


@interface MacOSaiXRectangularTileShapesEditor : NSObject <MacOSaiXTileShapesEditor>
{
	IBOutlet NSView					*editorView;
	
		// Freeform tab
	IBOutlet NSSlider				*tilesAcrossSlider,
									*tilesDownSlider;
    IBOutlet NSTextField			*tilesAcrossTextField,
									*tilesDownTextField;
	IBOutlet NSStepper				*tilesAcrossStepper, 
									*tilesDownStepper;

		// Fixed Size tab
	IBOutlet NSPopUpButton			*tilesSizePopUp;
	IBOutlet NSSlider				*tilesSizeSlider,
									*tilesCountSlider;
    IBOutlet NSTextField			*tilesSizeTextField, 
									*widerLabel, 
									*tallerLabel;
	
	id								editorDelegate;
	NSSize							originalImageSize;
	float							minAspectRatio,
									maxAspectRatio;
	MacOSaiXRectangularTileShapes	*currentTileShapes;
}

- (IBAction)setTilesAcross:(id)sender;
- (IBAction)setTilesDown:(id)sender;

- (IBAction)setTilesSize:(id)sender;
- (IBAction)setOtherTilesSize:(id)sender;
- (IBAction)setTilesCount:(id)sender;

@end

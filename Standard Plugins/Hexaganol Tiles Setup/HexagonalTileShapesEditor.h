//
//  HexagonalTileShapesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapes.h"
#import "HexagonalTileShapes.h"


@interface MacOSaiXHexagonalTileShapesEditor : NSObject <MacOSaiXTileShapesEditor>
{
	IBOutlet NSView					*editorView;
	
		// Freeform controls
	IBOutlet NSSlider				*tilesAcrossSlider,
									*tilesDownSlider;
    IBOutlet NSTextField			*tilesAcrossTextField,
									*tilesDownTextField;
	IBOutlet NSStepper				*tilesAcrossStepper, 
									*tilesDownStepper;
	
		// Fixed Size controls
	IBOutlet NSPopUpButton			*tilesSizePopUp;
	IBOutlet NSSlider				*tilesSizeSlider,
									*tilesCountSlider;
	
	NSSize							originalImageSize;
	float							minAspectRatio,
									maxAspectRatio;
	MacOSaiXHexagonalTileShapes		*currentTileShapes;
}

- (IBAction)setTilesAcross:(id)sender;
- (IBAction)setTilesDown:(id)sender;

- (IBAction)setTilesSize:(id)sender;
- (IBAction)setTilesCount:(id)sender;

@end

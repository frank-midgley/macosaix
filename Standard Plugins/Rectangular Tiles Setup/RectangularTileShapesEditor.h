
//
//  RectangularTileShapesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXRectangularTilesOrientationView.h"
#import "MacOSaiXTileShapes.h"
#import "RectangularTileShapes.h"


@interface MacOSaiXRectangularTileShapesEditor : NSObject <MacOSaiXTileShapesEditor>
{
	IBOutlet NSView										*editorView;
	
		// Freeform controls
	IBOutlet NSSlider									*tilesAcrossSlider,
														*tilesDownSlider;
    IBOutlet NSTextField								*tilesAcrossTextField,
														*tilesDownTextField;
	IBOutlet NSStepper									*tilesAcrossStepper, 
														*tilesDownStepper;

		// Fixed Size controls
	IBOutlet NSPopUpButton								*tilesSizePopUp;
	IBOutlet NSSlider									*tilesSizeSlider,
														*tilesCountSlider;
	
		// Image Aligment controls
	IBOutlet NSMatrix									*imageOrientationMatrix;
	IBOutlet MacOSaiXRectangularTilesOrientationView	*imageOrientationView;
	IBOutlet NSTextField								*imageOrientationLabel;
	
	NSImage												*originalImage;
	NSSize												originalImageSize;
	float												minAspectRatio,
														maxAspectRatio;
	MacOSaiXRectangularTileShapes						*currentTileShapes;
}

- (IBAction)setTilesAcross:(id)sender;
- (IBAction)setTilesDown:(id)sender;

- (IBAction)setTilesSize:(id)sender;
- (IBAction)setTilesCount:(id)sender;

- (IBAction)setImageOrientation:(id)sender;

@end

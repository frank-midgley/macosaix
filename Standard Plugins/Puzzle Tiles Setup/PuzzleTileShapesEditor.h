//
//  PuzzleTileShapesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapes.h"
#import "PuzzleTileShapes.h"


@interface MacOSaiXPuzzleTileShapesEditor : NSObject <MacOSaiXTileShapesEditor>
{
	IBOutlet NSView				*editorView;
    IBOutlet NSTextField		*tilesAcrossTextField,
								*tilesDownTextField, 
								*tabbedSidesTextField, 
								*curvinessTextField;
	IBOutlet NSSlider			*tilesAcrossSlider,
								*tilesDownSlider, 
								*tilesSizeSlider, 
								*tilesCountSlider, 
								*tabbedSidesSlider, 
								*curvinessSlider;
	IBOutlet NSStepper			*tilesAcrossStepper, 
								*tilesDownStepper;
	IBOutlet NSPopUpButton		*tilesSizePopUp;
	IBOutlet NSMatrix			*alignImagesMatrix;
	
	NSSize						originalImageSize;
	float						minAspectRatio,
								maxAspectRatio;
	MacOSaiXPuzzleTileShapes	*currentTileShapes;
	
	NSTimer						*previewTimer;
	MacOSaiXPuzzleTileShape		*previewShape;
}

- (IBAction)setTilesAcross:(id)sender;
- (IBAction)setTilesDown:(id)sender;
- (IBAction)setTilesSize:(id)sender;
- (IBAction)setTilesCount:(id)sender;

- (IBAction)setTabbedSides:(id)sender;
- (IBAction)setCurviness:(id)sender;

- (IBAction)setImagesAligned:(id)sender;

@end

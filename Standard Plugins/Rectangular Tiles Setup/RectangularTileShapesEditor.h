
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
    IBOutlet NSTextField			*tilesAcrossTextField,
									*tilesDownTextField, 
									*tileSizeTextField;
	IBOutlet NSSlider				*tilesAcrossSlider,
									*tilesDownSlider, 
									*tileSizeSlider;
	IBOutlet NSButton				*preserveTileSizeCheckBox;
	
	id								editorDelegate;
	NSSize							originalImageSize;
	float							minAspectRatio,
									maxAspectRatio;
	MacOSaiXRectangularTileShapes	*currentTileShapes;
}

- (IBAction)setTilesAcross:(id)sender;
- (IBAction)setTilesDown:(id)sender;
- (IBAction)setTilesSize:(id)sender;

- (IBAction)setTileSizePreserved:(id)sender;

@end

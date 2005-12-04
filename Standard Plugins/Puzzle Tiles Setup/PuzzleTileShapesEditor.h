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
								*tileSizeTextField,
								*tabbedSidesTextField, 
								*curvinessTextField;
	IBOutlet NSSlider			*tilesAcrossSlider,
								*tilesDownSlider, 
								*tileSizeSlider, 
								*tabbedSidesSlider, 
								*curvinessSlider;
	IBOutlet NSButton			*preserveTileSizeCheckBox;
	
	id							editorDelegate;
	NSSize						originalImageSize;
	MacOSaiXPuzzleTileShapes	*currentTileShapes;
	
	NSTimer						*previewTimer;
	PuzzlePiece					previewPiece;
}

- (IBAction)setTilesAcross:(id)sender;
- (IBAction)setTilesDown:(id)sender;
- (IBAction)setTilesSize:(id)sender;
- (IBAction)setTabbedSides:(id)sender;
- (IBAction)setCurviness:(id)sender;

- (IBAction)setTileSizePreserved:(id)sender;

@end

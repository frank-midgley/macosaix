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
								*tileSizeTextField;
	IBOutlet NSSlider			*tilesAcrossSlider,
								*tilesDownSlider, 
								*tileSizeSlider;
	IBOutlet NSButton			*preserveTileSizeCheckBox;
	
	id							editorDelegate;
	NSSize						originalImageSize;
	MacOSaiXPuzzleTileShapes	*currentTileShapes;
	
	NSTimer						*previewTimer;
	PuzzleTabType				topTabType, 
								leftTabType, 
								rightTabType, 
								bottomTabType;
}

- (IBAction)setTilesAcross:(id)sender;
- (IBAction)setTilesDown:(id)sender;
- (IBAction)setTilesSize:(id)sender;

- (IBAction)setTileSizePreserved:(id)sender;

@end

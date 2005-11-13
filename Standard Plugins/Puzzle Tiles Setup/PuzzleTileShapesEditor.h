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
								*tilesDownTextField;
    IBOutlet NSStepper			*tilesAcrossStepper, 
								*tilesDownStepper;
	IBOutlet NSTextField		*tileCountTextField, 
								*tileSizeTextField;
	IBOutlet NSButton			*restrictTileSizeCheckBox;
	IBOutlet NSPopUpButton		*restrictedXSizePopUpButton,
								*restrictedYSizePopUpButton;
	
	NSSize						originalImageSize;
	MacOSaiXPuzzleTileShapes	*currentTileShapes;
}

- (IBAction)setTilesAcross:(id)sender;
- (IBAction)setTilesDown:(id)sender;
- (IBAction)restrictTileSize:(id)sender;
- (IBAction)setRestrictedXSize:(id)sender;
- (IBAction)setRestrictedYSize:(id)sender;

@end

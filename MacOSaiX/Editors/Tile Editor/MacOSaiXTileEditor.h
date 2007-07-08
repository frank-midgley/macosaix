//
//  MacOSaiXTileEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"

@class MacOSaiXTile;


@interface MacOSaiXTileContentEditor : MacOSaiXMosaicEditor
{
    NSArray					*selectedTiles;
	
	IBOutlet NSPopUpButton	*fillStylePopUp;
	IBOutlet NSTabView		*fillStyleTabView;
	
		// Best match from sources tab
	IBOutlet NSImageView	*bestMatchImageView;
	IBOutlet NSPopUpButton	*dontUseThisImagePopUp;
	NSButton				*openBestMatchInBrowserButton;
	
		// Hand-picked image tab
	IBOutlet NSImageView	*handPickedImageView;
	IBOutlet NSButton		*chooseImageButton;
	
		// Portion of target image tab
	IBOutlet NSImageView	*portionOfTargetImageView;
	
		// Solid color tab
	IBOutlet NSMatrix		*solidColorMatrix;
	IBOutlet NSColorWell	*solidColorWell;
	
	NSPoint					mouseDownPoint, 
							mouseDragPoint;
}

- (void)setSelectedTiles:(NSArray *)tiles;
- (NSArray *)selectedTiles;

- (IBAction)setFillStyle:(id)sender;

- (IBAction)dontUseThisImage:(id)sender;

- (IBAction)chooseImageForTile:(id)sender;

- (IBAction)setSolidColor:(id)sender;

@end

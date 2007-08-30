//
//  MacOSaiXSpiralTileShapesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 8/16/2007.
//  Copyright (c) 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXSpiralTileShapes;


@interface MacOSaiXSpiralTileShapesEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>	delegate;
	
	IBOutlet NSView				*editorView;
	
	IBOutlet NSSlider			*spiralTightnessSlider,
								*tileAspectRatioSlider;
	
		// Other size panel
	IBOutlet NSPanel			*otherSizePanel;
	IBOutlet NSTextField		*otherSizeField;
	IBOutlet NSButton			*okButton;
	
	MacOSaiXSpiralTileShapes	*currentTileShapes;
}

- (IBAction)setSpiralTightness:(id)sender;
- (IBAction)setTileSize:(id)sender;

	// Other size panel
- (IBAction)setOtherSize:(id)sender;
- (IBAction)cancelOtherSize:(id)sender;

@end


//
//  GuitarPickTileShapesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapes.h"
#import "GuitarPickTileShapes.h"


@interface MacOSaiXGuitarPickTileShapesEditor : NSObject <MacOSaiXTileShapesEditor>
{
	IBOutlet NSView					*editorView;
	
	IBOutlet NSSlider				*rowCountSlider;
    IBOutlet NSTextField			*rowCountTextField;
	IBOutlet NSStepper				*rowCountStepper;
	
	NSSize							originalImageSize;
	MacOSaiXGuitarPickTileShapes	*currentTileShapes;
}

- (IBAction)setRowCount:(id)sender;

@end

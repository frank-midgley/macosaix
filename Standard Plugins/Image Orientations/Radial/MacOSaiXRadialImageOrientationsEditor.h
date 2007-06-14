//
//  MacOSaiXRadialImageOrientationsEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 6/13/07.
//  Copyright (c) 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXRadialImageOrientations;


@interface MacOSaiXRadialImageOrientationsEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>		delegate;
	
	IBOutlet NSView					*editorView;
	IBOutlet NSPopUpButton			*presetsPopUp;
	IBOutlet NSSlider				*angleSlider;
	IBOutlet NSTextField			*angleTextField;
	
		// The image orientations instance currently being edited.
	MacOSaiXRadialImageOrientations	*currentImageOrientations;
}

- (IBAction)setPresetOrientations:(id)sender;
- (IBAction)setOffsetAngle:(id)sender;

@end

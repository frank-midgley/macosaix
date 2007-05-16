//
//  ConstantImageOrientationsEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on Dec 07 2006.
//  Copyright (c) 2006 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXConstantImageOrientations;


@interface MacOSaiXConstantImageOrientationsEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>	delegate;
	
	IBOutlet NSView				*editorView;
	IBOutlet NSSlider			*angleSlider;
	IBOutlet NSTextField		*angleTextField;
	
		// The image orientations instance currently being edited.
	MacOSaiXConstantImageOrientations		*currentImageOrientations;
}

- (IBAction)setConstantAngle:(id)sender;

@end

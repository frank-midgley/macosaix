//
//  MacOSaiXBitmapExportEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 5/14/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXBitmapExportSettings;


@interface MacOSaiXBitmapExportEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>			delegate;
	
	MacOSaiXBitmapExportSettings		*currentSettings;
	
	IBOutlet NSView						*editorView;
	IBOutlet NSMatrix					*formatMatrix;
	IBOutlet NSTextField				*widthField, 
										*heightField;
	IBOutlet NSPopUpButton				*unitsPopUp, 
										*resolutionPopUp;
}

- (IBAction)setFormat:(id)sender;
- (IBAction)setUnits:(id)sender;
- (IBAction)setResolution:(id)sender;

@end

//
//  MacOSaiXPDFExportEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 5/31/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXPDFExportSettings;


@interface MacOSaiXPDFExportEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>		delegate;
	
	MacOSaiXPDFExportSettings		*currentSettings;
	
	IBOutlet NSView					*editorView;
	IBOutlet NSTextField			*widthField, 
									*heightField;
	IBOutlet NSPopUpButton			*unitsPopUp;
}

- (IBAction)setUnits:(id)sender;

@end

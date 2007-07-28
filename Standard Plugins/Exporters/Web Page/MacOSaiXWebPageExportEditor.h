//
//  MacOSaiXWebPageExportEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 7/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXWebPageExportSettings;


@interface MacOSaiXWebPageExportEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>		delegate;
	
	MacOSaiXWebPageExportSettings	*currentSettings;
	
	IBOutlet NSView					*editorView;
	IBOutlet NSTextField			*widthField, 
									*heightField;
	IBOutlet NSButton				*includeTargetImageButton, 
									*includeTilePopUpsButton;
}

- (IBAction)setIncludeTargetImage:(id)sender;
- (IBAction)setIncludeTilePopUps:(id)sender;

@end

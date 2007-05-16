/*
	GoogleImageSourceController.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

@class MacOSaiXGoogleImageSource;

@interface MacOSaiXGoogleImageSourceEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>	delegate;
	
		// Simple view
	IBOutlet NSView				*editorView;
	IBOutlet NSTextField		*keywordsTextField;
	IBOutlet NSMatrix			*keywordsMatchingMatrix;
	IBOutlet NSTextField		*moreOptionsTextField;
	
		// More options panel
	IBOutlet NSPanel			*moreOptionsPanel;
	IBOutlet NSTextField		*requiredTermsTextField,
								*optionalTermsTextField,
								*excludedTermsTextField,
								*siteTextField;
	IBOutlet NSPopUpButton		*colorSpacePopUpButton,
								*adultContentFilteringPopUpButton;
	IBOutlet NSButton			*okButton;

	MacOSaiXGoogleImageSource	*currentImageSource;
}

- (IBAction)setKeywordsMatching:(id)sender;

- (IBAction)showMoreOptions:(id)sender;
- (IBAction)saveMoreOptions:(id)sender;
- (IBAction)cancelMoreOptions:(id)sender;

@end

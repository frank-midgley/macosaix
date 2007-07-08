//
//  GlyphImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "GlyphImageSource.h"


@interface MacOSaiXGlyphImageSourceEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>	delegate;
	
	IBOutlet NSView				*editorView;
	
	IBOutlet NSPopUpButton		*fontsPopUp, 
								*colorsPopUp;
	IBOutlet NSTextView			*lettersView;
	IBOutlet NSMatrix			*sizeMatrix;
	IBOutlet NSPopUpButton		*sizePopUp;
	IBOutlet NSSlider			*sizeSlider;
	IBOutlet NSImageView		*sampleImageView;
	
	MacOSaiXGlyphImageSource	*currentImageSource;
	NSTimer						*sampleTimer;
}

- (IBAction)useAllFonts:(id)sender;
- (IBAction)useFontCollection:(id)sender;
- (IBAction)useFontFamily:(id)sender;
- (IBAction)editFontCollections:(id)sender;

- (IBAction)useBuiltInColors:(id)sender;
- (IBAction)useSystemWideColors:(id)sender;
- (IBAction)editSystemWideColors:(id)sender;

- (IBAction)setSize:(id)sender;

@end

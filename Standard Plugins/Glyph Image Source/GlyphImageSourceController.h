//
//  GlyphImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacOSaiXImageSource.h"
#import "GlyphImageSource.h"


@interface MacOSaiXGlyphImageSourceController : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView				*editorView;
	
		// Fonts tab
	IBOutlet NSMatrix			*fontsMatrix;
	IBOutlet NSOutlineView		*fontsOutlineView;
	IBOutlet NSButton			*noFontsButton, 
								*allFontsButton;
	
		// Colors tab
	IBOutlet NSMatrix			*colorsMatrix;
	IBOutlet NSOutlineView		*colorsOutlineView;
	
		// Letters tab
	IBOutlet NSMatrix			*lettersMatrix;
	IBOutlet NSTextView			*lettersView;

		// Sample images
	IBOutlet NSImageView		*sampleImageView;
	IBOutlet NSTextField		*sizeTextField;
	
		// Counts
	IBOutlet NSMatrix			*countMatrix;
	IBOutlet NSTextField		*countTextField;
	
	NSButton					*okButton;
	
	MacOSaiXGlyphImageSource	*currentImageSource;
	NSTimer						*sampleTimer;
	
		// Font outline view data sources
	NSArray						*fontFamilyNames;
	NSMutableArray				*chosenFonts;
	NSMutableDictionary			*availableFontMembers;
	
		// Colors table data sources
	NSMutableArray				*builtinColorLists,
								*systemWideColorLists,
								*photoshopColorLists;
}

	// Fonts tab
- (IBAction)setFontsOption:(id)sender;
- (IBAction)toggleFont:(id)sender;
- (IBAction)chooseNoFonts:(id)sender;
- (IBAction)chooseAllFonts:(id)sender;

	// Colors tab
- (IBAction)setColorsOption:(id)sender;
- (IBAction)toggleColor:(id)sender;

	// Letters tab
- (IBAction)setLettersOption:(id)sender;

	// Counts
- (IBAction)setCountOption:(id)sender;

@end

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
	
	IBOutlet NSOutlineView		*fontsOutlineView;
	IBOutlet NSTableView		*colorsTableView;
	IBOutlet NSButton			*toggleFontsButton,
								*toggleColorsButton;
	IBOutlet NSMatrix			*textMatrix,
								*countMatrix;
	IBOutlet NSTextView			*textView;
	IBOutlet NSTextField		*countTextField;
	IBOutlet NSImageView		*sampleImageView;
	IBOutlet NSTextField		*sizeTextField;
	
	NSButton					*okButton;
	
	MacOSaiXGlyphImageSource	*currentImageSource;
	NSTimer						*sampleTimer;
	NSArray						*fontFamilyNames;
	NSMutableArray				*chosenFonts;
	NSMutableDictionary			*availableFontMembers;
}

- (IBAction)toggleFont:(id)sender;
- (IBAction)toggleSelectedFonts:(id)sender;
- (IBAction)toggleColor:(id)sender;
- (IBAction)toggleSelectedColors:(id)sender;
- (IBAction)setTextOption:(id)sender;
- (IBAction)setCountOption:(id)sender;

@end

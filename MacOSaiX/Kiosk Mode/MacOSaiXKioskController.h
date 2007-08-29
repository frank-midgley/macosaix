//
//  MacOSaiXKioskController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 9/26/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXMosaic, MosaicView, MacOSaiXKioskView, MacOSaiXKioskMessageView;


@interface MacOSaiXKioskController : NSWindowController
{
		// The six top level views
	IBOutlet MacOSaiXKioskView			*kioskView;	// content view of the window
	IBOutlet NSMatrix					*targetImageMatrix;
	IBOutlet MacOSaiXKioskMessageView	*messageView;
	IBOutlet NSBox						*vanityView;
	IBOutlet MosaicView					*mosaicView;
	IBOutlet NSBox						*imageSourcesView;
	
		// Views inside the image sources box.
	IBOutlet NSTextField				*keywordTextField;
	IBOutlet NSButton					*addKeywordButton,
										*removeKeywordButton;
	IBOutlet NSTableView				*imageSourcesTableView;
	
		// Model objects
	MacOSaiXMosaic						*currentMosaic;
	NSMutableArray						*mosaics,
										*imageSources;
	
		// Tile refresh management
	BOOL								displayNonUniqueMatches;
	
	NSMutableArray						*mosaicControllers;
}

- (void)setMosaicControllers:(NSArray *)controllers;

- (void)tile;

- (void)setTileCount:(int)count;

- (void)setMessage:(NSAttributedString *)message;
- (void)setMessageBackgroundColor:(NSColor *)color;

- (IBAction)setTargetImage:(id)sender;
- (IBAction)addKeyword:(id)sender;
- (IBAction)removeKeyword:(id)sender;

@end

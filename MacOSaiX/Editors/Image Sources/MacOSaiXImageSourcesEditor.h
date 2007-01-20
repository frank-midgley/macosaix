//
//  MacOSaiXImageSourcesEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"

@class MacOSaiXPopUpButton;
@protocol MacOSaiXImageSource;


@interface MacOSaiXImageSourcesEditor : MacOSaiXEditor
{
	IBOutlet NSTabView				*tabView;
	
		// Image source list tab
	IBOutlet NSTableView			*imageSourcesTable;
	IBOutlet MacOSaiXPopUpButton	*addSourceButton;
	IBOutlet NSButton				*editSourceButton, 
									*removeSourceButton;
	
		// Image source editor tab
	IBOutlet NSTableView			*imageSourceTable;
	IBOutlet NSButton				*showSourcesButton;
	NSBox							*editorBox;
	id<MacOSaiXImageSource>			imageSourceBeingEdited;
	
	NSTimer							*animationTimer;
	
	NSMutableArray					*highlightedImageSources;
	NSLock							*highlightedImageSourcesLock;
	NSBezierPath					*highlightedImageSourcesOutline;
}

- (IBAction)addImageSource:(id)sender;
- (IBAction)editImageSource:(id)sender;
- (IBAction)removeImageSource:(id)sender;

- (IBAction)showImageSources:(id)sender;

@end

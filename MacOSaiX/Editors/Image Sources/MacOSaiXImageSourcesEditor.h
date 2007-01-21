//
//  MacOSaiXImageSourcesEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"

#import "MacOSaiXPlugIn.h"

@class MacOSaiXPopUpButton;
@protocol MacOSaiXImageSource;


@interface MacOSaiXImageSourcesEditor : MacOSaiXEditor <MacOSaiXDataSourceEditorDelegate>
{
	IBOutlet NSTableView			*imageSourcesTable;
	IBOutlet MacOSaiXPopUpButton	*addSourceButton;
	IBOutlet NSButton				*editSourceButton, 
									*removeSourceButton;
	
	NSBox							*editorBox;
	id<MacOSaiXImageSource>			imageSourceBeingEdited;
	id<MacOSaiXDataSourceEditor>	imageSourceEditor;
	
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

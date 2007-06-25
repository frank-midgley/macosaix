//
//  MacOSaiXImageSourcesEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"

#import "MacOSaiXPlugIn.h"

@class MacOSaiXImageSourcesView, MacOSaiXPopUpButton;


@interface MacOSaiXImageSourcesEditor : MacOSaiXMosaicEditor <MacOSaiXEditorDelegate>
{
	IBOutlet NSScrollView				*imageSourcesScrollView;
	
		// Initial view
	IBOutlet NSView						*initialView;
	IBOutlet NSTextField				*labelTextField;
	IBOutlet NSMatrix					*imageSourcesMatrix;
	
		// Editing view
	IBOutlet MacOSaiXImageSourcesView	*imageSourcesView;
	NSMutableArray						*imageSourceViews;
	
		// Auxiliary view
	IBOutlet MacOSaiXPopUpButton		*addSourceButton;
	IBOutlet NSButton					*removeSourceButton;
	
		// Image source highlighting
	NSMutableArray						*highlightedImageSources;
	NSLock								*highlightedImageSourcesLock;
	NSBezierPath						*highlightedImageSourcesOutline;
}

- (IBAction)addImageSource:(id)sender;
- (IBAction)removeImageSource:(id)sender;

- (void)imageSourcesSelectionDidChange;

@end

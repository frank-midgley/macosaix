//
//  MacOSaiXEditorsView.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"

@class MosaicView;


@interface MacOSaiXEditorsView : NSView <MacOSaiXMosaicEditorDelegate>
{
	MosaicView				*mosaicView;
	
	NSMutableArray			*editors, 
							*editorButtons;
	
	MacOSaiXMosaicEditor	*activeEditor;
	
	NSPopUpButton			*additionalEditorsPopUp;
}

- (void)setMosaicView:(MosaicView *)view;

- (void)updateMinimumViewSize;

- (void)setEditorClass:(Class)editorClass isVisible:(BOOL)isVisible;

- (BOOL)setActiveEditorClass:(Class)editorClass;
- (Class)activeEditorClass;

@end

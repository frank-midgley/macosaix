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
}

- (void)setMosaicView:(MosaicView *)view;

- (void)updateMinimumViewSize;

- (void)addEditor:(MacOSaiXMosaicEditor *)editor;

- (NSArray *)editors;

@end

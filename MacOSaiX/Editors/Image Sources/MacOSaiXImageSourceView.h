//
//  MacOSaiXImageSourceView.h
//  MacOSaiX
//
//  Created by Frank Midgley on 4/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXImageSourceEnumerator, MacOSaiXImageSourcesEditor;
@protocol MacOSaiXDataSourceEditor, MacOSaiXEditorDelegate;


@interface MacOSaiXImageSourceView : NSView <MacOSaiXEditorDelegate>
{
	MacOSaiXImageSourcesEditor		*imageSourcesEditor;
	NSButton						*disclosureButton;
	NSBox							*editorBox;
	NSSize							boxBorderSize;
	BOOL							selected;
	MacOSaiXImageSourceEnumerator	*imageSourceEnumerator;
	id<MacOSaiXDataSourceEditor>	imageSourceEditor;
}

- (void)setEditor:(MacOSaiXImageSourcesEditor *)editor;

- (void)setImageSourceEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator;
- (MacOSaiXImageSourceEnumerator *)imageSourceEnumerator;

- (void)setSelected:(BOOL)flag;
- (BOOL)selected;

- (void)setEditorVisible:(BOOL)flag;
- (BOOL)editorVisible;

- (NSSize)minimumEditorSize;

@end

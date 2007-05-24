//
//  MacOSaiXImageSourceView.h
//  MacOSaiX
//
//  Created by Frank Midgley on 4/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXImageSourcesEditor;
@protocol MacOSaiXDataSourceEditor, MacOSaiXEditorDelegate, MacOSaiXImageSource;

@interface MacOSaiXImageSourceView : NSView <MacOSaiXEditorDelegate>
{
	MacOSaiXImageSourcesEditor		*imageSourcesEditor;
	NSButton						*disclosureButton;
	NSBox							*editorBox;
	NSSize							boxBorderSize;
	BOOL							selected;
	id<MacOSaiXImageSource>			imageSource;
	id<MacOSaiXDataSourceEditor>	imageSourceEditor;
}

- (void)setEditor:(MacOSaiXImageSourcesEditor *)editor;

- (void)setImageSource:(id<MacOSaiXImageSource>)source;
- (id<MacOSaiXImageSource>)imageSource;

- (void)setSelected:(BOOL)flag;
- (BOOL)selected;

- (void)setEditorVisible:(BOOL)flag;
- (BOOL)editorVisible;

- (NSSize)minimumEditorSize;

@end

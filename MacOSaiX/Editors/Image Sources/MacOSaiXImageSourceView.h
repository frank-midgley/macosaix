//
//  MacOSaiXImageSourceView.h
//  MacOSaiX
//
//  Created by Frank Midgley on 4/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@protocol MacOSaiXDataSourceEditor, MacOSaiXDataSourceEditorDelegate, MacOSaiXImageSource;

@interface MacOSaiXImageSourceView : NSView <MacOSaiXDataSourceEditorDelegate>
{
	NSButton						*disclosureButton;
	NSBox							*editorBox;
	NSSize							boxBorderSize;
	BOOL							selected;
	id<MacOSaiXImageSource>			imageSource;
	id<MacOSaiXDataSourceEditor>	imageSourceEditor;
}

- (void)setImageSource:(id<MacOSaiXImageSource>)source;
- (id<MacOSaiXImageSource>)imageSource;

- (void)setSelected:(BOOL)flag;
- (BOOL)selected;

- (void)setEditorVisible:(BOOL)flag;
- (BOOL)editorVisible;

@end

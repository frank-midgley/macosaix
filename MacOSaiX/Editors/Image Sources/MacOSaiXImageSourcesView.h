//
//  MacOSaiXImageSourcesView.h
//  MacOSaiX
//
//  Created by Frank Midgley on 4/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


@class MacOSaiXImageSourcesEditor, MacOSaiXImageSourceView, MacOSaiXMosaic;
@protocol MacOSaiXImageSource;


@interface MacOSaiXImageSourcesView : NSView
{
	MacOSaiXImageSourcesEditor *imageSourcesEditor;
	MacOSaiXMosaic				*mosaic;
	NSMutableArray				*imageSourceViews;
}

- (void)setImageSourcesEditor:(MacOSaiXImageSourcesEditor *)editor;
- (MacOSaiXImageSourcesEditor *)imageSourcesEditor;

- (void)setMosaic:(MacOSaiXMosaic *)mosaic;
- (MacOSaiXMosaic *)mosaic;

- (MacOSaiXImageSourceView *)viewForImageSource:(id<MacOSaiXImageSource>)imageSource;

- (void)updateImageSourceViews;

- (void)tile;

- (NSArray *)viewsWithVisibleEditors;
- (NSArray *)selectedImageSourceEnumerators;

@end

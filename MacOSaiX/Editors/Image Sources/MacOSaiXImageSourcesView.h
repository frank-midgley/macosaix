//
//  MacOSaiXImageSourcesView.h
//  MacOSaiX
//
//  Created by Frank Midgley on 4/25/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


@class MacOSaiXMosaic, MacOSaiXImageSourceView;
@protocol MacOSaiXImageSource;


@interface MacOSaiXImageSourcesView : NSView
{
	MacOSaiXMosaic	*mosaic;
	NSMutableArray	*imageSourceViews;
}

- (void)setMosaic:(MacOSaiXMosaic *)mosaic;
- (MacOSaiXMosaic *)mosaic;

- (MacOSaiXImageSourceView *)viewForImageSource:(id<MacOSaiXImageSource>)imageSource;

- (void)updateImageSourceViews;

@end

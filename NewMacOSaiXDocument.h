//
//  NewMacOSaiXDocument.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Feb 21 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface NewMacOSaiXDocument : NSWindowController
{
    IBOutlet id		previewView;
    IBOutlet id		tileShapesPopup;
    IBOutlet id		tilesAcrossView, tilesAcrossStepper;
    IBOutlet id		tilesDownView, tilesDownStepper;
    IBOutlet id		tilesTotal;
    IBOutlet id		imageSourcesView;
    IBOutlet id		removeImageSourceButton;
    IBOutlet id		cropLimit;
    IBOutlet id		goButton;
    NSImage		*_originalImage, *_previewImage;
    BOOL		_userCancelled;
    NSMutableArray	*_tileOutlines, *_imageSources;
    int			_tilesWide, _tilesHigh;
}

- (void)chooseOriginalImage:(id)sender;
- (void)setTileShapes:(id)sender;
- (void)setTilesAcross:(id)sender;
- (void)setTilesDown:(id)sender;
- (void)addImageSource:(id)sender;
- (void)removeImageSource:(id)sender;
- (void)setCropLimit:(id)sender;
- (void)userCancelled:(id)sender;
- (void)beginMacOSaiX:(id)sender;

// private methods
- (void)createTileOutlines;
- (void)createRectangleTiles;
- (void)createHexagonalTiles;
- (void)updatePreview;

@end

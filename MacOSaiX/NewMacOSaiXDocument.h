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
    IBOutlet id		googleTermPanel, googleTermField;
    NSURL		*_originalImageURL;
    NSImage		*_originalImage, *_previewImage;
    BOOL		_userCancelled;
    NSMutableArray	*_tileOutlines, *_imageSources;
    NSString		*_tileShapes;
    int			_tilesWide, _tilesHigh;
}

- (void)chooseOriginalImage:(id)sender;
- (void)chooseOriginalImageOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context;
- (void)setTileShapes:(id)sender;
- (void)setTilesAcross:(id)sender;
- (void)setTilesDown:(id)sender;
- (void)addDirectoryImageSource:(id)sender;
- (void)addDirectoryImageSourceOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context;
- (void)addGoogleImageSource:(id)sender;
- (void)cancelAddGoogleImageSource:(id)sender;
- (void)okAddGoogleImageSource:(id)sender;
- (void)addGlyphImageSource:(id)sender;
- (void)removeImageSource:(id)sender;
- (void)setCropLimit:(id)sender;
- (void)userCancelled:(id)sender;
- (void)beginMacOSaiX:(id)sender;

- (void)createTileOutlines;
- (void)createRectangleTiles;
- (void)createPuzzleTiles;
- (void)createHexagonalTiles;
- (void)updatePreview;

@end

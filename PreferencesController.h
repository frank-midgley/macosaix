//
//  PreferencesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface PreferencesController : NSWindowController
{
    IBOutlet id		autosaveFrequencyField;
    IBOutlet id		tileShapesPopup;
    IBOutlet id		tilesAcrossView, tilesAcrossStepper;
    IBOutlet id		tilesDownView, tilesDownStepper;
    IBOutlet id		tilesTotal;
    IBOutlet id		imageSourcesView;
    IBOutlet id		removeImageSourceButton;
    IBOutlet id		cropLimit;
    IBOutlet id		okButton;
    IBOutlet id		googleTermPanel, googleTermField;
    BOOL		_userCancelled;
    NSMutableArray	*_imageSources;
    NSString		*_tileShapes;
    int			_tilesWide, _tilesHigh;
}

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
- (void)savePreferences:(id)sender;

@end

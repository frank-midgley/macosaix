//
//  PreferencesController.h
//  MacOSaiX.app
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface PreferencesController : NSWindowController
{
    IBOutlet id		autosaveFrequencyField;
    IBOutlet id		tileShapesPopup;
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

//- (void)setTileShapes:(id)sender;
//- (void)removeImageSource:(id)sender;
- (void)setCropLimit:(id)sender;
- (void)userCancelled:(id)sender;
- (void)savePreferences:(id)sender;

@end

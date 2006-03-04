//
//  MacOSaiXTilesShapes.h
//  MacOSaiX
//
//  Created by Frank Midgley on Nov 28 2004.
//  Copyright (c) 2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kMacOSaiXTileShapesSettingType @"Element Type"


@protocol MacOSaiXTileShapes <NSObject, NSCopying>

	// A generic image for this type of tile shapes.
	// This image is used for display in the preferences window (32x32), the tiles setup pop-up menu (16x16) 
	// and the crash reporter window (16x16).
+ (NSImage *)image;

	// A class whose instances conform to the MacOSaiXTileShapesEditor protocol.
+ (Class)editorClass;

	// A class whose instances conform to the MacOSaiXTileShapesPreferencesController protocol.
+ (Class)preferencesControllerClass;

	// An image appropriate for this instance of the tile shapes.
	// This image is used for the "Tiles Setup" toolbar icon (32x32).
- (NSImage *)image;

	// A human-readable NSString, NSAttributedString or NSImage that briefly describes this instance's settings.
- (id)briefDescription;

	// Methods for adding settings to a saved file.
- (NSString *)settingsAsXMLElement;

	// Methods called when loading settings from a saved mosaic.
- (void)useSavedSetting:(NSDictionary *)settingDict;
- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict;
- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict;

- (NSArray *)shapes;

@end


@protocol MacOSaiXTileShapesEditor <NSObject>

- (id)initWithDelegate:(id)delegate;

	// The view containing the editing controls.
- (NSView *)editorView;

	// The minimum size of the editor view.
- (NSSize)minimumSize;

	// The first responder of the editor view.
- (NSResponder *)firstResponder;

- (void)editTileShapes:(id<MacOSaiXTileShapes>)tilesSetup;
- (void)editingComplete;

- (int)tileCount;
- (NSBezierPath *)previewPath;

@end

@interface NSObject (MacOSaiXTileShapesEditorDelegate)
- (NSImage *)originalImage;
- (void)tileShapesWereEdited;
@end

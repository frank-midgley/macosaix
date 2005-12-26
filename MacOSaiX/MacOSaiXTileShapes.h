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

	// Name to display in pop-up menu
+ (NSString *)name;

	// A class whose instances conform to the MacOSaiXTileShapesEditor protocol.
+ (Class)editorClass;

	// A class whose instances conform to the MacOSaiXTileShapesPreferencesController protocol.
+ (Class)preferencesControllerClass;

// TBD: initWithXML or parser callbacks?

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
- (NSSize)editorViewMinimumSize;
- (NSResponder *)editorViewFirstResponder;

- (void)editTileShapes:(id<MacOSaiXTileShapes>)tilesSetup;
- (void)editingComplete;

- (int)tileCount;
- (NSBezierPath *)previewPath;

@end

@interface NSObject (MacOSaiXTileShapesEditorDelegate)
- (NSImage *)originalImage;
- (void)tileShapesWereEdited;
@end


@protocol MacOSaiXTileShapesPreferencesController <NSObject>

	// The view containing the preferences controls.
- (NSView *)preferencesView;

@end

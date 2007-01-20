/*
 *  MacOSaiXPlugIn.h
 *  MacOSaiX
 *
 *  Created by Frank Midgley on 1/4/07.
 *  Copyright 2007 Frank M. Midgley. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>


@protocol MacOSaiXPlugIn <NSObject>

	// This method should return a generic image for the plug-in.  This image is used for display in the preferences window (32x32), various pop-up menus (16x16) and the crash reporter window (16x16).
+ (NSImage *)image;

	// This method should return a class that conforms to the MacOSaiXDataSource protocol.
+ (Class)dataSourceClass;

	// This method should return a class that conforms to the MacOSaiXDataSourceEditor protocol.
+ (Class)dataSourceEditorClass;

	// This method can return a class that conforms to the MacOSaiXPlugInPreferencesEditor protocol.  Return nil if there are no editable preferences for this plug-in.
+ (Class)preferencesEditorClass;

@end


@protocol MacOSaiXDataSource <NSObject, NSCopying>

	// This method should return an image appropriate for this instance of the tile shapes.  This image is used for the "Tiles Setup" toolbar icon (32x32).
- (NSImage *)image;

	// This method should return a human-readable string or attributed string that briefly describes this instance's settings.
- (id)briefDescription;

	// Methods called to save and load settings.
- (BOOL)saveSettingsToFileAtPath:(NSString *)path;
- (BOOL)loadSettingsFromFileAtPath:(NSString *)path;

@end


@protocol MacOSaiXDataSourceEditorDelegate

	// This method returns the target image being used for the current mosaic.
- (NSImage *)targetImage;

	// Call this method when the settings have been changed by the user.  The change description will be used as part of the Undo item in the Edit menu, e.g. "Undo Change Tiles Across".
- (void)plugInSettingsDidChange:(NSString *)changeDescription;

@end


@protocol MacOSaiXDataSourceEditor <NSObject>

- (id)initWithDelegate:(id<MacOSaiXDataSourceEditorDelegate>)delegate;

- (id<MacOSaiXDataSourceEditorDelegate>)delegate;

	// The view containing the editing controls.
- (NSView *)editorView;

	// These methods should return the minimum and maximum sizes of the editor view.  If no limit is desired then return NSZeroSize from either method.
- (NSSize)minimumSize;
- (NSSize)maximumSize;

	// The first responder of the editor view.
- (NSResponder *)firstResponder;

- (void)editDataSource:(id<MacOSaiXDataSource>)dataSource;

- (void)editingDidComplete;

@end


@protocol MacOSaiXPlugInPreferencesEditor <NSObject>

	// The view containing the preference controls.
- (NSView *)editorView;

	// The minimum size of the main view.
- (NSSize)minimumSize;

	// The first control in the key view loop of the main view.
- (NSResponder *)firstResponder;

	// These messages get sent to a preference pane just before and just after it becomes the currently selected preference pane.
- (void)willSelect;
- (void)didSelect;

	// The willUnselect message gets sent to the currently selected preference pane just before and just after it gets swapped out for another preference pane.
- (void)willUnselect;
- (void)didUnselect;

@end

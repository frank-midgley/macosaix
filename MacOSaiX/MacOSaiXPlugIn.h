/*
 *  MacOSaiXPlugIn.h
 *  MacOSaiX
 *
 *  Created by Frank Midgley on 1/4/07.
 *  Copyright 2007 Frank M. Midgley. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>


@protocol MacOSaiXDataSource;


@protocol MacOSaiXPlugIn <NSObject>

	// This method should return a generic image for the plug-in.  This image is used for display in the preferences window (32x32), various pop-up menus (16x16) and the crash reporter window (16x16).
+ (NSImage *)image;

	// This method should return a class that conforms to the MacOSaiXDataSource protocol.
+ (Class)dataSourceClass;

	// This method should return a class that conforms to the MacOSaiXEditor protocol.
+ (Class)editorClass;

	// This method can return a class that conforms to the MacOSaiXPlugInPreferencesEditor protocol.  Return nil if there are no editable preferences for this plug-in.
+ (Class)preferencesEditorClass;

@end


@protocol MacOSaiXEditorDelegate

	// An editor can call this method to get the target image being used for the current mosaic.
- (NSImage *)targetImage;

	// Call this method when a data source being displayed in an editor has been changed by the user.  The change description may be used as part of the Undo item in the Edit menu, e.g. "Undo Change Tiles Across".
- (void)dataSource:(id<MacOSaiXDataSource>)dataSource settingsDidChange:(NSString *)changeDescription;

@end


@protocol MacOSaiXEditor <NSObject>

- (id)initWithDelegate:(id<MacOSaiXEditorDelegate>)delegate;

- (id<MacOSaiXEditorDelegate>)delegate;

	// The view containing the editing controls.
- (NSView *)editorView;

	// These methods should return the minimum and maximum sizes of the editor view.  If no limit is desired then return NSZeroSize from either method.
- (NSSize)minimumSize;
- (NSSize)maximumSize;

	// The first responder of the editor view.
- (NSResponder *)firstResponder;

@end


@protocol MacOSaiXDataSource <NSObject, NSCopying>

	// This method should return an image appropriate for this instance of the data source.
- (NSImage *)image;

	// This method should return a human-readable string or attributed string that briefly describes this instance's settings.
- (id)briefDescription;

	// Methods called to save and load settings.
- (BOOL)saveSettingsToFileAtPath:(NSString *)path;
- (BOOL)loadSettingsFromFileAtPath:(NSString *)path;

@end


@protocol MacOSaiXDataSourceEditor <MacOSaiXEditor>

- (void)editDataSource:(id<MacOSaiXDataSource>)dataSource;

- (void)editingDidComplete;

@end


@protocol MacOSaiXPlugInPreferencesEditor <MacOSaiXEditor>

	// These messages get sent to a preference pane just before and just after it becomes the currently selected preference pane.
- (void)willSelect;
- (void)didSelect;

	// These messages get sent to the currently selected preference pane just before and just after it gets swapped out for another preference pane.
- (void)willUnselect;
- (void)didUnselect;

@end

//
//  MacOSaiXTilesShapes.h
//  MacOSaiX
//
//  Created by Frank Midgley on Nov 28 2004.
//  Copyright (c) 2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

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

- (NSString *)settingsAsXMLElement;

- (NSArray *)shapes;

@end


@protocol MacOSaiXTileShapesEditor <NSObject>

	// The view containing the editing controls.
- (NSView *)editorView;

- (void)editTileShapes:(id<MacOSaiXTileShapes>)tilesSetup forOriginalImage:(NSImage *)originalImage;

@end


@protocol MacOSaiXTileShapesPreferencesController <NSObject>

	// The view containing the preferences controls.
- (NSView *)preferencesView;

@end

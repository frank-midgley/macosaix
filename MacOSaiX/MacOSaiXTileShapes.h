//
//  MacOSaiXTilesShapes.h
//  MacOSaiX
//
//  Created by Frank Midgley on Nov 28 2004.
//  Copyright (c) 2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol MacOSaiXTileShapes <NSObject, NSCopying>

// TBD: initWithXML, saveXML?

	// Name to display in pop-up menu
+ (NSString *)name;

+ (Class)editorClass;

+ (Class)preferencesControllerClass;

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

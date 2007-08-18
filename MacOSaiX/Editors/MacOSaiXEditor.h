//
//  MacOSaiXEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MosaicView.h"

@class MacOSaiXMosaic;
@protocol MacOSaiXDataSource, MacOSaiXDataSourceEditor, MacOSaiXEditorDelegate, MacOSaiXMosaicEditorDelegate;


@interface MacOSaiXMosaicEditor : NSObject <MacOSaiXEditorDelegate>
{
	IBOutlet NSView						*editorView, 
										*auxiliaryView;
	IBOutlet NSPopUpButton				*plugInPopUpButton;
	IBOutlet NSBox						*plugInEditorBox;
	IBOutlet NSView						*plugInEditorPreviousKeyView, 
										*plugInEditorNextKeyView;
	
	id<MacOSaiXMosaicEditorDelegate>	editorDelegate;
	
	id<MacOSaiXDataSourceEditor>		plugInEditor;
	
	BOOL								isActive;
}

+ (NSArray *)editorClasses;

+ (NSImage *)image;

+ (NSString *)title;

+ (BOOL)isAdditional;

+ (BOOL)descriptionHasBeenShown;

+ (void)showDescriptionNearPoint:(NSPoint)descriptionPoint;

- (id)initWithDelegate:(id<MacOSaiXMosaicEditorDelegate>)delegate;
- (id<MacOSaiXMosaicEditorDelegate>)delegate;

- (NSString *)editorNibName;

- (NSView *)view;

- (void)updateMinimumViewSize;
- (NSSize)minimumViewSize;

- (NSView *)auxiliaryView;

- (NSArray *)plugInClasses;
- (NSString *)plugInTitleFormat;

- (void)setMosaicDataSource:(id<MacOSaiXDataSource>)dataSource;
- (id<MacOSaiXDataSource>)mosaicDataSource;

- (void)setDataSource:(id<MacOSaiXDataSource>)dataSource value:(id)value forKey:(NSString *)key;

- (IBAction)setPlugInClass:(id)sender;

- (id<MacOSaiXDataSourceEditor>)plugInEditor;

- (NSNumber *)targetImageOpacity;

- (void)beginEditing;

- (void)embellishMosaicView:(MosaicView *)mosaicView inRect:(NSRect)rect;

- (void)handleEvent:(NSEvent *)event inMosaicView:(MosaicView *)mosaicView;

- (void)selectAllInMosaicView:(MosaicView *)mosaicView;

- (BOOL)endEditing;

- (BOOL)isActive;

@end


@protocol MacOSaiXMosaicEditorDelegate

- (MacOSaiXMosaic *)mosaic;

- (BOOL)setActiveEditor:(MacOSaiXMosaicEditor *)editor;
- (MacOSaiXMosaicEditor *)activeEditor;

- (BOOL)makeFirstResponder:(NSResponder *)responder;

- (void)embellishmentNeedsDisplay;

@end

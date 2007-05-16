//
//  MacOSaiXEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MosaicView.h"
#import "MacOSaiXPlugIn.h"


@interface MacOSaiXEditor : NSObject <MacOSaiXEditorDelegate>
{
	IBOutlet NSView					*editorView, 
									*auxiliaryView;
	IBOutlet NSPopUpButton			*plugInPopUpButton;
	IBOutlet NSBox					*plugInEditorBox;
	IBOutlet NSView					*plugInEditorPreviousKeyView, 
									*plugInEditorNextKeyView;
	
	MosaicView						*mosaicView;
	
	id<MacOSaiXDataSourceEditor>	plugInEditor;
}

+ (NSImage *)image;

- (id)initWithMosaicView:(MosaicView *)mosaicView;
- (MosaicView *)mosaicView;

- (NSString *)title;

- (NSString *)editorNibName;

- (NSView *)view;

- (void)updateMinimumViewSize;
- (NSSize)minimumViewSize;

- (NSView *)auxiliaryView;

- (NSArray *)plugInClasses;
- (NSString *)plugInTitleFormat;

- (void)setMosaicDataSource:(id<MacOSaiXDataSource>)dataSource;
- (id<MacOSaiXDataSource>)mosaicDataSource;

- (IBAction)setPlugInClass:(id)sender;

- (void)beginEditing;

- (void)embellishMosaicViewInRect:(NSRect)rect;

- (void)handleEventInMosaicView:(NSEvent *)event;

- (void)endEditing;

@end

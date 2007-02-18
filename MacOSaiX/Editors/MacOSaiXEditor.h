//
//  MacOSaiXEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MosaicView.h"


@interface MacOSaiXEditor : NSObject
{
	IBOutlet NSView	*editorView;
	
	MosaicView		*mosaicView;
}

+ (NSImage *)image;

- (id)initWithMosaicView:(MosaicView *)mosaicView;
- (MosaicView *)mosaicView;

- (NSString *)title;

- (NSString *)editorNibName;

- (NSView *)view;

- (void)beginEditing;

- (void)embellishMosaicViewInRect:(NSRect)rect;

- (void)handleEventInMosaicView:(NSEvent *)event;

- (void)endEditing;

@end

//
//  MacOSaiXEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"


@implementation MacOSaiXEditor


- (id)initWithMosaicView:(MosaicView *)inMosaicView
{
	if (self = [super init])
	{
		mosaicView = inMosaicView;
	}
	
	return self;
}


- (MosaicView *)mosaicView
{
	return mosaicView;
}


- (NSImage *)image
{
	NSImage	*image = [[[NSImage alloc] initWithSize:NSMakeSize(24.0, 16.0)] autorelease];
	
	[image lockFocus];
		[[NSColor blackColor] set];
		NSFrameRect(NSMakeRect(0.0, 0.0, 24.0, 16.0));
	[image unlockFocus];
	
	return image;
}


- (NSString *)title
{
	return @"";
}


- (NSString *)editorNibName
{
	return nil;
}


- (NSView *)view
{
	if (!editorView)
		[NSBundle loadNibNamed:[self editorNibName] owner:self];
	
	return editorView;
}


- (void)beginEditing
{
}


- (void)embellishMosaicViewInRect:(NSRect)rect
{
}


- (void)handleEventInMosaicView:(NSEvent *)event
{
}


- (void)endEditing
{
}


- (void)dealloc
{
	mosaicView = nil;
	
	[super dealloc];
}


@end

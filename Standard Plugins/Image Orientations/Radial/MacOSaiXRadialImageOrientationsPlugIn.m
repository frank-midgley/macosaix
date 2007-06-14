//
//  MacOSaiXRadialImageOrientationsPlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/13/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXRadialImageOrientationsPlugIn.h"

#import "MacOSaiXRadialImageOrientations.h"
#import "MacOSaiXRadialImageOrientationsEditor.h"


@implementation MacOSaiXRadialImageOrientationsPlugIn


+ (NSImage *)image
{
	static	NSImage	*image = nil;
	
	if (!image)
	{
		NSRect	rect = NSMakeRect(0.0, 4.0, 31.0, 23.0);
		
		image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
		[image lockFocus];
		[[NSColor lightGrayColor] set];
		NSFrameRect(NSOffsetRect(rect, 1.0, -1.0));
		[[NSColor whiteColor] set];
		NSRectFill(rect);
		[[NSColor blackColor] set];
		NSFrameRect(rect);
		[image unlockFocus];
	}
	
	return image;
}


+ (Class)dataSourceClass
{
	return [MacOSaiXRadialImageOrientations class];
}


+ (Class)editorClass
{
	return [MacOSaiXRadialImageOrientationsEditor class];
}


+ (Class)preferencesEditorClass
{
	return nil;
}


@end

//
//  ConstantImageOrientationsPlugIn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 1/9/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "ConstantImageOrientationsPlugIn.h"

#import "ConstantImageOrientations.h"
#import "ConstantImageOrientationsEditor.h"


@implementation MacOSaiXConstantImageOrientationsPlugIn


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
	return [MacOSaiXConstantImageOrientations class];
}


+ (Class)dataSourceEditorClass
{
	return [MacOSaiXConstantImageOrientationsEditor class];
}


+ (Class)preferencesEditorClass
{
	return nil;
}


@end

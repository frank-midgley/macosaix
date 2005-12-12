//
//  MacOSaiXPopUpImageView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/11/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXPopUpImageView.h"


@implementation MacOSaiXPopUpImageView


- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame])
	{
		
    }
	
    return self;
}


- (void)setImage:(NSImage *)image
{
	[popUpImage autorelease];
	popUpImage = [image retain];
	
	[self setNeedsDisplay:YES];
}


- (NSImage *)image
{
	return popUpImage;
}


- (void)setMenu:(NSMenu *)menu
{
	[popUpMenu autorelease];
	popUpMenu = [menu retain];
}


- (NSMenu *)menu
{
	return popUpMenu;
}


- (void)drawRect:(NSRect)rect
{
		// Draw the image as large as possible and centered.
	NSSize	imageSize = [popUpImage size];
	NSRect	bounds = [self bounds],
			destRect;
	if ((imageSize.width / NSWidth(bounds)) > (imageSize.height / NSHeight(bounds)))
	{
		float	scaledHeight = imageSize.height * NSWidth(bounds) / imageSize.width;
		destRect = NSMakeRect(NSMinX(bounds), (NSHeight(bounds) - scaledHeight) / 2.0, NSWidth(bounds), scaledHeight);
	}
	else
	{
		float	scaledWidth = imageSize.width * NSHeight(bounds) / imageSize.height;
		destRect = NSMakeRect((NSWidth(bounds) - scaledWidth) / 2.0, NSMinY(bounds), scaledWidth, NSHeight(bounds));
	}
	
	if (popUpMenu)
	{
		[[NSGraphicsContext currentContext] saveGraphicsState];
//		[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMaxX(destRect) - 8.0, NSMinY(destRect) - 8.0, 16.0, 16.0)] addClip];
	}
	
	[popUpImage drawInRect:destRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	
	if (popUpMenu)
	{
		[[NSGraphicsContext currentContext] restoreGraphicsState];

		NSBezierPath	*trianglePath = [NSBezierPath bezierPath];
		[trianglePath moveToPoint:NSMakePoint(NSMaxX(destRect) - 6.5, NSMinY(destRect) + 4.5)];
		[trianglePath lineToPoint:NSMakePoint(NSMaxX(destRect) - 0.5, NSMinY(destRect) + 4.5)];
		[trianglePath lineToPoint:NSMakePoint(NSMaxX(destRect) - 3.5, NSMinY(destRect) + 0.5)];
		[trianglePath lineToPoint:NSMakePoint(NSMaxX(destRect) - 6.5, NSMinY(destRect) + 4.5)];
		[[NSColor blackColor] set];
		[trianglePath fill];
	}
}


- (void)mouseDown:(NSEvent *)theEvent
{
	if (popUpMenu)
		[NSMenu popUpContextMenu:popUpMenu withEvent:theEvent forView:self];
}


- (void)dealloc
{
	[popUpImage release];
	[popUpMenu release];
	
	[super dealloc];
}


@end

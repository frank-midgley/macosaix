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


- (BOOL)isOpaque
{
	return NO;
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
	NSRect	bounds = NSInsetRect([self bounds], 6.0, 0.0), 
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
	destRect = NSIntegralRect(destRect);
	
	[popUpImage drawInRect:destRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	
	if (popUpMenu)
	{
		NSBezierPath	*trianglePath = [NSBezierPath bezierPath];
		[trianglePath moveToPoint:NSMakePoint(NSMaxX(destRect) + 1.5, NSMinY(destRect) + 4.0)];
		[trianglePath lineToPoint:NSMakePoint(NSMaxX(destRect) + 6.5, NSMinY(destRect) + 4.0)];
		[trianglePath lineToPoint:NSMakePoint(NSMaxX(destRect) + 4.0, NSMinY(destRect) + 0.0)];
		[trianglePath lineToPoint:NSMakePoint(NSMaxX(destRect) + 1.5, NSMinY(destRect) + 4.0)];
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
	popUpImage = nil;
	[popUpMenu release];
	popUpMenu = nil;
	
	[super dealloc];
}


@end

//
//  MacOSaiXPopUpButton.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/11/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXPopUpButton.h"


@implementation MacOSaiXPopUpButton


- (void)setImage:(NSImage *)image
{
	NSSize	imageSize = [image size], 
			buttonSize = [self bounds].size, 
			scaledImageSize;
	
	if ((imageSize.width / buttonSize.width) > (imageSize.height / buttonSize.height))
		scaledImageSize = NSMakeSize(buttonSize.width, imageSize.height * buttonSize.width / imageSize.width);
	else
		scaledImageSize = NSMakeSize(imageSize.width * buttonSize.height / imageSize.height, buttonSize.height);
	
	NSImage	*scaledImage = [image copy];
	[scaledImage setScalesWhenResized:YES];
	[scaledImage setSize:scaledImageSize];
	[super setImage:scaledImage];
	[scaledImage release];
}


- (void)setIndicatorColor:(NSColor *)color
{
	[indicatorColor autorelease];
	indicatorColor = [color retain];
	
	[self setNeedsDisplay:YES];
}


- (NSColor *)indicatorColor
{
	return (indicatorColor ? indicatorColor : [NSColor blackColor]);
}


- (void)addItemWithTitle:(NSString *)title
{
	if (![self menu])
		[self setMenu:[[[NSMenu alloc] initWithTitle:@""] autorelease]];
	
	NSMenuItem	*newItem = [[NSMenuItem alloc] initWithTitle:title action:[self action] keyEquivalent:@""];
	[newItem setTarget:[self target]];
	[[self menu] addItem:newItem];
	[newItem release];
}


- (NSMenuItem *)lastItem
{
	return ([[self menu] numberOfItems] > 0 ? [[[self menu] itemArray] lastObject] : nil);
}


- (void)removeAllItems
{
	NSMenu	*menu = [self menu];
	
	while ([menu numberOfItems] > 0)
		[menu removeItemAtIndex:0];
}


- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	
	if ([self menu])
	{
		NSRect			bounds = [self bounds];
		NSBezierPath	*trianglePath = [NSBezierPath bezierPath];
		[trianglePath moveToPoint:NSMakePoint(NSMaxX(bounds) - 7.0, NSMaxY(bounds) - 6.0)];
		[trianglePath lineToPoint:NSMakePoint(NSMaxX(bounds) - 2.0, NSMaxY(bounds) - 6.0)];
		[trianglePath lineToPoint:NSMakePoint(NSMaxX(bounds) - 4.5, NSMaxY(bounds) - 2.0)];
		[trianglePath lineToPoint:NSMakePoint(NSMaxX(bounds) - 7.0, NSMaxY(bounds) - 6.0)];
		[trianglePath setLineWidth:1.5];
		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
		[trianglePath stroke];
		[trianglePath setLineWidth:1.0];
		[[self indicatorColor] set];
		[trianglePath fill];
	}
}


- (void)mouseDown:(NSEvent *)theEvent
{
	if ([self menu])
		[NSMenu popUpContextMenu:[self menu] withEvent:theEvent forView:self];
	else
		[super mouseDown:theEvent];
}


//- (void)dealloc
//{
//	[popUpImage release];
//	[popUpMenu release];
//	
//	[super dealloc];
//}


@end

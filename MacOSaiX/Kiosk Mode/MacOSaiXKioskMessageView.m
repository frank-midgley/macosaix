//
//  MacOSaiXKioskMessageView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/30/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXKioskMessageView.h"


@implementation MacOSaiXKioskMessageView

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame])
	{
        textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0.0, 0.0, NSWidth(frame), NSHeight(frame))];
		[textView setDrawsBackground:NO];
		[textView setDelegate:self];
		[textView setEditable:YES];
		[textView setImportsGraphics:YES];
		[textView alignCenter:self];
		[textView setHorizontallyResizable:YES];
		[textView setMinSize:NSMakeSize(16.0, 16.0)];
		[self addSubview:textView];
		
		[self setBackgroundColor:[[NSColor yellowColor] highlightWithLevel:0.75]];
		[self textDidChange:nil];
    }
	
    return self;
}


- (void)setEditable:(BOOL)flag
{
	[textView setEditable:flag];
	[textView setSelectable:flag];
}


- (BOOL)isEditable
{
	return [textView isEditable];
}


- (void)setBackgroundColor:(NSColor *)color
{
	[backgroundColor release];
	backgroundColor = [color retain];
	
	[self setNeedsDisplay:YES];
}


- (NSColor *)backgroundColor
{
	return backgroundColor;
}


- (void)textDidChange:(NSNotification *)notification
{
	if ([[textView string] length] == 0)
		[textView setString:NSLocalizedString(@"Sample Message", @"")];
	
	[textView setFrameSize:NSMakeSize(256.0, 256.0)];
	[textView sizeToFit];
	[textView setFrameOrigin:NSMakePoint((NSWidth([self frame]) - NSWidth([textView frame])) / 2.0,
									     (NSHeight([self frame]) - NSHeight([textView frame])) / 2.0)];
	
	[self setNeedsDisplay:YES];
}


- (void)setMessage:(NSAttributedString *)message
{
	[[textView textStorage] setAttributedString:message];
	
	[self textDidChange:nil];
}


- (NSAttributedString *)message
{
	return [[[NSAttributedString alloc] initWithAttributedString:[textView textStorage]] autorelease];
}


- (void)drawRect:(NSRect)rect
{
    [[NSColor blackColor] set];
	NSRectFill(rect);
	
	NSRect			frame = NSInsetRect([textView frame], -3.0, -3.0);
	NSBezierPath	*backgroundPath = [NSBezierPath bezierPath];
	[backgroundPath moveToPoint:NSMakePoint(NSMaxX(frame) - 8.0, NSMinY(frame))];
	[backgroundPath curveToPoint:NSMakePoint(NSMaxX(frame), NSMinY(frame) + 8.0) 
				   controlPoint1:NSMakePoint(NSMaxX(frame), NSMinY(frame)) 
				   controlPoint2:NSMakePoint(NSMaxX(frame), NSMinY(frame))];
	[backgroundPath lineToPoint:NSMakePoint(NSMaxX(frame), NSMaxY(frame) - 8.0)];
	[backgroundPath curveToPoint:NSMakePoint(NSMaxX(frame) - 8.0, NSMaxY(frame)) 
				   controlPoint1:NSMakePoint(NSMaxX(frame), NSMaxY(frame)) 
				   controlPoint2:NSMakePoint(NSMaxX(frame), NSMaxY(frame))];
	[backgroundPath lineToPoint:NSMakePoint(NSMinX(frame) + 8.0, NSMaxY(frame))];
	[backgroundPath curveToPoint:NSMakePoint(NSMinX(frame), NSMaxY(frame) - 8.0) 
				   controlPoint1:NSMakePoint(NSMinX(frame), NSMaxY(frame)) 
				   controlPoint2:NSMakePoint(NSMinX(frame), NSMaxY(frame))];
	[backgroundPath lineToPoint:NSMakePoint(NSMinX(frame), NSMinY(frame) + 8.0)];
	[backgroundPath curveToPoint:NSMakePoint(NSMinX(frame) + 8.0, NSMinY(frame)) 
				   controlPoint1:NSMakePoint(NSMinX(frame), NSMinY(frame)) 
				   controlPoint2:NSMakePoint(NSMinX(frame), NSMinY(frame))];
	[backgroundPath closePath];
	
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:2.0 yBy:-2.0];
	
	[[backgroundColor shadowWithLevel:0.5] set];
	[backgroundPath transformUsingAffineTransform:transform];
	[backgroundPath fill];
	
	[backgroundColor set];
	[transform invert];
	[backgroundPath transformUsingAffineTransform:transform];
	[backgroundPath fill];
	
	[super drawRect:rect];
}


- (void)dealloc
{
	[textView release];
	
	[super dealloc];
}

@end

//
//  OriginalView.m
//  MacOSaiX
//
//  Created by Frank Midgley on Fri Mar 22 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "OriginalView.h"


@implementation OriginalView

- (id)init
{
    [super init];
    _focusRect = NSMakeRect(0, 0, 0, 0);
    _displayTileOutlines = NO;
    _tileOutlines = nil;
    return self;
}


- (void)setTileOutlines:(NSBezierPath *)tileOutlines
{
    [_tileOutlines autorelease];
    _tileOutlines = [tileOutlines retain];
}


- (void)setDisplayTileOutlines:(BOOL)displayTileOutlines;
{
    if (_displayTileOutlines != displayTileOutlines)
	[self setNeedsDisplay:YES];
    _displayTileOutlines = displayTileOutlines;
}


- (void)setFocusRect:(NSRect)focusRect;
{
    _focusRect = focusRect;
}


- (void)drawRect:(NSRect)theRect
{
    NSAffineTransform	*transform;
    NSBezierPath 	*bezierPath;
    
    [[self image] drawInRect:[self bounds] fromRect:NSMakeRect(0, 0, [[self image] size].width,
							       [[self image] size].height)
		   operation:NSCompositeCopy fraction:1.0];

    if (_displayTileOutlines)
    {
	transform = [NSAffineTransform transform];
	[transform translateXBy:0.5 yBy:-0.5];
	[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
	[[NSColor colorWithCalibratedWhite:0.0 alpha: 0.5] set];	// darken
	[[transform transformBezierPath:_tileOutlines] stroke];

	transform = [NSAffineTransform transform];
	[transform translateXBy:-0.5 yBy:0.5];
	[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
	[[NSColor colorWithCalibratedWhite:1.0 alpha: 0.5] set];	// lighten
	[[transform transformBezierPath:_tileOutlines] stroke];
    }

    // lighten the parts of the original image not currently showing in the mosaic
    bezierPath = [NSBezierPath bezierPath];
    [bezierPath moveToPoint:NSMakePoint(0, 0)];
    [bezierPath lineToPoint:NSMakePoint(0, [self frame].size.height)];
    [bezierPath lineToPoint:NSMakePoint([self frame].size.width, [self frame].size.height)];
    [bezierPath lineToPoint:NSMakePoint([self frame].size.width, 0)];
    [bezierPath closePath];
    [bezierPath appendBezierPath:[NSBezierPath bezierPathWithRect:_focusRect]];
    [[NSColor colorWithCalibratedWhite:1.0 alpha: 0.5] set];	// lighten
    [bezierPath fill];
}


- (void)dealloc
{
    [super dealloc];
    [_tileOutlines release];
}

@end

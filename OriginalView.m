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
    return self;
}


- (void)setDisplayTileOutlines:(BOOL)displayTileOutlines;
{
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
    int			i;
    
    // draw the tile outlines
/*    [NSBezierPath setDefaultLineWidth:1.0];
    transform = [NSAffineTransform transform];
    [transform translateXBy:0.5 yBy:0.5];
    [transform scaleXBy:[[self bounds] size].width yBy:[[self bounds] size].height];
    [[NSColor colorWithCalibratedWhite:1.0 alpha: 0.5] set];
    for (i = 0; i < [_tileOutlines count]; i++)
    	[[transform transformBezierPath:[_tileOutlines objectAtIndex:i]] stroke];*/

    // dim the parts of the original image not currently showing in the mosaic
    [[self image] drawInRect:theRect fromRect:NSMakeRect(0, 0, [[self image] size].width,
							 [[self image] size].height)
		   operation:NSCompositeCopy fraction:1.0];
    [[NSColor colorWithCalibratedWhite:1.0 alpha: 0.5] set];
//    [[NSColor blackColor] set];
//    NSRectFillUsingOperation(_focusRect, NSCompositeSourceAtop);
    bezierPath = [NSBezierPath bezierPath];
    [bezierPath moveToPoint:NSMakePoint(0, 0)];
    [bezierPath lineToPoint:NSMakePoint(0, [self frame].size.height)];
    [bezierPath lineToPoint:NSMakePoint([self frame].size.width, [self frame].size.height)];
    [bezierPath lineToPoint:NSMakePoint([self frame].size.width, 0)];
    [bezierPath closePath];
//    [bezierPath setWindingRule:];
    [bezierPath appendBezierPath:[NSBezierPath bezierPathWithRect:_focusRect]];
    [bezierPath fill];
}

@end

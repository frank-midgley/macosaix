//
//  MacOSaiXKioskView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/11/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXKioskView.h"


@implementation MacOSaiXKioskView

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame])
	{
        // Initialization code here.
    }
    return self;
}


- (void)drawRect:(NSRect)rect
{
	[[NSColor blackColor] set];
	NSRectFill(rect);
	
	NSRect			originalTransitionRect = NSMakeRect(NSMinX([mosaicView frame]), 
														NSMaxY([mosaicView frame]), 
														NSWidth([mosaicView frame]), 
														NSMinY([originalImageMatrix frame]) - 
															NSMaxY([mosaicView frame]));
	
	if (NSIntersectsRect(rect, originalTransitionRect))
	{
		[[NSGraphicsContext currentContext] saveGraphicsState];
		NSBezierPath	*transitionPath = [NSBezierPath bezierPath];
		float			totalWidth = NSWidth(originalTransitionRect), 
						wideStripeWidth = totalWidth / 50.0, 
						originalWidth = totalWidth / [originalImageMatrix numberOfColumns], 
						narrowStripeWidth = originalWidth / 50.0, 
						startX = NSMinX(originalTransitionRect) + [originalImageMatrix selectedColumn] * originalWidth, 
						endX = startX + originalWidth;
		
			// Fill the entire transition path with light gray.
		[transitionPath moveToPoint:NSMakePoint(NSMinX(originalTransitionRect), NSMinY(originalTransitionRect))];
		[transitionPath lineToPoint:NSMakePoint(NSMaxX(originalTransitionRect), NSMinY(originalTransitionRect))];
		[transitionPath curveToPoint:NSMakePoint(endX, NSMaxY(originalTransitionRect)) 
					   controlPoint1:NSMakePoint(NSMaxX(originalTransitionRect), NSMidY(originalTransitionRect)) 
					   controlPoint2:NSMakePoint(endX, NSMidY(originalTransitionRect))];
		[transitionPath lineToPoint:NSMakePoint(startX, NSMaxY(originalTransitionRect))];
		[transitionPath curveToPoint:NSMakePoint(NSMinX(originalTransitionRect), NSMinY(originalTransitionRect)) 
					   controlPoint1:NSMakePoint(startX, NSMidY(originalTransitionRect)) 
					   controlPoint2:NSMakePoint(NSMinX(originalTransitionRect), NSMidY(originalTransitionRect))];
		[[NSColor lightGrayColor] set];
		[transitionPath fill];
		
		[transitionPath addClip];
		
		[transitionPath removeAllPoints];
		int				i = 0;
		float	narrowX = startX,
				wideX = NSMinX(originalTransitionRect);
		for (i = 0; i < 51; i++, narrowX += narrowStripeWidth, wideX += wideStripeWidth)
		{
			[transitionPath moveToPoint:NSMakePoint(narrowX, NSMaxY(originalTransitionRect))];
			[transitionPath curveToPoint:NSMakePoint(wideX, NSMinY(originalTransitionRect)) 
						   controlPoint1:NSMakePoint(narrowX, NSMidY(originalTransitionRect)) 
						   controlPoint2:NSMakePoint(wideX, NSMidY(originalTransitionRect))];
		}
		[[NSColor darkGrayColor] set];
		[transitionPath stroke];
		
		float			stripeHeight = 10.0, 
						y = 0.0;
		for (y = NSMinY(originalTransitionRect); 
			 y < NSMaxY(originalTransitionRect); 
			 y += stripeHeight, stripeHeight *= 0.9)
			[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMinX(originalTransitionRect), y)
									  toPoint:NSMakePoint(NSMaxX(originalTransitionRect), y)];
		[[NSGraphicsContext currentContext] restoreGraphicsState];
	}
}


@end

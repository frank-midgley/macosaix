//
//  MacOSaiXKioskView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/11/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXKioskView.h"

#import "RectangularTileShapes.h"


@implementation MacOSaiXKioskView

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame])
	{
        // Initialization code here.
    }
    return self;
}


- (void)setTileCount:(int)count
{
	tileCount = count;
}


- (void)drawRect:(NSRect)rect
{
	[[NSColor blackColor] set];
	NSRectFill(rect);
	
	NSColor			*transitionBackgroundColor = [NSColor colorWithCalibratedRed:0.75 green:0.80 blue:1.0 alpha:1.0],
					*transitionForegroundColor = [transitionBackgroundColor shadowWithLevel:0.5];
	
		// Draw the transition from the original image to the mosaic.
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
						wideStripeWidth = totalWidth / tileCount, 
						originalWidth = totalWidth / [originalImageMatrix numberOfColumns], 
						narrowStripeWidth = originalWidth / tileCount, 
						startX = NSMinX(originalTransitionRect) + [originalImageMatrix selectedColumn] * originalWidth, 
						endX = startX + originalWidth;
		
			// Fill the entire transition path with the background color.
		[transitionPath moveToPoint:NSMakePoint(NSMinX(originalTransitionRect), NSMinY(originalTransitionRect))];
		[transitionPath lineToPoint:NSMakePoint(NSMaxX(originalTransitionRect), NSMinY(originalTransitionRect))];
		[transitionPath curveToPoint:NSMakePoint(endX, NSMaxY(originalTransitionRect)) 
					   controlPoint1:NSMakePoint(NSMaxX(originalTransitionRect), NSMidY(originalTransitionRect)) 
					   controlPoint2:NSMakePoint(endX, NSMidY(originalTransitionRect))];
		[transitionPath lineToPoint:NSMakePoint(startX, NSMaxY(originalTransitionRect))];
		[transitionPath curveToPoint:NSMakePoint(NSMinX(originalTransitionRect), NSMinY(originalTransitionRect)) 
					   controlPoint1:NSMakePoint(startX, NSMidY(originalTransitionRect)) 
					   controlPoint2:NSMakePoint(NSMinX(originalTransitionRect), NSMidY(originalTransitionRect))];
		[transitionBackgroundColor set];
		[transitionPath fill];
		
		[transitionPath addClip];
		
		[transitionPath removeAllPoints];
		int				i = 0;
		float	narrowX = startX,
				wideX = NSMinX(originalTransitionRect);
		for (i = 0; i < tileCount + 1; i++, narrowX += narrowStripeWidth, wideX += wideStripeWidth)
		{
			[transitionPath moveToPoint:NSMakePoint(narrowX, NSMaxY(originalTransitionRect))];
			[transitionPath curveToPoint:NSMakePoint(wideX, NSMinY(originalTransitionRect)) 
						   controlPoint1:NSMakePoint(narrowX, NSMidY(originalTransitionRect)) 
						   controlPoint2:NSMakePoint(wideX, NSMidY(originalTransitionRect))];
		}
		[transitionForegroundColor set];
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
	
		// Draw the transition from the image sources to the mosaic.
	NSRect			mosaicFrame = [[mosaicView superview] convertRect:[mosaicView frame] toView:self], 
					imageSourcesFrame = [[imageSourcesView superview] convertRect:[imageSourcesView frame] toView:self];
	NSRect			sourcesTransitionRect = NSMakeRect(NSMaxX(mosaicFrame), 
													   NSMinY(mosaicFrame), 
													   NSMinX(imageSourcesFrame) - NSMaxX(mosaicFrame), 
													   NSHeight(mosaicFrame)); 
	if (NSIntersectsRect(rect, sourcesTransitionRect))
	{
		
		[[NSGraphicsContext currentContext] saveGraphicsState];
		
			// Fill the entire transition path with the background color.
		NSBezierPath	*transitionPath = [NSBezierPath bezierPath];
		[transitionPath moveToPoint:NSMakePoint(NSMaxX(mosaicFrame), NSMaxY(mosaicFrame))];
		[transitionPath lineToPoint:NSMakePoint(NSMaxX(mosaicFrame), NSMinY(mosaicFrame))];
		[transitionPath curveToPoint:NSMakePoint(NSMinX(imageSourcesFrame), NSMinY(imageSourcesFrame)) 
					   controlPoint1:NSMakePoint(NSMidX(sourcesTransitionRect), NSMinY(mosaicFrame)) 
					   controlPoint2:NSMakePoint(NSMidX(sourcesTransitionRect), NSMinY(imageSourcesFrame))];
		[transitionPath lineToPoint:NSMakePoint(NSMinX(imageSourcesFrame), NSMaxY(imageSourcesFrame))];
		[transitionPath curveToPoint:NSMakePoint(NSMaxX(mosaicFrame), NSMaxY(mosaicFrame)) 
					   controlPoint1:NSMakePoint(NSMidX(sourcesTransitionRect), NSMaxY(imageSourcesFrame)) 
					   controlPoint2:NSMakePoint(NSMidX(sourcesTransitionRect), NSMaxY(mosaicFrame))];
		[transitionBackgroundColor set];
		[transitionPath fill];
		
		[transitionPath addClip];
		
		[transitionPath removeAllPoints];
		int				i = 0;
		float			mosaicStripeHeight = NSHeight(mosaicFrame) / tileCount, 
						sourcesStripeHeight = NSHeight(imageSourcesFrame) / tileCount, 
						mosaicY = NSMinY(mosaicFrame),
						imageSourcesY = NSMinY(imageSourcesFrame);
		for (i = 0; i < tileCount + 1; i++, mosaicY += mosaicStripeHeight, imageSourcesY += sourcesStripeHeight)
		{
			[transitionPath moveToPoint:NSMakePoint(NSMaxX(mosaicFrame), mosaicY)];
			[transitionPath curveToPoint:NSMakePoint(NSMinX(imageSourcesFrame), imageSourcesY) 
						   controlPoint1:NSMakePoint(NSMidX(sourcesTransitionRect), mosaicY) 
						   controlPoint2:NSMakePoint(NSMidX(sourcesTransitionRect), imageSourcesY)];
		}
		[transitionForegroundColor set];
		[transitionPath stroke];
		
		float			stripeWidth = 15.0, 
						x = 0.0;
		for (x = NSMinX(sourcesTransitionRect); 
			 x < NSMaxX(sourcesTransitionRect); 
			 x += stripeWidth, stripeWidth *= 0.9)
			[NSBezierPath strokeLineFromPoint:NSMakePoint(x, NSMinY(sourcesTransitionRect))
									  toPoint:NSMakePoint(x, NSMaxY(sourcesTransitionRect))];
		
		[[NSGraphicsContext currentContext] restoreGraphicsState];
	}
}


@end

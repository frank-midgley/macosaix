//
//  MacOSaiXKioskView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/11/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXKioskView.h"

#import "MosaicView.h"
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
	
		// Draw the transition from the target image to the mosaic.
	NSRect			targetTransitionRect = NSMakeRect(NSMinX([mosaicView frame]), 
													  NSMaxY([mosaicView frame]), 
													  NSWidth([mosaicView frame]), 
													  NSMinY([targetImageMatrix frame]) - 
															NSMaxY([mosaicView frame]));
	if (NSIntersectsRect(rect, targetTransitionRect))
	{
		[[NSGraphicsContext currentContext] saveGraphicsState];
		
		NSBezierPath	*transitionPath = [NSBezierPath bezierPath];
		float			totalWidth = NSWidth(targetTransitionRect), 
						wideStripeWidth = totalWidth / tileCount, 
						targetWidth = totalWidth / [targetImageMatrix numberOfColumns], 
						narrowStripeWidth = targetWidth / tileCount, 
						startX = NSMinX(targetTransitionRect) + [targetImageMatrix selectedColumn] * targetWidth, 
						endX = startX + targetWidth;
		
			// Fill the entire transition path with the background color.
		[transitionPath moveToPoint:NSMakePoint(NSMinX(targetTransitionRect), NSMinY(targetTransitionRect))];
		[transitionPath lineToPoint:NSMakePoint(NSMaxX(targetTransitionRect), NSMinY(targetTransitionRect))];
		[transitionPath curveToPoint:NSMakePoint(endX, NSMaxY(targetTransitionRect)) 
					   controlPoint1:NSMakePoint(NSMaxX(targetTransitionRect), NSMidY(targetTransitionRect)) 
					   controlPoint2:NSMakePoint(endX, NSMidY(targetTransitionRect))];
		[transitionPath lineToPoint:NSMakePoint(startX, NSMaxY(targetTransitionRect))];
		[transitionPath curveToPoint:NSMakePoint(NSMinX(targetTransitionRect), NSMinY(targetTransitionRect)) 
					   controlPoint1:NSMakePoint(startX, NSMidY(targetTransitionRect)) 
					   controlPoint2:NSMakePoint(NSMinX(targetTransitionRect), NSMidY(targetTransitionRect))];
		[transitionBackgroundColor set];
		[transitionPath fill];
		
		[transitionPath addClip];
		
		[transitionPath removeAllPoints];
		int				i = 0;
		float	narrowX = startX,
				wideX = NSMinX(targetTransitionRect);
		for (i = 0; i < tileCount + 1; i++, narrowX += narrowStripeWidth, wideX += wideStripeWidth)
		{
			[transitionPath moveToPoint:NSMakePoint(narrowX, NSMaxY(targetTransitionRect))];
			[transitionPath curveToPoint:NSMakePoint(wideX, NSMinY(targetTransitionRect)) 
						   controlPoint1:NSMakePoint(narrowX, NSMidY(targetTransitionRect)) 
						   controlPoint2:NSMakePoint(wideX, NSMidY(targetTransitionRect))];
		}
		[transitionForegroundColor set];
		[transitionPath stroke];
		
		float			stripeHeight = 10.0, 
						y = 0.0;
		for (y = NSMinY(targetTransitionRect); 
			 y < NSMaxY(targetTransitionRect); 
			 y += stripeHeight, stripeHeight *= 0.9)
			[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMinX(targetTransitionRect), y)
									  toPoint:NSMakePoint(NSMaxX(targetTransitionRect), y)];
		
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

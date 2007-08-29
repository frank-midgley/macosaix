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


- (void)setTileCount:(int)count
{
	tileCount = count;
	
	[self setNeedsDisplay:YES];
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
			// Fill the entire transition path with the background color.
		NSBezierPath	*transitionOutline = [NSBezierPath bezierPath];
		float			totalWidth = NSWidth(targetTransitionRect), 
						targetWidth = totalWidth / [targetImageMatrix numberOfColumns], 
						startX = NSMinX(targetTransitionRect) + [targetImageMatrix selectedColumn] * targetWidth, 
						endX = startX + targetWidth;
		[transitionOutline moveToPoint:NSMakePoint(NSMinX(targetTransitionRect), NSMinY(targetTransitionRect))];
		[transitionOutline lineToPoint:NSMakePoint(NSMaxX(targetTransitionRect), NSMinY(targetTransitionRect))];
		[transitionOutline curveToPoint:NSMakePoint(endX, NSMaxY(targetTransitionRect)) 
						  controlPoint1:NSMakePoint(NSMaxX(targetTransitionRect), NSMidY(targetTransitionRect)) 
						  controlPoint2:NSMakePoint(endX, NSMidY(targetTransitionRect))];
		[transitionOutline lineToPoint:NSMakePoint(startX, NSMaxY(targetTransitionRect))];
		[transitionOutline curveToPoint:NSMakePoint(NSMinX(targetTransitionRect), NSMinY(targetTransitionRect)) 
						  controlPoint1:NSMakePoint(startX, NSMidY(targetTransitionRect)) 
						  controlPoint2:NSMakePoint(NSMinX(targetTransitionRect), NSMidY(targetTransitionRect))];
		[transitionBackgroundColor set];
		[transitionOutline fill];
		
		if (tileCount > 0)
		{
			NSBezierPath	*transitionWeb = [NSBezierPath bezierPath];
			float			wideStripeWidth = totalWidth / tileCount, 
							narrowStripeWidth = targetWidth / tileCount;
			
			int				i = 0;
			float			narrowX = startX,
							wideX = NSMinX(targetTransitionRect);
			for (i = 0; i < tileCount + 1; i++, narrowX += narrowStripeWidth, wideX += wideStripeWidth)
			{
				[transitionWeb moveToPoint:NSMakePoint(narrowX, NSMaxY(targetTransitionRect))];
				[transitionWeb curveToPoint:NSMakePoint(wideX, NSMinY(targetTransitionRect)) 
							  controlPoint1:NSMakePoint(narrowX, NSMidY(targetTransitionRect)) 
							  controlPoint2:NSMakePoint(wideX, NSMidY(targetTransitionRect))];
			}
			
			float			stripeHeight = 10.0, 
							y = 0.0;
			for (y = NSMinY(targetTransitionRect); y < NSMaxY(targetTransitionRect); y += stripeHeight, stripeHeight *= 0.9)
			{
				[transitionWeb moveToPoint:NSMakePoint(NSMinX(targetTransitionRect), y)];
				[transitionWeb lineToPoint:NSMakePoint(NSMaxX(targetTransitionRect), y)];
			}
			
			[[NSGraphicsContext currentContext] saveGraphicsState];
			
				[transitionOutline addClip];
				[transitionForegroundColor set];
				[transitionWeb stroke];
			
			[[NSGraphicsContext currentContext] restoreGraphicsState];
		}
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
			// Fill the entire transition path with the background color.
		NSBezierPath	*transitionOutline = [NSBezierPath bezierPath];
		[transitionOutline moveToPoint:NSMakePoint(NSMaxX(mosaicFrame), NSMaxY(mosaicFrame))];
		[transitionOutline lineToPoint:NSMakePoint(NSMaxX(mosaicFrame), NSMinY(mosaicFrame))];
		[transitionOutline curveToPoint:NSMakePoint(NSMinX(imageSourcesFrame), NSMinY(imageSourcesFrame)) 
						  controlPoint1:NSMakePoint(NSMidX(sourcesTransitionRect), NSMinY(mosaicFrame)) 
						  controlPoint2:NSMakePoint(NSMidX(sourcesTransitionRect), NSMinY(imageSourcesFrame))];
		[transitionOutline lineToPoint:NSMakePoint(NSMinX(imageSourcesFrame), NSMaxY(imageSourcesFrame))];
		[transitionOutline curveToPoint:NSMakePoint(NSMaxX(mosaicFrame), NSMaxY(mosaicFrame)) 
						  controlPoint1:NSMakePoint(NSMidX(sourcesTransitionRect), NSMaxY(imageSourcesFrame)) 
						  controlPoint2:NSMakePoint(NSMidX(sourcesTransitionRect), NSMaxY(mosaicFrame))];
		[transitionBackgroundColor set];
		[transitionOutline fill];
		
		if (tileCount > 0)
		{
			NSBezierPath	*transitionWeb = [NSBezierPath bezierPath];
			int				i = 0;
			float			mosaicStripeHeight = NSHeight(mosaicFrame) / tileCount, 
							sourcesStripeHeight = NSHeight(imageSourcesFrame) / tileCount, 
							mosaicY = NSMinY(mosaicFrame),
							imageSourcesY = NSMinY(imageSourcesFrame);
			for (i = 0; i < tileCount + 1; i++, mosaicY += mosaicStripeHeight, imageSourcesY += sourcesStripeHeight)
			{
				[transitionWeb moveToPoint:NSMakePoint(NSMaxX(mosaicFrame), mosaicY)];
				[transitionWeb curveToPoint:NSMakePoint(NSMinX(imageSourcesFrame), imageSourcesY) 
							  controlPoint1:NSMakePoint(NSMidX(sourcesTransitionRect), mosaicY) 
							  controlPoint2:NSMakePoint(NSMidX(sourcesTransitionRect), imageSourcesY)];
			}
			
			float			stripeWidth = 15.0, 
							x = 0.0;
			for (x = NSMinX(sourcesTransitionRect); x < NSMaxX(sourcesTransitionRect); x += stripeWidth, stripeWidth *= 0.9)
			{
				[transitionWeb moveToPoint:NSMakePoint(x, NSMinY(sourcesTransitionRect))];
				[transitionWeb lineToPoint:NSMakePoint(x, NSMaxY(sourcesTransitionRect))];
			}
			
			[[NSGraphicsContext currentContext] saveGraphicsState];
			
				[transitionOutline addClip];
				[transitionForegroundColor set];
				[transitionWeb stroke];
			
			[[NSGraphicsContext currentContext] restoreGraphicsState];
		}
	}
}


@end

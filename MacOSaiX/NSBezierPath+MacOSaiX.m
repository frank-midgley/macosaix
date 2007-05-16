//
//  NSBezierPath+MacOSaiX.m
//  MacOSaiX
//
//  Created by Frank Midgley on 7/9/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "NSBezierPath+MacOSaiX.h"


@implementation NSBezierPath (MacOSaiX)


+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect radius:(float)radius
{
	NSBezierPath	*path = [NSBezierPath bezierPath];
	float			halfRadius = radius / 2.0;
	
	[path moveToPoint:NSMakePoint(NSMinX(rect) + radius, NSMinY(rect))];
	[path lineToPoint:NSMakePoint(NSMaxX(rect) - radius, NSMinY(rect))];
	[path curveToPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect) + radius) 
		 controlPoint1:NSMakePoint(NSMaxX(rect) - halfRadius, NSMinY(rect)) 
		 controlPoint2:NSMakePoint(NSMaxX(rect), NSMinY(rect) + halfRadius)];
	[path lineToPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect) - radius)];
	[path curveToPoint:NSMakePoint(NSMaxX(rect) - radius, NSMaxY(rect)) 
		 controlPoint1:NSMakePoint(NSMaxX(rect), NSMaxY(rect) - halfRadius) 
		 controlPoint2:NSMakePoint(NSMaxX(rect) - halfRadius, NSMaxY(rect))];
	[path lineToPoint:NSMakePoint(NSMinX(rect) + radius, NSMaxY(rect))];
	[path curveToPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect) - radius) 
		 controlPoint1:NSMakePoint(NSMinX(rect) + halfRadius, NSMaxY(rect)) 
		 controlPoint2:NSMakePoint(NSMinX(rect), NSMaxY(rect) - halfRadius)];
	[path lineToPoint:NSMakePoint(NSMinX(rect), NSMinY(rect) + radius)];
	[path curveToPoint:NSMakePoint(NSMinX(rect) + radius, NSMinY(rect)) 
		 controlPoint1:NSMakePoint(NSMinX(rect), NSMinY(rect) + halfRadius) 
		 controlPoint2:NSMakePoint(NSMinX(rect) + halfRadius, NSMinY(rect))];
	[path closePath];
	
	return path;
}


- (CGPathRef)quartzPath
{
    int			i, numElements = [self elementCount];
    CGPathRef	immutablePath = NULL;
	
		// If there are elements to draw, create a CGMutablePathRef and draw.
    if (numElements > 0)
    {
        CGMutablePathRef    path = CGPathCreateMutable();
        NSPoint             points[3];
		
			// Iterate over the points and add them to the mutable path object.
        for (i = 0; i < numElements; i++) 
        {
            switch ([self elementAtIndex:i associatedPoints:points]) 
            {
                case NSMoveToBezierPathElement:
                    CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
                    break;
					
                case NSLineToBezierPathElement:
                    CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
                    break;
					
                case NSCurveToBezierPathElement:
                    CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y, 
										  points[1].x, points[1].y, 
										  points[2].x, points[2].y);
                    break;
					
                case NSClosePathBezierPathElement:
                    CGPathCloseSubpath(path);
                    break;
            }
        }
		
        // Return an immutable copy of the path.
        immutablePath = CGPathCreateCopy(path);
        CGPathRelease(path);
    }
	
    return immutablePath;
}


@end

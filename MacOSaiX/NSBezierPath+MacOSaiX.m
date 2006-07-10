//
//  NSBezierPath+MacOSaiX.m
//  MacOSaiX
//
//  Created by Frank Midgley on 7/9/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NSBezierPath+MacOSaiX.h"


@implementation NSBezierPath (MacOSaiX)


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

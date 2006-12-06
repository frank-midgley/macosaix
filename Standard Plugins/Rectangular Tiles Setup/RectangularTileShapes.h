//
//  RectangularTileShapes.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapes.h"


typedef enum { normalImageOrientation, radialInImageOrientation, radialOutImageOrientation } MacOSaiXImageOrientation;


@interface MacOSaiXRectangularTileShape : NSObject <MacOSaiXTileShape>
{
	NSBezierPath	*outline;
	float			imageOrientation;
}

+ (MacOSaiXRectangularTileShape *)tileShapeWithOutline:(NSBezierPath *)outline imageOrientation:(float)angle;
- (id)initWithOutline:(NSBezierPath *)outline imageOrientation:(float)angle;

@end


@interface MacOSaiXRectangularTileShapes : NSObject <MacOSaiXTileShapes>
{
	unsigned int				tilesAcross, 
								tilesDown;
	
	MacOSaiXImageOrientation	imageOrientationType;
	NSPoint						imageOrientationFocusPoint;
}

- (void)setTilesAcross:(unsigned int)count;
- (unsigned int)tilesAcross;

- (void)setTilesDown:(unsigned int)count;
- (unsigned int)tilesDown;

- (void)setImageOrientationType:(MacOSaiXImageOrientation)orientation;
- (MacOSaiXImageOrientation)imageOrientationType;

- (void)setImageOrientationFocusPoint:(NSPoint)point;
- (NSPoint)imageOrientationFocusPoint;

@end

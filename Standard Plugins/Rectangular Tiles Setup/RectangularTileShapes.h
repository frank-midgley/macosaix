//
//  RectangularTileShapes.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapes.h"


@interface MacOSaiXRectangularTileShape : NSObject <MacOSaiXTileShape>
{
	NSBezierPath	*outline;
}

+ (MacOSaiXRectangularTileShape *)tileShapeWithOutline:(NSBezierPath *)outline;
- (id)initWithOutline:(NSBezierPath *)outline;

@end


@interface MacOSaiXRectangularTileShapes : NSObject <MacOSaiXTileShapes>
{
	unsigned int				tilesAcross, 
								tilesDown;
}

- (void)setTilesAcross:(unsigned int)count;
- (unsigned int)tilesAcross;

- (void)setTilesDown:(unsigned int)count;
- (unsigned int)tilesDown;

@end

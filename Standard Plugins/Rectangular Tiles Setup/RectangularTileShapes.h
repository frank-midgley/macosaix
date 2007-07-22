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
	BOOL			isFreeForm;
	
		// Freeform tiles
	unsigned int	tilesAcross, 
					tilesDown;
	
		// Fixed size tiles
	float			tileAspectRatio, 
					tileCount;
}

- (BOOL)isFreeForm;

- (void)setTilesAcross:(unsigned int)count;
- (unsigned int)tilesAcross;

- (void)setTilesDown:(unsigned int)count;
- (unsigned int)tilesDown;

- (void)setTileAspectRatio:(float)aspectRatio;
- (float)tileAspectRatio;

- (void)setTileCount:(float)count;
- (float)tileCount;

@end

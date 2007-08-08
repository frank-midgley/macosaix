//
//  HexagonalTileShapes.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 12 2005.
//  Copyright (c) 2003-2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapes.h"


@interface MacOSaiXHexagonalTileShape : NSObject <MacOSaiXTileShape>
{
	NSBezierPath	*outline;
}

+ (MacOSaiXHexagonalTileShape *)tileShapeWithOutline:(NSBezierPath *)inOutline;
- (id)initWithOutline:(NSBezierPath *)outline;

@end


@interface MacOSaiXHexagonalTileShapes : NSObject <MacOSaiXTileShapes>
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

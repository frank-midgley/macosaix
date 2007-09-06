//
//  SpiralTileShapes.h
//  MacOSaiX
//
//  Created by Frank Midgley on 8/16/2007.
//  Copyright (c) 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapes.h"


@interface MacOSaiXSpiralTileShape : NSObject <MacOSaiXTileShape>
{
	NSBezierPath	*outline;
	NSNumber		*orientation;
}

+ (MacOSaiXSpiralTileShape *)tileShapeWithOutline:(NSBezierPath *)outline orientation:(NSNumber *)angle;
- (id)initWithOutline:(NSBezierPath *)outline orientation:(NSNumber *)angle;

@end


@interface MacOSaiXSpiralTileShapes : NSObject <MacOSaiXTileShapes>
{
	float			spiralTightness, 
					tileAspectRatio;
	BOOL			imagesFollowSpiral;
}

- (void)setSpiralTightness:(float)count;
- (float)spiralTightness;

- (void)setTileAspectRatio:(float)aspectRatio;
- (float)tileAspectRatio;

- (void)setImagesFollowSpiral:(BOOL)flag;
- (BOOL)imagesFollowSpiral;

@end

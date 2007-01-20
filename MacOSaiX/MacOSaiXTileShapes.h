//
//  MacOSaiXTilesShapes.h
//  MacOSaiX
//
//  Created by Frank Midgley on Nov 28 2004.
//  Copyright (c) 2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXPlugIn.h"


@protocol MacOSaiXTileShape <NSObject>

	// This method should return a bezier path that defines the outline of the shape.  The outline is assumed to exist inside of a unit square that will be mapped to a mosaic's target image.  So, for example, the size of a rectangular tile in a 40x40 array would be {0.025, 0.025}.
- (NSBezierPath *)unitOutline;

	// This method can return the angle at which images should be drawn inside the tile, in degrees.  An angle of 0 degress will draw images drawn in their normal, upright orientation.  If nil is returned then the angle specified by the image orientation plug-in will be used instead.
- (NSNumber *)imageOrientation;

@end


@protocol MacOSaiXTileShapes <MacOSaiXDataSource>

	// This method should return an array of objects conforming to the MacOSaiXTileShape protocol based on the settings defined by the user.
- (NSArray *)shapes;

@end

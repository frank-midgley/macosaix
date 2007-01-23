//
//  MacOSaiXTilesShapes.h
//  MacOSaiX
//
//  Created by Frank Midgley on Nov 28 2004.
//  Copyright (c) 2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXPlugIn.h"


@protocol MacOSaiXTileShape <NSObject>

	// This method should return a bezier path that defines the outline of the shape.  The outline is assumed to exist inside of a rectangle located at {0.0, 0.0} and having the size passed to the -shapesForMosaicOfSize: method below.  So, for example, an outline for a tile in a set of 40x40 rectangular tiles for a mosaic of size {600.0, 400.0} could have a bounding box of {0.0, 0.0, 15.0, 10.0}.
- (NSBezierPath *)outline;

	// This method can return the angle at which images should be drawn inside the tile, in degrees.  An angle of 0 degress will draw images drawn in their normal, upright orientation.  If nil is returned then the angle specified by the image orientation plug-in will be used instead.
- (NSNumber *)imageOrientation;

@end


@protocol MacOSaiXTileShapes <MacOSaiXDataSource>

	// This method should return an array of objects conforming to the MacOSaiXTileShape protocol based on the settings defined by the user.
- (NSArray *)shapesForMosaicOfSize:(NSSize)mosaicSize;

@end

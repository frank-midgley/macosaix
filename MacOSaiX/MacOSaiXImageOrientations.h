//
//  MacOSaiXImageOrientations.h
//  MacOSaiX
//
//  Created by Frank Midgley on Dec 07 2006.
//  Copyright (c) 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXPlugIn.h"


@protocol MacOSaiXImageOrientations <MacOSaiXDataSource>

	// This method should return the image orientation angle at the point within a rect of rectSize based on the settings defined by the user.
- (float)imageOrientationAtPoint:(NSPoint)point inRectOfSize:(NSSize)rectSize;

@end

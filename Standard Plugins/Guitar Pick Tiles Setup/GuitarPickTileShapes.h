//
//  GuitarPickTileShapes.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileShapes.h"


@interface MacOSaiXGuitarPickTileShapes : NSObject <MacOSaiXTileShapes>
{
	unsigned int	rowCount;
	float			aspectRatio;
}

- (void)setRowCount:(unsigned int)count aspectRatio:(float)ratio;
- (unsigned int)rowCount;
- (float)aspectRatio;

@end

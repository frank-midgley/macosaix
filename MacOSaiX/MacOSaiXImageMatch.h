//
//  MacOSaiXImageMatch.h
//  MacOSaiX
//
//  Created by Frank Midgley on 9/5/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXSourceImage, MacOSaiXTile;


@interface MacOSaiXImageMatch : NSObject
{
    float				matchValue;
    MacOSaiXSourceImage	*sourceImage;
	MacOSaiXTile		*tile;
}

+ (id)imageMatchWithValue:(float)value 
		   forSourceImage:(MacOSaiXSourceImage *)source
				  forTile:(MacOSaiXTile *)tile;

- (id)initWithMatchValue:(float)inMatchValue 
		  forSourceImage:(MacOSaiXSourceImage *)source
				 forTile:(MacOSaiXTile *)inTile;

- (float)matchValue;
- (MacOSaiXSourceImage *)sourceImage;

- (void)setTile:(MacOSaiXTile *)inTile;
- (MacOSaiXTile *)tile;

- (NSComparisonResult)compare:(MacOSaiXImageMatch *)otherMatch;

@end

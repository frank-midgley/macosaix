//
//  MacOSaiXImageMatch.h
//  MacOSaiX
//
//  Created by Frank Midgley on 9/5/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MacOSaiXSourceImage, MacOSaiXTile;


@interface MacOSaiXImageMatch : NSObject
{
    float					matchValue;
	MacOSaiXSourceImage		*sourceImage;
	MacOSaiXTile			*tile;
//	NSLock					*lock;
}

+ (id)imageMatchWithValue:(float)value 
			  sourceImage:(MacOSaiXSourceImage *)sourceImage
					 tile:(MacOSaiXTile *)tile;

- (id)initWithMatchValue:(float)inMatchValue 
			 sourceImage:(MacOSaiXSourceImage *)inSourceImage
					tile:(MacOSaiXTile *)inTile;

- (void)setMatchValue:(float)value;
- (float)matchValue;
- (MacOSaiXSourceImage *)sourceImage;
- (void)setTile:(MacOSaiXTile *)inTile;
- (MacOSaiXTile *)tile;

- (NSComparisonResult)compareByMatchThenSourceImage:(MacOSaiXImageMatch *)otherMatch;
- (NSComparisonResult)compareByMatchThenTile:(MacOSaiXImageMatch *)otherMatch;

@end

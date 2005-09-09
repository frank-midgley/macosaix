//
//  MacOSaiXImageMatch.h
//  MacOSaiX
//
//  Created by Frank Midgley on 9/5/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXImageSource.h"

@class MacOSaiXTile;


@interface MacOSaiXImageMatch : NSObject
{
    float					matchValue;
    id<MacOSaiXImageSource>	imageSource;
	NSString				*imageIdentifier;
	MacOSaiXTile			*tile;
}

+ (id)imageMatchWithValue:(float)value 
	   forImageIdentifier:(NSString *)identifier 
		  fromImageSource:(id<MacOSaiXImageSource>)source
				  forTile:(MacOSaiXTile *)tile;
- (id)initWithMatchValue:(float)inMatchValue 
	  forImageIdentifier:(NSString *)inImageIdentifier 
		 fromImageSource:(id<MacOSaiXImageSource>)inImageSource
				 forTile:(MacOSaiXTile *)inTile;
- (float)matchValue;
- (id<MacOSaiXImageSource>)imageSource;
- (NSString *)imageIdentifier;
- (MacOSaiXTile *)tile;
- (void)setTile:(MacOSaiXTile *)inTile;
- (NSComparisonResult)compare:(MacOSaiXImageMatch *)otherMatch;

@end

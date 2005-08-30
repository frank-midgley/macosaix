//
//  MacOSaiXImageMatcher.h
//  MacOSaiX
//
//  Created by Frank Midgley on 8/28/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXImageMatcher : NSObject
{

}

+ (MacOSaiXImageMatcher *)sharedMatcher;

- (float)compareImageRep:(NSBitmapImageRep *)bitmapRep1
				withMask:(NSBitmapImageRep *)maskRep
			  toImageRep:(NSBitmapImageRep *)bitmapRep2
		    previousBest:(float)valueToBeat;

@end

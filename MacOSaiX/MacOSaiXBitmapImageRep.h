//
//  MacOSaiXBitmapImageRep.h
//  MacOSaiX
//
//  Created by Frank Midgley on 4/3/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MacOSaiXSourceImage;


@interface MacOSaiXBitmapImageRep : NSBitmapImageRep
{
	UInt32				lastAccessTickCount;
	MacOSaiXSourceImage	*sourceImage;
	NSData				*cachedBitmapData;
}

- (void)imageRepWasAccessed;
- (UInt32)lastAccessTickCount;

- (void)setSourceImage:(MacOSaiXSourceImage *)image;
- (MacOSaiXSourceImage *)sourceImage;

@end

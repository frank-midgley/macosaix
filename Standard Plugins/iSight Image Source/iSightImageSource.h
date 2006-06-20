/*
	iSightImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/

#import <Cocoa/Cocoa.h>
#import <QuickTime/QuickTime.h>

#import "MacOSaiXImageSource.h"


@interface MacOSaiXiSightImageSource : NSObject <MacOSaiXImageSource>
{
	NSLock		*movieLock;
	BOOL		movieIsThreadSafe;
	NSImage		*currentImage;
	float		aspectRatio;
}

- (NSString *)path;
- (void)setPath:(NSString *)path;

- (float)aspectRatio;

@end

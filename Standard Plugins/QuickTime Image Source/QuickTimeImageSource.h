/*
	QuickTimeImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/

#import <Cocoa/Cocoa.h>
#import <QuickTime/QuickTime.h>

#import "MacOSaiXImageSource.h"


@interface QuickTimeImageSource : NSObject <MacOSaiXImageSource>
{
    NSString	*moviePath;
	NSMovie		*movie;
	float		aspectRatio;
	TimeValue	minIncrement,
                currentTimeValue, 
                duration;
	NSLock		*currentImageLock;
	NSImage		*currentImage;
}

- (NSString *)path;
- (void)setPath:(NSString *)path;

- (NSMovie *)movie;
- (float)aspectRatio;

@end

/*
	QuickTimeImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>

#import "MacOSaiXImageSource.h"


@interface QuickTimeImageSource : NSObject <MacOSaiXImageSource>
{
    NSString		*moviePath;
	QTMovie			*movie;
	NSRecursiveLock	*movieLock;
	NSImage			*currentImage;
	float			aspectRatio;
	QTTime			minIncrement,
					currentTime, 
					duration;
//	TimeScale		timeScale;
	BOOL			canRefetchImages;
}

- (NSString *)path;
- (void)setPath:(NSString *)path;

- (void)setCanRefetchImages:(BOOL)flag;

- (float)aspectRatio;

@end

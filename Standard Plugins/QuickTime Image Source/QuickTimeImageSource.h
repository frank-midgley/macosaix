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
    NSString		*moviePath;
	NSMovie			*movie;
	NSRecursiveLock	*movieLock;
	BOOL			movieIsThreadSafe;
	NSImage			*currentImage;
	float			aspectRatio;
	TimeValue		currentTimeValue, 
					duration;
	TimeScale		timeScale;
	int				samplingRateType;
	float			constantSamplingRate;
	Rect			nativeBounds, 
					thumbnailBounds;
	BOOL			canRefetchImages;
	
	NSMutableArray	*recentImageReps;
}

- (NSString *)path;
- (void)setPath:(NSString *)path;

- (void)setSamplingRateType:(int)type;
- (int)samplingRateType;

- (void)setConstantSamplingRate:(float)rate;
- (float)constantSamplingRate;

- (void)setCanRefetchImages:(BOOL)flag;

- (float)aspectRatio;

@end

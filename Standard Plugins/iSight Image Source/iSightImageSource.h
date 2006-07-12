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
	NSString	*videoSource;
	NSImage		*currentImage;
	float		aspectRatio;
	
	VideoDigitizerComponent		digitizer;
	ImageDescriptionHandle		imageDescHandle;
	
	GWorldPtr					offscreen;
	SeqGrabComponent			grabber;
	SGChannel					channel;
	TimeScale					timeScale;
	ImageDescriptionHandle		imageDescription;
	ICMDecompressionSessionRef	session;
	long						frameNumber;
	NSTimer						*timer;
	NSSize						size;
}

- (NSString *)source;
- (void)setSource:(NSString *)source;

- (float)aspectRatio;

@end

/*
	QuickTimeImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/

#import <Cocoa/Cocoa.h>
#import <QuickTime/QuickTime.h>

#import <MacOSaiXmageSource.h>


@interface QuickTimeImageSource <MacOSaiXImageSource>
{
    NSString	*moviePath;
	Movie		movie;
	TimeValue	minIncrement,
                currentTimeValue, 
                duration;
	NSImage		*currentImage;
}

@end

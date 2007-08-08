//
//  MacOSaiXImageQueue.h
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


@class MacOSaiXSourceImage;
@protocol MacOSaiXImageSource;


@interface MacOSaiXImageQueue : NSObject
{
	NSMutableArray	*imageQueue;
	NSLock			*queueLock;
	NSConditionLock	*queueFullLock;
	unsigned int	maximumCount;
}

- (unsigned)count;

- (void)setMaximumCount:(unsigned int)count;
- (unsigned int)maximumCount;

- (void)pushImage:(MacOSaiXSourceImage *)image;
- (MacOSaiXSourceImage *)popImage;

- (void)addImagesFromQueue:(MacOSaiXImageQueue *)otherQueue;

- (void)removeImagesFromImageSource:(id<MacOSaiXImageSource>)imageSource;

- (NSArray *)queuedImages;

- (void)clear;

@end

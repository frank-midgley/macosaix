//
//  MacOSaiXImageQueue.h
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


@class MacOSaiXImageSourceEnumerator, MacOSaiXSourceImage;


@interface MacOSaiXImageQueue : NSObject
{
	NSMutableArray	*imageQueue, 
					*imagelessQueue;
	NSLock			*queueLock;
	unsigned int	maximumCount, 
					revisitStep;
}

- (unsigned)count;

- (void)setMaximumCount:(unsigned int)count;
- (unsigned int)maximumCount;

- (void)pushImage:(MacOSaiXSourceImage *)image;
- (MacOSaiXSourceImage *)popImage;

- (void)addImagesFromQueue:(MacOSaiXImageQueue *)otherQueue;

- (void)removeImagesFromImageSourceEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator;

- (NSArray *)queuedImages;

- (void)clear;

@end

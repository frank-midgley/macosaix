//
//  MacOSaiXImageQueue.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageQueue.h"

#import "MacOSaiXImageSourceEnumerator.h"
#import "MacOSaiXSourceImage.h"


#define IMAGE_QUEUE_NOT_FULL	0
#define IMAGE_QUEUE_FULL		1


@implementation MacOSaiXImageQueue


- (id)init
{
	if (self = [super init])
	{
		imageQueue = [[NSMutableArray array] retain];
		queueLock = [[NSLock alloc] init];
		queueFullLock = [[NSConditionLock alloc] initWithCondition:IMAGE_QUEUE_NOT_FULL];
	}
	
	return self;
}


- (unsigned)count
{
	unsigned	count = 0;
	
	[queueLock lock];
		count = [imageQueue count];
	[queueLock unlock];
	
	return count;
}

- (void)setMaximumCount:(unsigned int)count
{
	[queueLock lock];
		
		maximumCount = count;
		
		if (maximumCount == 0 || ([imageQueue count] < maximumCount))
			[queueFullLock unlockWithCondition:IMAGE_QUEUE_NOT_FULL];
		
	[queueLock unlock];
}


- (unsigned int)maximumCount
{
	return maximumCount;
}


- (void)pushImage:(MacOSaiXSourceImage *)sourceImage;
{
	[queueLock lock];
		
		while ([self maximumCount] > 0 && [imageQueue count] >= [self maximumCount])
		{
			[queueFullLock unlockWithCondition:IMAGE_QUEUE_FULL];
			[queueLock unlock];
			[queueFullLock lockWhenCondition:IMAGE_QUEUE_NOT_FULL];
			[queueLock lock];
		}
		[imageQueue addObject:sourceImage];
		
	[queueLock unlock];
}


- (MacOSaiXSourceImage *)popImage
{
	MacOSaiXSourceImage	*queuedImage = nil;
				
	[queueLock lock];
		queuedImage = [[[imageQueue objectAtIndex:0] retain] autorelease];
		[imageQueue removeObjectAtIndex:0];
		
		if ([self maximumCount] > 0 && [imageQueue count] < [self maximumCount])
			[queueFullLock unlockWithCondition:IMAGE_QUEUE_NOT_FULL];
	[queueLock unlock];
	
	return queuedImage;
}


- (void)addImagesFromQueue:(MacOSaiXImageQueue *)otherQueue
{
	NSEnumerator		*queuedImageEnumerator = [[otherQueue queuedImages] objectEnumerator];
	MacOSaiXSourceImage	*queuedImage = nil;
	
	[queueLock lock];
		while (queuedImage = [queuedImageEnumerator nextObject])
			if (![imageQueue containsObject:queuedImage])
				[imageQueue addObject:queuedImage];
	[queueLock unlock];
}


- (void)removeImagesFromImageSourceEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator;
{
		// Remove any images that came from the enumerator.
	[queueLock lock];
		NSEnumerator		*sourceImageEnumerator = [[NSArray arrayWithArray:imageQueue] objectEnumerator];
		MacOSaiXSourceImage	*sourceImage = nil;
		while (sourceImage = [sourceImageEnumerator nextObject])
			if ([sourceImage enumerator] == enumerator)
				[imageQueue removeObjectIdenticalTo:sourceImage];
		
		if ([self maximumCount] > 0 && [imageQueue count] < [self maximumCount])
			[queueFullLock unlockWithCondition:IMAGE_QUEUE_NOT_FULL];
	[queueLock unlock];
}


- (NSArray *)queuedImages
{
	NSArray	*queuedImages = nil;
	
	[queueLock lock];
		queuedImages = [NSArray arrayWithArray:imageQueue];
	[queueLock unlock];
	
	return queuedImages;
}


- (void)clear
{
	[queueLock lock];
		[imageQueue removeAllObjects];
		
		[queueFullLock unlockWithCondition:IMAGE_QUEUE_NOT_FULL];
	[queueLock unlock];
}


- (void)dealloc
{
	[imageQueue release];
	[queueLock release];
	[queueFullLock release];
	
	[super dealloc];
}


@end

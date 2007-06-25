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


@implementation MacOSaiXImageQueue


- (id)init
{
	if (self = [super init])
	{
		imageQueue = [[NSMutableArray array] retain];
		imagelessQueue = [[NSMutableArray array] retain];
		queueLock = [[NSLock alloc] init];
	}
	
	return self;
}


- (unsigned)count
{
	unsigned	count = 0;
	
	[queueLock lock];
		count = [imageQueue count] + [imagelessQueue count];
	[queueLock unlock];
	
	return count;
}

- (void)setMaximumCount:(unsigned int)count
{
	maximumCount = count;
}


- (unsigned int)maximumCount
{
	return maximumCount;
}


- (void)pushImage:(MacOSaiXSourceImage *)sourceImage;
{
	// TODO: lock if queue is full
	
	[queueLock lock];
		if ([sourceImage image])
			[imageQueue addObject:sourceImage];
		else
			[imagelessQueue addObject:sourceImage];
	[queueLock unlock];
}


- (MacOSaiXSourceImage *)popImage
{
	MacOSaiXSourceImage	*queuedImage = nil;
				
	[queueLock lock];
		NSMutableArray	*chosenQueue = nil;
		
		if ([imageQueue count] > 0 && [imagelessQueue count] == 0)
			chosenQueue = imageQueue;
		else if ([imagelessQueue count] > 0 && [imageQueue count] == 0)
			chosenQueue = imagelessQueue;
		else if ([imagelessQueue count] > 0 && [imageQueue count] > 0)
		{
			chosenQueue = (revisitStep < 15 ? imageQueue : imagelessQueue);
			revisitStep = (revisitStep + 1) % 16;
		}
		
		queuedImage = [[[chosenQueue objectAtIndex:0] retain] autorelease];
		[chosenQueue removeObjectAtIndex:0];
	[queueLock unlock];
	
	return queuedImage;
}


- (void)addImagesFromQueue:(MacOSaiXImageQueue *)otherQueue
{
	NSEnumerator		*sourceImageEnumerator = [[otherQueue queuedImages] objectEnumerator];
	MacOSaiXSourceImage	*sourceImage = nil;
	
	[queueLock lock];
		while (sourceImage = [sourceImageEnumerator nextObject])
		{
			if ([sourceImage image])
				[imageQueue addObject:sourceImage];
			else
				[imagelessQueue addObject:sourceImage];
		}
	[queueLock unlock];
}


- (void)removeImagesFromImageSourceEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator;
{
		// Remove any images from this enumerator that are waiting to be matched or revisited.
	[queueLock lock];
		NSEnumerator		*sourceImageEnumerator = [[NSArray arrayWithArray:imageQueue] objectEnumerator];
		MacOSaiXSourceImage	*sourceImage = nil;
		while (sourceImage = [sourceImageEnumerator nextObject])
			if ([sourceImage enumerator] == enumerator)
				[imageQueue removeObjectIdenticalTo:sourceImage];
		sourceImageEnumerator = [[NSArray arrayWithArray:imagelessQueue] objectEnumerator];
		while (sourceImage = [sourceImageEnumerator nextObject])
			if ([sourceImage enumerator] == enumerator)
				[imagelessQueue removeObjectIdenticalTo:sourceImage];
	[queueLock unlock];
}


- (NSArray *)queuedImages
{
	NSArray	*queuedImages = nil;
	
	[queueLock lock];
		queuedImages = [imageQueue arrayByAddingObjectsFromArray:imagelessQueue];
	[queueLock unlock];
	
	return queuedImages;
}


- (void)clear
{
	[queueLock lock];
		[imageQueue removeAllObjects];
		[imagelessQueue removeAllObjects];
	[queueLock unlock];
}


- (void)dealloc
{
	[imageQueue release];
	[imagelessQueue release];
	[queueLock release];
	
	[super dealloc];
}


@end

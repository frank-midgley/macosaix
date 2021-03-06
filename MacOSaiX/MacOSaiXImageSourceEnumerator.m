//
//  MacOSaiXImageSourceEnumerator.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/21/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSourceEnumerator.h"

#import "MacOSaiX.h"
#import "MacOSaiXEnumeratedImage.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageQueue.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXMosaic.h"


NSString	*MacOSaiXImageSourceEnumeratorDidChangeCountNotification = @"MacOSaiXImageSourceEnumeratorDidChangeCountNotification";


@implementation MacOSaiXImageSourceEnumerator


- (id)initWithImageSource:(id<MacOSaiXImageSource>)source forMosaic:(MacOSaiXMosaic *)inMosaic
{
	if (self = [super init])
	{
		[self setImageSource:source];
		mosaic = inMosaic;	// don't retain our parent
		inUseLock = [[NSLock alloc] init];
		identifiersInUse = [[NSMutableSet set] retain];
		
		probationLock = [[NSRecursiveLock alloc] init];
		probationaryImageQueue = [[MacOSaiXImageQueue alloc] init];
	}
	
	return self;
}


- (void)setImageSource:(id<MacOSaiXImageSource>)source
{
	if (source != imageSource)
	{
		[imageSource release];
		imageSource = [source retain];
	}
	
		// Work with a copy of the source so the original can be modified safely in the main thread.
	[workingImageSource release];
	workingImageSource = [imageSource copyWithZone:[self zone]];
	
	// reset?
}


- (id<MacOSaiXImageSource>)imageSource
{
	return imageSource;
}


- (id<MacOSaiXImageSource>)workingImageSource
{
	return workingImageSource;
}


- (void)setNumberOfImagesFound:(unsigned long)count
{
	if (count != imagesFound)
	{
		imagesFound = count;
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXImageSourceEnumeratorDidChangeCountNotification object:self];
	}
}


- (unsigned long)numberOfImagesFound
{
	return imagesFound;
}


- (void)setImageIdentifier:(NSString *)imageIdentifier isInUse:(BOOL)inUse
{
	BOOL	imageWasInUse;
	
	[inUseLock lock];
	
		imageWasInUse = [identifiersInUse containsObject:imageIdentifier];
		
		if (inUse && !imageWasInUse)
			[identifiersInUse addObject:imageIdentifier];
		else if (!inUse && imageWasInUse)
			[identifiersInUse removeObject:imageIdentifier];
	
	[inUseLock unlock];
	
	if (inUse != imageWasInUse)
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXImageSourceEnumeratorDidChangeCountNotification object:self];
}


- (NSArray *)imageIdentifiersInUse
{
	NSArray	*imageIdentifiersInUse = nil;
	
	[inUseLock lock];
	
		imageIdentifiersInUse = [identifiersInUse copy];
	
	[inUseLock unlock];
	
	return [imageIdentifiersInUse autorelease];
}


- (void)pause
{
	if (resumeTimer)
	{
		[resumeTimer invalidate];
		[resumeTimer release];
		resumeTimer = nil;
		
		pausing = NO;
		paused = YES;
	}
	else
		pausing = YES;
}


- (void)pauseForEditing
{
	if ([self isEnumerating])
	{
		[self pause];
		do
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		while ([self isEnumerating]);
	}
	
	if (resumeTimer)
	{
		[resumeTimer invalidate];
		[resumeTimer release];
	}
	
	resumeTimer = [[NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(resumeWithTimer:) userInfo:nil repeats:NO] retain];
}


- (void)resumeWithTimer:(NSTimer *)timer
{
	[resumeTimer release];
	resumeTimer = nil;
	
	[self resume];
}


- (void)resume
{
	if ([imageSource settingsAreValid] && (!paused || [workingImageSource hasMoreImages]))
	{
		pausing = NO;
		paused = NO;
		[NSApplication detachDrawingThread:@selector(enumerateImageSourceInNewThread) 
								  toTarget:self 
								withObject:nil];
	}
}


- (BOOL)isEnumerating
{
	return !paused;
}


- (void)setIsOnProbation:(BOOL)flag
{
	if (onProbation != flag)
	{
		[probationLock lock];
		
			onProbation = flag;
			
			if (onProbation)
			{
				[probationStartDate release];
				probationStartDate = [[NSDate date] retain];
			}
			else
			{
				[probationStartDate release];
				probationStartDate = nil;
				
				[probationaryImageQueue clear];
			}
			
		[probationLock unlock];
	}
}


- (BOOL)isOnProbation
{
	BOOL	flag;
	
	[probationLock lock];
	
			// Check if the probation period is over.
		if (onProbation && [probationStartDate timeIntervalSinceNow] < -60)
			[self setIsOnProbation:NO];
		
		flag = onProbation;
		
	[probationLock unlock];
	
	return flag;
}


- (void)rememberProbationaryImage:(MacOSaiXSourceImage *)image
{
	[probationLock lock];
		
		if (onProbation)
			[probationaryImageQueue pushImage:image];
		
	[probationLock unlock];
}


- (MacOSaiXImageQueue *)probationaryImageQueue
{
	return probationaryImageQueue;
}


- (void)reset
{
	if (!paused)
		[NSException raise:@"Enumeration Exception" format:@"Enumerator not paused when reset"];
	
	[imageSource reset];
	
	[workingImageSource release];
	workingImageSource = [imageSource copyWithZone:[self zone]];
	
	[inUseLock lock];
		[identifiersInUse removeAllObjects];
	[inUseLock unlock];

	[self setNumberOfImagesFound:0];
}


- (void)enumerateImageSourceInNewThread
{
	NSAutoreleasePool	*threadPool = [[NSAutoreleasePool alloc] init];
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
		// Check if the source has any images left.
	BOOL				sourceHasMoreImages = [workingImageSource hasMoreImages];
	
	while (!pausing && sourceHasMoreImages)
	{
		NSAutoreleasePool		*sourcePool = [[NSAutoreleasePool alloc] init];
		NSImage					*image = nil;
		NSString				*imageIdentifier = nil;
		BOOL					imageIsValid = NO;
		
		NS_DURING
				// Get the next image from the source (and identifier if there is one)
			image = [workingImageSource nextImageAndIdentifier:&imageIdentifier];
			
			imageIsValid = [image isValid];
		NS_HANDLER
			#ifdef DEBUG
				NSLog(@"Exception raised while getting the next image (%@)", localException);
			#endif
		NS_ENDHANDLER
		
		MacOSaiXEnumeratedImage	*sourceImage = [MacOSaiXEnumeratedImage imageWithIdentifier:imageIdentifier fromEnumerator:self];
		
		if (image && imageIsValid && 
			![[mosaic disallowedImages] containsObject:sourceImage] && 
			![[(MacOSaiX *)[NSApp delegate] disallowedImages] containsObject:sourceImage])
		{
				// Set the caching behavior of the image.  We'll be adding bitmap representations of various sizes to the image so it doesn't need to do any of its own caching.
			[image setCachedSeparately:YES];
			[image setCacheMode:NSImageCacheNever];
			
				// Ignore whatever DPI was set for the image.  We just care about the bitmap dimensions.
			NSImageRep	*targetRep = [[image representations] objectAtIndex:0];
			[targetRep setSize:NSMakeSize([targetRep pixelsWide], [targetRep pixelsHigh])];
			[image setSize:NSMakeSize([targetRep pixelsWide], [targetRep pixelsHigh])];
			
			if ([image size].width >= 16.0 && [image size].height >= 16.0)
			{
					// This image is a reasonable size.
				imagesFound++;
				
				[[MacOSaiXImageCache sharedImageCache] cacheImage:image 
												   withIdentifier:imageIdentifier 
													   fromSource:workingImageSource];
				
				[mosaic addSourceImageToQueue:sourceImage];
			}
		}
		
		sourceHasMoreImages = [workingImageSource hasMoreImages];
		
		[sourcePool release];
	}
	
	paused = YES;
	
	[threadPool release];
}


- (void)dealloc
{
	[[MacOSaiXImageCache sharedImageCache] removeCachedImagesFromSource:imageSource];
	[imageSource release];
	[workingImageSource release];
	
	[inUseLock release];
	[identifiersInUse release];
	
	[probationStartDate release];
	[probationaryImageQueue release];
	
	if (resumeTimer)
	{
		[resumeTimer invalidate];
		[resumeTimer release];
	}
	
    [super dealloc];
}


@end

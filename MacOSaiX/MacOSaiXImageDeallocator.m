//
//  MacOSaiXImageDeallocator.m
//  MacOSaiX
//
//  Created by Frank Midgley on 9/10/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "MacOSaiXImageDeallocator.h"


static NSLock		*sLock = nil;
static NSMutableSet	*sImagesToDeallocate = nil;
static BOOL			sTryAgain = NO;

@implementation MacOSaiXImageDeallocator


+ (void)initialize
{
    sLock = [[NSLock alloc] init];
    sImagesToDeallocate = [[NSMutableSet set] retain];
}


+ (void)deallocateImageOnMainThread:(NSImage *)image
{
	return;
	
    [sLock lock];
//		NSLog(@"Making sure NSImage @ %p gets dealloc'd on the main thread.", image);
        [sImagesToDeallocate addObject:image];
        
        if (sTryAgain || [sImagesToDeallocate count] == 1)
            [self performSelectorOnMainThread:@selector(deallocateImages) withObject:nil waitUntilDone:NO];
    [sLock unlock];
}


+ (void)deallocateImages
{
    [sLock lock];
        NSEnumerator    *imageEnumerator = [sImagesToDeallocate objectEnumerator];
        NSImage            *image = nil;
        
            // If we're the only one still holding onto to the image then it's safe to release it.
        while (image = [imageEnumerator nextObject])
            if ([image retainCount] == 1)
                [sImagesToDeallocate removeObject:image];
		
		sTryAgain = ([sImagesToDeallocate count] > 0);
    [sLock unlock];
}


@end

#pragma mark


@interface MacOSaiXImage : NSImage {}
@end

@implementation MacOSaiXImage

+ (void)load
{
    [self poseAsClass:[NSImage class]];
}

//- (id)retain
//{
//    if (!pthread_main_np())
//        NSLog(@"retaining off the main thread");
//    return [super retain];
//}

- (id)autorelease
{
    if (!pthread_main_np() && ([NSBundle bundleForClass:[self class]] == [NSBundle mainBundle]))
        NSLog(@"autoreleasing off the main thread");
    return [super autorelease];
}

- (oneway void)release
{
    if (!pthread_main_np() && ([NSBundle bundleForClass:[self class]] == [NSBundle mainBundle]))
        NSLog(@"releasing off the main thread");
    [super release];
}

- (void)dealloc
{
    if (!pthread_main_np())		//&& ([NSBundle bundleForClass:[self class]] == [NSBundle mainBundle]))
        NSLog(@"dealloc'ing off the main thread");
	
    [super dealloc];
}

@end

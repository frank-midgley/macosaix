//
//  MacOSaiXImageDeallocator.h
//  MacOSaiX
//
//  Created by Frank Midgley on 9/10/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXImageDeallocator : NSObject
{
}

+ (void)deallocateImageOnMainThread:(NSImage *)image;

@end

//
//  TileImage.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sun Mar 24 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "TileImage.h"


@implementation TileImage

- (id)initWithImageURL:(NSURL *)imageURL bitmapRep:(NSBitmapImageRep *)imageRep
{
    [super init];
    _imageURL = [imageURL retain];
    _imageRep = [imageRep retain];
    _displayUseCount = 0;
    _possibleUseCount = 0;
    return self;
}


- (void)imageInUse { _displayUseCount++; }
- (void)imageNotInUse { _displayUseCount--; }
- (void)imageMightBeUsed { _possibleUseCount++; }
- (void)imageWontBeUsed { _possibleUseCount--; }


- (void)dealloc
{
    [_imageURL release];
    [_imageRep release];
}

@end

//
//  TileImage.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sun Mar 24 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface TileImage : NSObject {
    NSURL		*_imageURL;
    int			_displayUseCount;
    int			_possibleUseCount;
    NSBitmapImageRep	*_imageRep;
}

- (id)initWithImageURL:(NSURL *)imageURL bitmapRep:(NSBitmapImageRep *)imageRep;
- (void)imageInUse;
- (void)imageNotInUse;
- (void)imageMightBeUsed;
- (void)imageWontBeUsed;

@end

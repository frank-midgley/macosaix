//
//  ImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Wed Mar 13 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface ImageSource : NSObject {
    BOOL	_hasMoreImages;
    int		_imageCount;
}

- (id)initWithObject:(id)theObject;
- (NSImage *)typeImage;
- (NSString *)descriptor;
- (NSURL *)nextImageURL;
- (int)imageCount;

@end

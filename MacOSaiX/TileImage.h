//
//  TileImage.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sun Mar 24 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "ImageSource.h"

@interface TileImage : NSObject <NSCoding>
{
	ImageSource	*_imageSource;
	int			_useCount;
    id			_imageIdentifier;
    NSImage		*_image;
}

+ (void)initialize;
- (id)initWithIdentifier:(id)identifier fromImageSource:(ImageSource *)imageSource;

- (ImageSource *)imageSource;
- (id)imageIdentifier;

- (NSImage *)image;

- (void)removeImageFromCache;

- (void)imageIsInUse;
- (BOOL)imageIsNotInUse;

@end

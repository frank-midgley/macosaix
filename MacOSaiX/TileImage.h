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

@interface TileImage : NSObject <NSCoding> {
    int		_imageSourceIndex, _useCount;
    id		_imageIdentifier;
    NSImage	*_image;
}

+ (void)initialize;
- (id)initWithIdentifier:(id)identifier fromImageSourceIndex:(int)sourceIndex;

- (int)imageSourceIndex;
- (id)imageIdentifier;

- (NSImage *)imageFromSources:(NSArray *)imageSources;

- (void)removeImageFromCache;

- (void)imageIsInUse;
- (BOOL)imageIsNotInUse;

@end

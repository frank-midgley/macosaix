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
	ImageSource	*imageSource;
    id			imageIdentifier;
	int			useCount;
    NSImage		*image,
				*thumbnail;
}

+ (void)initialize;
- (id)initWithIdentifier:(id)identifier fromImageSource:(ImageSource *)imageSource;

- (ImageSource *)imageSource;
- (id)imageIdentifier;

- (NSImage *)image;
- (NSImage *)thumbnail;

- (void)imageIsInUse;
- (BOOL)imageIsNotInUse;

@end

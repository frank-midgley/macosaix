//
//  MosaicView.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface MosaicView : NSImageView
{
    NSImage*	_image;
}

- (id)initWithFrame:(NSRect)frame;
- (void)setImage:(NSImage*)image;
- (void)drawRect:(NSRect)rect;

@end

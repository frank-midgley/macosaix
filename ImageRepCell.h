//
//  ImageRepCell.h
//  MacOSaiX
//
//  Created by Frank Midgley on Tue Mar 26 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface ImageRepCell : NSCell {
    NSImageRep	*_imageRep;
}

- (void)setImageRep:(NSImageRep *)imageRep;
- (void)drawWithFrame:(NSRect)frameRect inView:(NSView *)controlView;

@end

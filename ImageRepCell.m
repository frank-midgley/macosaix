//
//  ImageRepCell.m
//  MacOSaiX
//
//  Created by Frank Midgley on Tue Mar 26 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "ImageRepCell.h"


@implementation ImageRepCell

- (BOOL)isFlipped
{
    return NO;
}


- (void)setImageRep:(NSImageRep *)imageRep
{
    if (_imageRep != nil) [_imageRep autorelease];
    _imageRep = imageRep;
}


- (void)drawWithFrame:(NSRect)frameRect inView:(NSView *)controlView
{
/*    NSAffineTransform	*transform = [NSAffineTransform transform];
    
    [NSGraphicsContext saveGraphicsState];
	//[transform scaleXBy:1.0 yBy:-1.0];
	[transform translateXBy:0 yBy:-5];	//frameRect.origin.x * -1 yBy:frameRect.origin.y * -1];
	[transform set];
	[_imageRep drawInRect:frameRect];   //NSMakeRect(0, 0, frameRect.size.width, frameRect.size.height)];
    [NSGraphicsContext restoreGraphicsState];*/
    
    NSImage	*image = [[NSImage alloc] initWithSize:[_imageRep size]];
    
    [super drawWithFrame:frameRect inView:controlView];
    
    [image lockFocus];
    [_imageRep drawInRect:NSMakeRect(0, 0, [image size].width, [image size].height)];
    [image unlockFocus];
    [image compositeToPoint:frameRect.origin operation:NSCompositeCopy];
    [image autorelease];
}

@end

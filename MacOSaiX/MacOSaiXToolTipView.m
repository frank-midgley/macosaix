//
//  MacOSaiXToolTipView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/14/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXToolTipView.h"


@interface NSColor (MacOSaiX)
+ (NSColor *)toolTipColor;
@end


@implementation MacOSaiXToolTipView


- (void)drawRect:(NSRect)rect
{
	[[[NSColor yellowColor] highlightWithLevel:0.75] set];
	NSRectFill(rect);
	
	[[NSColor lightGrayColor] set];
	NSFrameRect([self bounds]);
}


@end

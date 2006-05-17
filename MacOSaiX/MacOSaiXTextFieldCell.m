//
//  MacOSaiXTextFieldCell.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/16/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "MacOSaiXTextFieldCell.h"


@implementation MacOSaiXTextFieldCell


- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize	textSize = [[(NSTextField *)controlView attributedStringValue] size];
	
	if (textSize.width < NSWidth(cellFrame))
		cellFrame = NSInsetRect(cellFrame, 0.0, (NSHeight(cellFrame) - textSize.height) / 2.0);
	
	[super drawWithFrame:cellFrame inView:controlView];
}


@end

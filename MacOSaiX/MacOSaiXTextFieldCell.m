//
//  MacOSaiXTextFieldCell.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/16/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTextFieldCell.h"


@implementation MacOSaiXTextFieldCell


- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize	textSize = [[self attributedStringValue] size];
	
	if (textSize.width < NSWidth(cellFrame))
		cellFrame = NSInsetRect(cellFrame, 0.0, (NSHeight(cellFrame) - textSize.height) / 2.0);
	
	[super drawWithFrame:cellFrame inView:controlView];
}


- (void)highlight:(BOOL)flag withFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize	textSize = [[self attributedStringValue] size];
	
	if (textSize.width < NSWidth(cellFrame))
		cellFrame = NSInsetRect(cellFrame, 0.0, (NSHeight(cellFrame) - textSize.height) / 2.0);
	
	[super highlight:flag withFrame:cellFrame inView:controlView];
}


@end

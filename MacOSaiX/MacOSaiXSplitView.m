//
//  MacOSaiXSplitView.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/3/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXSplitView.h"


@implementation MacOSaiXSplitView


- (void)setAdjustsLastViewOnly:(BOOL)flag
{
	adjustsLastViewOnly = flag;
}


- (BOOL)adjustsLastViewOnly
{
	return adjustsLastViewOnly;
}


- (void)adjustSubviews
{
	if (adjustsLastViewOnly)
	{
		NSEnumerator	*subViewEnumerator = [[self subviews] objectEnumerator];
		NSView			*subView = nil, 
						*lastSubView = [[self subviews] lastObject];
		NSRect			selfBounds = [self bounds], 
						lastSubViewFrame = NSZeroRect;
		
		lastSubViewFrame.origin.x -= [self dividerThickness];
		
		while (subView = [subViewEnumerator nextObject])
		{
			NSRect	subViewFrame = [subView frame];
			
			subViewFrame.origin.x = NSMaxX(lastSubViewFrame) + [self dividerThickness];
			subViewFrame.size.height = NSHeight(selfBounds);
			
			if (subView == lastSubView)
				subViewFrame.size.width = NSMaxX(selfBounds) - NSMinX(subViewFrame);
			
			[subView setFrame:subViewFrame];
			
			lastSubViewFrame = subViewFrame;
		}
		
		// TODO: handle vertical frames
	}
	else
		[super adjustSubviews];
}


@end

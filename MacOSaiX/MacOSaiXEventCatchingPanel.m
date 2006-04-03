//
//  MacOSaiXEventCatchingPanel.m
//  MacOSaiX
//
//  Created by Frank Midgley on 4/2/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEventCatchingPanel.h"


@implementation MacOSaiXEventCatchingPanel

- (void)sendEvent:(NSEvent *)event
{
	if (event)
		[super sendEvent:event];
	
	if ([[self delegate] respondsToSelector:@selector(windowEventDidOccur:)])
		[[self delegate] windowEventDidOccur:event];
}


@end

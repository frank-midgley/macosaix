//
//  MacOSaiXFullScreenWindow.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/13/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXFullScreenWindow.h"

#import "MacOSaiXFullScreenController.h"


@implementation MacOSaiXFullScreenWindow


- (BOOL)canBecomeKeyWindow
{
	return YES;
}


- (void)sendEvent:(NSEvent *)theEvent
{
	if ([(MacOSaiXFullScreenController *)[self windowController] closesOnKeyPress] && [theEvent type] == NSKeyDown)
		[self close];
	else
		[super sendEvent:theEvent];
}


@end

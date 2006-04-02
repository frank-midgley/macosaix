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
	NSWindowController	*controller = [self windowController];
	
	if ([controller isKindOfClass:[MacOSaiXFullScreenController class]] && 
		[(MacOSaiXFullScreenController *)controller closesOnKeyPress] && 
		[theEvent type] == NSKeyDown)
		[self close];
	else
		[super sendEvent:theEvent];
}


@end

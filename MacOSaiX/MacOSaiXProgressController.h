//
//  MacOSaiXProgressController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 6/24/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXProgressController : NSWindowController
{
	IBOutlet NSTextField			*messageField;
	IBOutlet NSProgressIndicator	*progressIndicator;
	IBOutlet NSButton				*cancelButton;
}

- (void)displayPanelWithMessage:(NSString *)message modalForWindow:(NSWindow *)window;
- (void)setPercentComplete:(NSNumber *)percentComplete;
- (void)setMessage:(NSString *)message, ...;
- (void)setCancelTarget:(id)target action:(SEL)action;
- (void)closePanel;

@end

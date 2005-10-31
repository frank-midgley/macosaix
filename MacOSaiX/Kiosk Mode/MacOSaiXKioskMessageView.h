//
//  MacOSaiXKioskMessageView.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/30/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXKioskMessageView : NSView
{
	NSTextView	*textView;
	NSColor		*backgroundColor;
}

- (void)setEditable:(BOOL)flag;
- (BOOL)isEditable;

- (void)setBackgroundColor:(NSColor *)color;
- (NSColor *)backgroundColor;

- (void)setMessage:(NSAttributedString *)message;
- (NSAttributedString *)message;

@end

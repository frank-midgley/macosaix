//
//  MacOSaiXPopUpButton.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/11/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//


@interface MacOSaiXPopUpButton : NSButton
{
	NSColor		*indicatorColor;
}

- (void)addItemWithTitle:(NSString *)title;
- (NSMenuItem *)lastItem;
- (void)removeAllItems;

- (void)setIndicatorColor:(NSColor *)color;
- (NSColor *)indicatorColor;

@end

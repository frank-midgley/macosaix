//
//  MacOSaiXPopUpImageView.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/11/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXPopUpImageView : NSControl
{
	NSImage	*popUpImage;
	NSMenu	*popUpMenu;
}

- (void)setImage:(NSImage *)image;
- (NSImage *)image;
- (void)setMenu:(NSMenu *)menu;
- (NSMenu *)menu;

@end

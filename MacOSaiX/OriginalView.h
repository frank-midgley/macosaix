//
//  OriginalView.h
//  MacOSaiX
//
//  Created by Frank Midgley on Fri Mar 22 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface OriginalView : NSImageView
{
    NSRect		_focusRect;	// the portion of the original image displayed in the mosaic view
    NSBezierPath	*_tileOutlines;
    BOOL		_displayTileOutlines;
}

- (id)init;
- (void)setTileOutlines:(NSBezierPath *)tileOutlines;
- (void)setDisplayTileOutlines:(BOOL)displayTileOutlines;
- (void)setFocusRect:(NSRect)focusRect;
- (void)drawRect:(NSRect)theRect;

@end

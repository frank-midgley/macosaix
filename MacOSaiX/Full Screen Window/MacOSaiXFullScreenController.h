//
//  MacOSaiXFullScreenController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/8/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXMosaic.h"
#import "MosaicView.h"


@interface MacOSaiXFullScreenController : NSWindowController
{
	IBOutlet MosaicView	*mosaicView;
	
	BOOL				closesOnKeyPress;
}

- (void)setMosaicView:(MosaicView *)view;
- (void)setMosaic:(MacOSaiXMosaic *)mosaic;

- (void)setClosesOnKeyPress:(BOOL)flag;
- (BOOL)closesOnKeyPress;

@end

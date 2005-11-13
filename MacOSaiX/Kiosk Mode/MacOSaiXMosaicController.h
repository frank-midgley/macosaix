//
//  MacOSaiXMosaicController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/8/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXMosaic.h"
#import "MosaicView.h"


@interface MacOSaiXMosaicController : NSWindowController
{
	IBOutlet MosaicView	*mosaicView;
}

- (void)setMosaic:(MacOSaiXMosaic *)mosaic;

@end

//
//  MacOSaiXKioskView.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/11/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MosaicView.h"


@interface MacOSaiXKioskView : NSView
{
	IBOutlet NSMatrix		*originalImageMatrix;
	IBOutlet MosaicView		*mosaicView;
	IBOutlet NSView			*imageSourcesView;
}

@end

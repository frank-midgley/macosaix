//
//  MacOSaiXKioskView.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/11/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MosaicView;


@interface MacOSaiXKioskView : NSView
{
	IBOutlet NSMatrix		*targetImageMatrix;
	IBOutlet MosaicView		*mosaicView;
	IBOutlet NSView			*imageSourcesView;

	int						tileCount;
}

- (void)setTileCount:(int)count;

@end

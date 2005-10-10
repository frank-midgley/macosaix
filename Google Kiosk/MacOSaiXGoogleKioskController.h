//
//  MacOSaiXGoogleKioskController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 9/26/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXMosaic.h"
#import "MosaicView.h"


@interface MacOSaiXGoogleKioskController : NSWindowController
{
	IBOutlet NSMatrix		*originalImageMatrix;
	IBOutlet NSImageView	*customImageView;
	IBOutlet MosaicView		*mosaicView;
	IBOutlet NSBox			*googleBox;
	IBOutlet NSTextField	*keywordTextField;
	IBOutlet NSButton		*addKeywordButton,
							*removeKeywordButton;
	IBOutlet NSTableView	*imageSourcesTableView;
	
	MacOSaiXMosaic			*mosaic;
	NSMutableArray			*originalImages;
}

- (IBAction)setOriginalImage:(id)sender;
- (IBAction)addKeyword:(id)sender;
- (IBAction)removeKeyword:(id)sender;

@end

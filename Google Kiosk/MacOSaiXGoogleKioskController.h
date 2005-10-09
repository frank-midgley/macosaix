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
	IBOutlet NSImageView	*googleImageView;
	IBOutlet MosaicView		*mosaicView;
	IBOutlet NSTextField	*keywordTextField;
	IBOutlet NSButton		*addKeywordButton,
							*removeKeywordButton;
	IBOutlet NSTableView	*imageSourcesTableView;
	
	MacOSaiXMosaic			*mosaic;
}

- (IBAction)setOriginalImage:(id)sender;
- (IBAction)addKeyword:(id)sender;
- (IBAction)removeKeyword:(id)sender;

@end

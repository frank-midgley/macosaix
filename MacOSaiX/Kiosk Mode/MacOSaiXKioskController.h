//
//  MacOSaiXKioskController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 9/26/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXKioskView.h"
#import "MacOSaiXMosaic.h"
#import "MosaicView.h"


@interface MacOSaiXKioskController : NSWindowController
{
		// The six top level views
	IBOutlet MacOSaiXKioskView	*kioskView;	// content view of the window
	IBOutlet NSMatrix			*originalImageMatrix;
	IBOutlet NSTextField		*customTextField;
	IBOutlet NSBox				*vanityView;
	IBOutlet MosaicView			*mosaicView;
	IBOutlet NSBox				*imageSourcesView;
	
		// Views inside the image sources box.
	IBOutlet NSTextField		*keywordTextField;
	IBOutlet NSButton			*addKeywordButton,
								*removeKeywordButton;
	IBOutlet NSTableView		*imageSourcesTableView;
	
		// Model objects
	MacOSaiXMosaic				*mosaic;
	NSMutableArray				*originalImages;
	
	NSMutableArray				*tilesToRefresh;
	NSLock						*tileRefreshLock;
	int							refreshTilesThreadCount;
}

- (IBAction)setOriginalImage:(id)sender;
- (IBAction)addKeyword:(id)sender;
- (IBAction)removeKeyword:(id)sender;

@end

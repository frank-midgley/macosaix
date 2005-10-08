//
//  MacOSaiXGoogleKioskController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 9/26/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MosaicView.h"


@interface MacOSaiXGoogleKioskController : NSWindowController
{
	IBOutlet NSMatrix	*originalImageMatrix,
						*keywordMatrix;
	IBOutlet NSButton	*chooseAllButton,
						*chooseNoneButton;
	IBOutlet MosaicView	*mosaicView;
	
	NSMutableDictionary	*imageSources;
}

- (IBAction)setOriginalImage:(id)sender;
- (IBAction)toggleKeyword:(id)sender;

@end

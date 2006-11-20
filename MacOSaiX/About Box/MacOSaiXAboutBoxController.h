//
//  MacOSaiXAboutBoxController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 11/16/06.
//  Copyright 2006 Frank M. Midgley.  All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>

@class MosaicView;


@interface MacOSaiXAboutBoxController : NSWindowController <ABImageClient>
{
	IBOutlet NSTextField	*versionField;
	IBOutlet NSButton		*homePageButton;
	IBOutlet MosaicView		*mosaicView;
	
	NSMutableDictionary		*personImages, 
							*personTags;
	
	int						lastTileChangeCount;
}

- (IBAction)openHomePage:(id)sender;

@end

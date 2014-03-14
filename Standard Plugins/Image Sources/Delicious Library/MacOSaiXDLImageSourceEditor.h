//
//  MacOSaiXDLImageSourceEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 15 2008.
//  Copyright (c) 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSource.h"
#import "MacOSaiXDLImageSource.h"


@interface MacOSaiXDLImageSourceEditor : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView					*editorView;
	
	IBOutlet NSTabView				*tabView;
	
	IBOutlet NSImageView			*iconView;
	IBOutlet NSButton				*reloadButton;
	IBOutlet NSMatrix				*sourceTypeMatrix;
	IBOutlet NSPopUpButton			*itemTypesPopUp, 
									*shelvesPopUp;
	IBOutlet NSTextField			*itemCountField, 
									*errorField;
	IBOutlet NSProgressIndicator	*loadingIndicator;
	
	MacOSaiXDLImageSource			*currentImageSource;
}

- (IBAction)reloadLibrary:(id)sender;

- (IBAction)setSourceType:(id)sender;
- (IBAction)setItemType:(id)sender;
- (IBAction)setShelf:(id)sender;

- (IBAction)visitWebSite:(id)sender;

@end

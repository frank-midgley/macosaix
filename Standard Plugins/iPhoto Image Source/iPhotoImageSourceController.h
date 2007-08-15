//
//  MacOSaiXiPhotoImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Mar 15 2005.
//  Copyright (c) 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXPlugIn.h"

@class MacOSaiXiPhotoImageSource;


@interface MacOSaiXiPhotoImageSourceEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>	delegate;
	
	IBOutlet NSView				*editorView;

	IBOutlet NSPopUpButton		*sourceTypePopUp;
	IBOutlet NSTableView		*tableView;
	
		// The image source instance currently being edited.
	MacOSaiXiPhotoImageSource	*currentImageSource;
	
	NSMutableArray				*albumNames, 
								*keywordNames;
}

- (IBAction)setSourceType:(id)sender;

@end

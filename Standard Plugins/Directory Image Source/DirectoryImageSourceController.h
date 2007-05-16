//
//  DirectoryImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2005 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXDirectoryImageSource;


@interface MacOSaiXDirectoryImageSourceEditor : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>		delegate;
	
	IBOutlet NSView					*editorView;
	
	IBOutlet NSPopUpButton			*folderPopUp;
	IBOutlet NSImageView			*locationImageView;
	IBOutlet NSTextField			*locationTextField, 
									*imageCountTextField;
	IBOutlet NSButton				*followsAliasesButton;
	
		// The image source instance currently being edited.
	MacOSaiXDirectoryImageSource	*currentImageSource;
}

- (IBAction)chooseFolder:(id)sender;
- (IBAction)clearFolderList:(id)sender;
- (IBAction)setFollowsAliases:(id)sender;

@end

//
//  DirectoryImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2005 Frank M. Midgley. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MacOSaiXImageSource.h"
#import "DirectoryImageSource.h"


@interface DirectoryImageSourceController : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView			*editorView;
	
	IBOutlet NSTableView	*folderTableView;
	IBOutlet NSButton		*chooseFolderButton, 
							*clearFolderListButton, 
							*followsAliasesButton;
	
	NSMutableArray			*folderList;
	
		// The image source instance currently being edited.
	DirectoryImageSource	*currentImageSource;
}

- (IBAction)chooseFolder:(id)sender;
- (IBAction)clearFolderList:(id)sender;
- (IBAction)setFollowsAliases:(id)sender;

@end

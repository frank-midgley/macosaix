//
//  DirectoryImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MacOSaiXImageSource.h"
#import "DirectoryImageSource.h"


@interface DirectoryImageSourceController : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView			*editorView;

	IBOutlet NSImageView	*pathComponent1ImageView,
							*pathComponent2ImageView,
							*pathComponent3ImageView,
							*pathComponent4ImageView,
							*pathComponent5ImageView;
	IBOutlet NSTextField	*pathComponent1TextField,
							*pathComponent2TextField,
							*pathComponent3TextField,
							*pathComponent4TextField,
							*pathComponent5TextField;
	IBOutlet NSButton		*changeDirectoryButton;
	
		// The image source instance currently being edited.
	DirectoryImageSource	*currentImageSource;
}

- (IBAction)chooseDirectory:(id)sender;

@end

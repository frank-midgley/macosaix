//
//  MacOSaiXWatchedFolderImageSourceEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSource.h"

@class MacOSaiXKioskMessageView, MacOSaiXWatchedFolderImageSource;


@interface MacOSaiXWatchedFolderImageSourceEditor : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView						*editorView;
	
	IBOutlet NSTextField				*watchedFolderField;
	IBOutlet NSButton					*chooseFolderButton;
	IBOutlet MacOSaiXKioskMessageView	*messageView;
	IBOutlet NSSlider					*durationSlider;
	
		// The image source instance currently being edited.
	MacOSaiXWatchedFolderImageSource	*currentImageSource;
}

- (IBAction)chooseFolder:(id)sender;

@end

//
//  iTunesImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on May 18 2006.
//  Copyright (c) 2006 Frank M. Midgley. All rights reserved.
//

#import "iTunesImageSource.h"


@interface MacOSaiXiTunesImageSourceController : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView				*editorView;

	IBOutlet NSImageView		*iconView;
	IBOutlet NSMatrix			*matrix;
	IBOutlet NSPopUpButton		*playlistsPopUp;
	
		// The image source instance currently being edited.
	MacOSaiXiTunesImageSource	*currentImageSource;
}

- (IBAction)setSourceType:(id)sender;
- (IBAction)chooseAllTracks:(id)sender;
- (IBAction)choosePlaylist:(id)sender;

@end

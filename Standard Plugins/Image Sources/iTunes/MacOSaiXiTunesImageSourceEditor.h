//
//  MacOSaiXiTunesImageSourceEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on Mar 15 2005.
//  Copyright (c) 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXiTunesImageSource.h"


@interface MacOSaiXiTunesImageSourceEditor : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView				*editorView;

	IBOutlet NSImageView		*iconView;
	IBOutlet NSMatrix			*sourceTypeMatrix;
	IBOutlet NSPopUpButton		*playlistPopUp;
	NSMutableArray				*playlistNames;
	
		// The image source instance currently being edited.
	MacOSaiXiTunesImageSource	*currentImageSource;
}

- (IBAction)setSourceType:(id)sender;
- (IBAction)setPlaylist:(id)sender;

@end

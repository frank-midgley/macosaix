//
//  MacOSaiXiPhotoImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Mar 15 2005.
//  Copyright (c) 2005 Frank M. Midgley. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MacOSaiXImageSource.h"
#import "iPhotoImageSource.h"


@interface MacOSaiXiPhotoImageSourceController : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView				*editorView;

	IBOutlet NSImageView		*iconView;
	IBOutlet NSPopUpButton		*albumsPopUp;
	
	NSButton					*okButton;
	
		// The image source instance currently being edited.
	MacOSaiXiPhotoImageSource	*currentImageSource;
}

- (IBAction)chooseAlbum:(id)sender;

@end

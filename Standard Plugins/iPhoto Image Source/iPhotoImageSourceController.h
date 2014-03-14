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
	IBOutlet NSMatrix			*matrix;
	IBOutlet NSPopUpButton		*albumsPopUp,
								*keywordsPopUp, 
								*eventsPopUp;
	
		// The image source instance currently being edited.
	MacOSaiXiPhotoImageSource	*currentImageSource;
}

- (IBAction)setSourceType:(id)sender;
- (IBAction)chooseAllPhotos:(id)sender;
- (IBAction)chooseAlbum:(id)sender;
- (IBAction)chooseKeyword:(id)sender;
- (IBAction)chooseEvent:(id)sender;

@end

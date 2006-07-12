//
//  iSightImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Jun 19 2006.
//  Copyright (c) 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSource.h"
#import "iSightImageSource.h"


@interface MacOSaiXiSightImageSourceController : NSObject <MacOSaiXImageSourceController>
{
	IBOutlet NSView				*editorView;
	
	IBOutlet NSPopUpButton		*sourcePopUp;
	IBOutlet NSImageView		*previewView;
	
	MacOSaiXiSightImageSource	*currentImageSource;
	NSTimer						*previewTimer;
}

- (IBAction)setSource:(id)sender;

@end

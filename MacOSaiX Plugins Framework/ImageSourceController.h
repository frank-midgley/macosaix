//
//  ImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Wed Nov 27 2002.
//  Copyright (c) 2002 Frank Midgley.  All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ImageSource.h"

@interface ImageSourceController : NSObject {
	@private
		void		*_reserved1,	// reserve some space for future needs
					*_reserved2,
					*_reserved3,
					*_reserved4;
	@public
		NSDocument	*_document;
		NSWindow	*_window;
}

- (void)createNewImageSource;
- (BOOL)canHaveMultipleImageSources;
- (void)editImageSource:(ImageSource *)imageSource;

@end

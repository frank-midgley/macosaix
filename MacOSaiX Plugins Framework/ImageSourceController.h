//
//  ImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Wed Nov 27 2002.
//  Copyright (c) 2002 Frank Midgley.  All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ImageSource.h"

@interface ImageSourceController : NSWindowController {
	@private
		void		*_MacOSaiX_reserved1,	// reserve some space for future needs
					*_MacOSaiX_reserved2,
					*_MacOSaiX_reserved3,
					*_MacOSaiX_reserved4;
	@public
		IBOutlet NSView	*_imageSourceView;
}

+ (NSString *)name;
- (NSView *)imageSourceView;
- (void)addImageSource:(id)sender;
- (void)cancelAddImageSource:(id)sender;
- (BOOL)canHaveMultipleImageSources;
- (void)editImageSource:(ImageSource *)imageSource;
- (void)showCurrentImageSources;

@end

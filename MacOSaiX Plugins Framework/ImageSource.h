//
//  ImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Wed Mar 13 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ImageSource : NSObject
{
	@private
		void	*_reserved1,	// reserve some space for future needs
				*_reserved2,
				*_reserved3,
				*_reserved4;
		NSLock	*_pauseLock;
	@public
		int		_imageCount;
}

- (BOOL)canRefetchImages;

	// methods for filling an Image Sources NSTableView
- (NSImage *)image;
- (NSString *)descriptor;

- (BOOL)hasMoreImages;

- (void)pause;
- (void)resume;
- (void)waitWhilePaused;

	// image enumerator
- (id)nextImageIdentifier;

	// return the number of images enumerated
- (int)imageCount;

	// return the image for the given identifier
- (NSImage *)imageForIdentifier:(id)identifier;

@end

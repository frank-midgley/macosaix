//
//  ImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Wed Mar 13 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ImageSource : NSObject <NSCoding> {
	@private
		void	*_reserved1,	// reserve some space for future needs
				*_reserved2,
				*_reserved3,
				*_reserved4;
	@public
		BOOL	_hasMoreImages;
		int		_imageCount;
}

// set up the image source based on data in theObject (usually a NSString)
- (id)initWithObject:(id)theObject;

// methods for filling an Image Sources NSTableView
- (NSImage *)typeImage;
- (NSString *)descriptor;

// image enumerator
- (id)nextImageIdentifier;

// return the number of images enumerated
- (int)imageCount;

// return the image for the given identifier (ususally a NSURL)
- (NSImage *)imageForIdentifier:(id)identifier;

@end

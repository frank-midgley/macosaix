/*
	iPhotoImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 15 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import <Cocoa/Cocoa.h>

#import "MacOSaiXImageSource.h"


@interface MacOSaiXiPhotoImageSource : NSObject <MacOSaiXImageSource>
{
    NSString				*albumName,
							*lastEnumeratedImageName,
							*enumerationRoot;
	NSAttributedString		*albumDescription;
    NSDirectoryEnumerator	*albumEnumerator;
	BOOL					haveMoreImages,
							imagesHaveBeenEnumerated;
}

+ (NSString *)albumsPath;
+ (NSImage *)albumImage;

- (NSString *)albumName;
- (void)setAlbumName:(NSString *)name;

@end

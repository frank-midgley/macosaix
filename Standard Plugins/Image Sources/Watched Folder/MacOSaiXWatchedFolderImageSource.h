/*
	MacOSaiXWatchedFolderImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Oct 17 2007.
	Copyright (c) 2007 Frank M. Midgley. All rights reserved.
*/

#import "MacOSaiXImageSource.h"


@interface MacOSaiXWatchedFolderImageSource : NSObject <MacOSaiXImageSource>
{
    NSString			*folderPath;
	NSImage				*folderImage;
	NSAttributedString	*attributedFolderPath;
	NSMutableSet		*knownSubPaths;
}

- (void)setPath:(NSString *)path;
- (NSString *)path;
- (NSAttributedString *)attributedPath;

@end

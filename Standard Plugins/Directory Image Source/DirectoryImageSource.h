/*
	DirectoryImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

#import <Cocoa/Cocoa.h>

#import "MacOSaiXImageSource.h"


@interface DirectoryImageSource : NSObject <MacOSaiXImageSource>
{
    NSString				*directoryPath;
	NSImage					*directoryImage;
	NSAttributedString		*directoryDescriptor;
    NSDirectoryEnumerator	*directoryEnumerator;
	BOOL					haveMoreImages;
}

- (NSString *)path;
- (void)setPath:(NSString *)path;

@end

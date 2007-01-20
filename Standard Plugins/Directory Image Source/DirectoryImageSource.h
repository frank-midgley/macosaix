/*
	DirectoryImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/


@interface MacOSaiXDirectoryImageSource : NSObject <MacOSaiXImageSource>
{
    NSString				*directoryPath, 
							*lastEnumeratedPath;
	NSImage					*directoryImage;
	NSAttributedString		*directoryDescriptor;
    NSDirectoryEnumerator	*directoryEnumerator;
	BOOL					followAliases, 
							haveMoreImages, 
							pathsHaveBeenEnumerated;
	int						imageCount;
}

- (NSString *)path;
- (void)setPath:(NSString *)path;

- (BOOL)followsAliases;
- (void)setFollowsAliases:(BOOL)flag;

@end

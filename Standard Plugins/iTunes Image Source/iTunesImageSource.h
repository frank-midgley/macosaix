/*
	iTunesImageSource.h
	MacOSaiX

	Created by Frank Midgley on Thu May 18 2006.
	Copyright (c) 2006 Frank M. Midgley. All rights reserved.
*/


@interface MacOSaiXiTunesImageSource : NSObject <MacOSaiXImageSource>
{
    NSString				*playlistName;
	NSAttributedString		*sourceDescription;
    NSMutableArray			*remainingTrackIDs;
}

+ (NSImage *)playlistImage;

- (NSString *)playlistName;
- (void)setPlaylistName:(NSString *)name;

@end

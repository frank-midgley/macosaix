/*
	MacOSaiXiTunesImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 15 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import <Cocoa/Cocoa.h>

#import "MacOSaiXImageSource.h"


@interface MacOSaiXiTunesImageSource : NSObject <MacOSaiXImageSource>
{
    NSString			*playlistName;
	NSAttributedString	*sourceDescription;
    NSMutableArray		*remainingTrackIDs;
	NSMutableDictionary	*artworkChecksums;
}

+ (NSImage *)musicImage;
+ (NSImage *)audiobooksImage;
+ (NSImage *)purchasedImage;
+ (NSImage *)smartPlaylistImage;
+ (NSImage *)playlistImage;

- (NSString *)playlistName;
- (void)setPlaylistName:(NSString *)name;

@end

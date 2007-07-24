/*
	iPhotoImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 15 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "MacOSaiXImageSource.h"


@interface MacOSaiXiPhotoImageSource : NSObject <MacOSaiXImageSource>
{
    NSString			*albumName,
						*keywordName;
	NSAttributedString	*sourceDescription;
    NSMutableArray		*remainingPhotoIDs;
	NSNumber			*imageCount;
}

- (NSString *)albumName;
- (void)setAlbumName:(NSString *)name;

- (NSString *)keywordName;
- (void)setKeywordName:(NSString *)name;

@end

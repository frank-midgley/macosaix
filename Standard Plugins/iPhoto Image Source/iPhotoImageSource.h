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
							*keywordName, 
							*eventName;
	NSAttributedString		*sourceDescription;
    NSMutableArray			*remainingPhotoIDs;
}

- (NSString *)albumName;
- (void)setAlbumName:(NSString *)name;

- (NSString *)keywordName;
- (void)setKeywordName:(NSString *)name;

- (NSString *)eventName;
- (void)setEventName:(NSString *)name;

@end

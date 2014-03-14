//
//  iPhotoDatabase.h
//  MacOSaiX
//
//  Created by Frank Midgley on 7/12/11.
//  Copyright 2011 HHMI Janelia Farm Research Campus. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface MacOSaiXiPhotoDatabase : NSObject
{
@private
	NSImage				*appImage, 
						*albumImage, 
						*keywordImage, 
						*eventImage;
	NSDictionary		*libraryPList, 
						*keywords,	// keys = id's, values = names
						*photos;
	NSArray				*albums, 	// array of dicts
						*events;
};

+ (MacOSaiXiPhotoDatabase *)sharedDatabase;

- (NSImage *)appImage;

- (NSString *)pathOfPhotoWithID:(NSString *)photoID;
- (NSString *)titleOfPhotoWithID:(NSString *)photoID;

- (NSArray *)photoIDs;

- (NSImage *)albumImage;
- (NSArray *)albumNames;
- (NSArray *)photoIDsFromAlbum:(NSString *)albumName;

- (NSImage *)keywordImage;
- (NSArray *)keywordNames;
- (NSArray *)photoIDsForKeyword:(NSString *)keyword;

- (NSImage *)eventImage;
- (NSArray *)eventNames;
- (NSArray *)photoIDsFromEvent:(NSString *)albumName;

@end

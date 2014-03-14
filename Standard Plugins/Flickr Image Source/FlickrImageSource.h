/*
	FlickrImageSource.h
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import <Foundation/Foundation.h>
#import "MacOSaiXImageSource.h"

@class MacOSaiXFlickrGroup;


typedef enum { matchAllTags, matchAnyTags, matchTitlesTagsOrDescriptions } FlickrQueryType;


@interface FlickrImageSource : NSObject <MacOSaiXImageSource>
{
    NSString				*queryString;
	FlickrQueryType			queryType;
	MacOSaiXFlickrGroup		*queryGroup;
	
	BOOL					haveMoreImages;
	NSString				*lastUploadTimeStamp;
	NSMutableArray			*identifierQueue;
}

+ (NSString *)imageCachePath;
+ (void)purgeCache;

+ (void)setMaxCacheSize:(unsigned long long)maxCacheSize;
+ (unsigned long long)maxCacheSize;
+ (void)setMinFreeSpace:(unsigned long long)minFreeSpace;
+ (unsigned long long)minFreeSpace;

+ (NSArray *)favoriteGroups;
+ (void)addFavoriteGroup:(MacOSaiXFlickrGroup *)group;
+ (void)removeFavoriteGroup:(MacOSaiXFlickrGroup *)group;

+ (NSError *)signIn;
+ (void)signOut;
+ (BOOL)signingIn;
+ (BOOL)signedIn;
+ (NSString *)signedInUserName;
+ (NSDictionary *)authenticatedParameters:(NSDictionary *)parameters;
+ (NSError *)errorFromWSMethodResults:(NSDictionary *)resultsDict;

- (void)setQueryString:(NSString *)string;
- (NSString *)queryString;

- (void)setQueryType:(FlickrQueryType)type;
- (FlickrQueryType)queryType;

- (void)setQueryGroup:(MacOSaiXFlickrGroup *)group;
- (MacOSaiXFlickrGroup *)queryGroup;

@end

extern NSString	*MacOSaiXFlickrFavoriteGroupsDidChangeNotification;
extern NSString	*MacOSaiXFlickrShowFavoriteGroupsNotification;
extern NSString	*MacOSaiXFlickrAuthenticationDidChangeNotification;

/*
	FlickrImageSource.h
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "MacOSaiXImageSource.h"


typedef enum { matchAllTags, matchAnyTag, matchTitlesTagsOrDescriptions } FlickrQueryType;


@interface MacOSaiXFlickrImageSource : NSObject <MacOSaiXImageSource>
{
    NSString				*queryString;
	FlickrQueryType			queryType;
	
	BOOL					haveMoreImages;
	NSString				*lastUploadTimeStamp;
	NSMutableArray			*identifierQueue;
}

- (void)setQueryString:(NSString *)string;
- (NSString *)queryString;
- (void)setQueryType:(FlickrQueryType)type;
- (FlickrQueryType)queryType;

@end

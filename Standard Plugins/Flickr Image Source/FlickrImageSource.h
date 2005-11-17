/*
	FlickrImageSource.h
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import <Foundation/Foundation.h>
#import "MacOSaiXImageSource.h"

typedef enum { matchAllTags, matchAnyTags, matchTitlesTagsOrDescriptions } FlickrQueryType;

@interface FlickrImageSource : NSObject <MacOSaiXImageSource>
{
    NSString				*queryString;
	FlickrQueryType			queryType;
	
	int						nextPage;
	NSMutableArray			*identifierQueue;
}

- (void)setQueryString:(NSString *)string;
- (NSString *)queryString;
- (void)setQueryType:(FlickrQueryType)type;
- (FlickrQueryType)queryType;

@end

/*
	GoogleImageSource.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

#import <Foundation/Foundation.h>
#import "MacOSaiXImageSource.h"

typedef enum { anyColorSpace, rgbColorSpace, grayscaleColorSpace, blackAndWhiteColorSpace } GoogleColorSpace;
typedef enum { strictFiltering, moderateFiltering, noFiltering } GoogleAdultContentFiltering;

@interface GoogleImageSource : NSObject <MacOSaiXImageSource>
{
    NSString					*requiredTerms,
								*optionalTerms,
								*excludedTerms,
								*siteString;
	GoogleColorSpace			colorSpace;
	GoogleAdultContentFiltering	adultContentFiltering;
	
	int							startIndex;
	NSMutableString				*urlBase,
								*descriptor;
	NSMutableArray				*imageURLQueue;
}

- (void)setRequiredTerms:(NSString *)terms;
- (NSString *)requiredTerms;
- (void)setOptionalTerms:(NSString *)terms;
- (NSString *)optionalTerms;
- (void)setExcludedTerms:(NSString *)terms;
- (NSString *)excludedTerms;
- (void)setColorSpace:(GoogleColorSpace)inColorSpace;
- (GoogleColorSpace)colorSpace;
- (void)setSiteString:(NSString *)string;
- (NSString *)siteString;
- (void)setAdultContentFiltering:(GoogleAdultContentFiltering)filtering;
- (GoogleAdultContentFiltering)adultContentFiltering;

@end

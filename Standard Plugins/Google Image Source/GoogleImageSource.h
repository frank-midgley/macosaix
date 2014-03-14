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
typedef enum { anyContent, newsContent, faceContent, photoContent } GoogleContentType;
typedef enum { licenseNone, licenseToShare, licenseToModify } GoogleLicenseType;

@interface GoogleImageSource : NSObject <MacOSaiXImageSource>
{
    NSString					*requiredTerms,
								*optionalTerms,
								*excludedTerms,
								*siteString;
	
	GoogleContentType			contentType;
	GoogleColorSpace			colorSpace;
	GoogleAdultContentFiltering	adultContentFiltering;
	GoogleLicenseType			licenseType;
	BOOL						commerciallyLicensed;
	
	NSString					*collectionQueryValue;
	
	int							startIndex;
	NSMutableString				*urlBase,
								*descriptor;
	NSMutableArray				*imageURLQueue;
}

+ (NSArray *)collections;

+ (NSString *)imageCachePath;
+ (void)purgeCache;

+ (void)setMaxCacheSize:(unsigned long long)maxCacheSize;
+ (unsigned long long)maxCacheSize;
+ (void)setMinFreeSpace:(unsigned long long)minFreeSpace;
+ (unsigned long long)minFreeSpace;

- (void)setRequiredTerms:(NSString *)terms;
- (NSString *)requiredTerms;
- (void)setOptionalTerms:(NSString *)terms;
- (NSString *)optionalTerms;
- (void)setExcludedTerms:(NSString *)terms;
- (NSString *)excludedTerms;

- (void)setContentType:(GoogleContentType)type;
- (GoogleContentType)contentType;
- (void)setColorSpace:(GoogleColorSpace)inColorSpace;
- (GoogleColorSpace)colorSpace;
- (void)setSiteString:(NSString *)string;
- (NSString *)siteString;
- (void)setAdultContentFiltering:(GoogleAdultContentFiltering)filtering;
- (GoogleAdultContentFiltering)adultContentFiltering;
- (void)setLicenseType:(GoogleLicenseType)licenseType;
- (GoogleLicenseType)licenseType;
- (void)setCommerciallyLicensed:(BOOL)flag;
- (BOOL)commerciallyLicensed;

- (void)setCollectionQueryValue:(NSString *)value;
- (NSString *)collectionQueryValue;

@end

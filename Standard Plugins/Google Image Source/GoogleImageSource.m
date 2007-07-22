/*
	GoogleImageSource.m
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

#import "GoogleImageSource.h"
#import "GoogleImageSourcePlugIn.h"
#import "GoogleImageSourceController.h"
#import "GooglePreferencesController.h"
#import "NSString+MacOSaiX.h"
#import <CoreFoundation/CFURL.h>


NSString *escapedNSString(NSString *string)
{
	NSString	*escapedString = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, 
																					 NULL, NULL, kCFStringEncodingUTF8);
	return [escapedString autorelease];
}


@interface MacOSaiXGoogleImageSource (PrivateMethods)
- (void)updateQueryAndDescriptor;
@end


@implementation MacOSaiXGoogleImageSource


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


+ (id<MacOSaiXImageSource>)imageSourceForUniversalIdentifier:(id<NSObject,NSCoding,NSCopying>)identifier
{
	return [[[self alloc] init] autorelease];
}


- (id)init
{
	if (self = [super init])
	{
		if ([[NSFileManager defaultManager] fileExistsAtPath:[MacOSaiXGoogleImageSourcePlugIn imageCachePath]])
		{
			imageURLQueue = [[NSMutableArray array] retain];
		}
		else
		{
			[self autorelease];
			self = nil;
		}
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXGoogleImageSource	*copy = [[MacOSaiXGoogleImageSource allocWithZone:zone] init];
	
	[copy setRequiredTerms:requiredTerms];
	[copy setOptionalTerms:optionalTerms];
	[copy setExcludedTerms:excludedTerms];
	[copy setColorSpace:colorSpace];
	[copy setSiteString:siteString];
	[copy setAdultContentFiltering:adultContentFiltering];
	
	return copy;
}


- (BOOL)settingsAreValid
{
	return ([[self requiredTerms] length] > 0 || 
			[[self optionalTerms] length] > 0 || 
			[[self excludedTerms] length] > 0 || 
			[[self siteString] length] > 0);
}


+ (NSString *)settingsExtension
{
	return @"plist";
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	NSMutableDictionary	*settings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithInt:startIndex], @"Page Index", 
										imageURLQueue, @"Image URL Queue", 
										nil];
	
	if ([self requiredTerms])
		[settings setObject:[self requiredTerms] forKey:@"Required Terms"];
	if ([self optionalTerms])
		[settings setObject:[self optionalTerms] forKey:@"Optional Terms"];
	if ([self excludedTerms])
		[settings setObject:[self excludedTerms] forKey:@"Excluded Terms"];
	
	switch ([self colorSpace])
	{
		case anyColorSpace:
			[settings setObject:@"Any" forKey:@"Colorspace"]; break;
		case rgbColorSpace:
			[settings setObject:@"RGB" forKey:@"Colorspace"]; break;
		case grayscaleColorSpace:
			[settings setObject:@"Grayscale" forKey:@"Colorspace"]; break;
		case blackAndWhiteColorSpace:
			[settings setObject:@"Black & White" forKey:@"Colorspace"]; break;
	}
	
	if ([self siteString])
		[settings setObject:[self siteString] forKey:@"Site"];
	
	switch ([self adultContentFiltering])
	{
		case strictFiltering:
			[settings setObject:@"Strict" forKey:@"Adult Content Filtering"]; break;
		case moderateFiltering:
			[settings setObject:@"Moderate" forKey:@"Adult Content Filtering"]; break;
		case noFiltering:
			[settings setObject:@"None" forKey:@"Adult Content Filtering"]; break;
	}
	
	return [settings writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	[self setRequiredTerms:[settings objectForKey:@"Required Terms"]];
	[self setOptionalTerms:[settings objectForKey:@"Optional Terms"]];
	[self setExcludedTerms:[settings objectForKey:@"Excluded Terms"]];
		
	NSString	*colorSpaceValue = [settings objectForKey:@"Colorspace"];
	if ([colorSpaceValue isEqualToString:@"Any"])
		[self setColorSpace:anyColorSpace];
	else if ([colorSpaceValue isEqualToString:@"RGB"])
		[self setColorSpace:rgbColorSpace];
	else if ([colorSpaceValue isEqualToString:@"Grayscale"])
		[self setColorSpace:grayscaleColorSpace];
	else if ([colorSpaceValue isEqualToString:@"Black & White"])
		[self setColorSpace:blackAndWhiteColorSpace];
	
	[self setSiteString:[settings objectForKey:@"Site"]];
	
	NSString	*filterValue = [settings objectForKey:@"Adult Content Filtering"];
	if ([filterValue isEqualToString:@"Strict"])
		[self setAdultContentFiltering:strictFiltering];
	else if ([filterValue isEqualToString:@"Moderate"])
		[self setAdultContentFiltering:moderateFiltering];
	else if ([filterValue isEqualToString:@"None"])
		[self setAdultContentFiltering:noFiltering];
	
	startIndex = [[settings objectForKey:@"Page Index"] intValue];
	imageURLQueue = [[settings objectForKey:@"Image URL Queue"] retain];
	
	[self updateQueryAndDescriptor];
	
	return YES;
}


// deprecated
- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:@"Element Type"];
	
	if ([settingType isEqualToString:@"TERMS"])
	{
		[self setRequiredTerms:[[[settingDict objectForKey:@"REQUIRED"] description] stringByUnescapingXMLEntites]];
		[self setOptionalTerms:[[[settingDict objectForKey:@"OPTIONAL"] description] stringByUnescapingXMLEntites]];
		[self setExcludedTerms:[[[settingDict objectForKey:@"EXCLUDED"] description] stringByUnescapingXMLEntites]];
	}
	else if ([settingType isEqualToString:@"COLOR_SPACE"])
	{
		NSString	*filterValue = [[settingDict objectForKey:@"FILTER"] description];
		
		if ([filterValue isEqualToString:@"ANY"])
			[self setColorSpace:anyColorSpace];
		else if ([filterValue isEqualToString:@"RGB"])
			[self setColorSpace:rgbColorSpace];
		else if ([filterValue isEqualToString:@"GRAYSCALE"])
			[self setColorSpace:grayscaleColorSpace];
		else if ([filterValue isEqualToString:@"B&W"])
			[self setColorSpace:blackAndWhiteColorSpace];
	}
	else if ([settingType isEqualToString:@"SITE"])
		[self setSiteString:[[[settingDict objectForKey:@"FILTER"] description] stringByUnescapingXMLEntites]];
	else if ([settingType isEqualToString:@"ADULT_CONTENT"])
	{
		NSString	*filterValue = [[settingDict objectForKey:@"FILTER"] description];
		
		if ([filterValue isEqualToString:@"STRICT"])
			[self setAdultContentFiltering:strictFiltering];
		else if ([filterValue isEqualToString:@"MODERATE"])
			[self setAdultContentFiltering:moderateFiltering];
		else if ([filterValue isEqualToString:@"NONE"])
			[self setAdultContentFiltering:noFiltering];
	}
	else if ([settingType isEqualToString:@"PAGE"])
		startIndex = [[[settingDict objectForKey:@"INDEX"] description] intValue];
	else if ([settingType isEqualToString:@"QUEUED_IMAGE"])
		[imageURLQueue addObject:[[settingDict objectForKey:@"URL"] description]];
}


// deprecated
- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	// not needed
}


// deprecated
- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
	[self updateQueryAndDescriptor];
}


- (void)updateQueryAndDescriptor
{
	[urlBase autorelease];
	urlBase = [[NSMutableString stringWithString:@"http://images.google.com/images?svnum=10&hl=en&"] retain];
	[descriptor autorelease];
	descriptor = [[NSMutableString string] retain];
	
	if ([requiredTerms length] > 0)
	{
		[urlBase appendString:[NSString stringWithFormat:@"as_q=%@&", escapedNSString(requiredTerms)]];
		[descriptor appendString:@"\""];
		[descriptor appendString:requiredTerms];
		[descriptor appendString:@"\""];
	}
	
	if ([optionalTerms length] > 0)
	{
		[urlBase appendString:[NSString stringWithFormat:@"as_oq=%@&", escapedNSString(optionalTerms)]];
		if ([descriptor length] > 0)
			[descriptor appendString:NSLocalizedString(@" and any of \"", @"")];
		else
			[descriptor appendString:NSLocalizedString(@"Any of \"", @"")];
		[descriptor appendString:optionalTerms];
		[descriptor appendString:@"\""];
	}
	
	if ([excludedTerms length] > 0)
	{
		[urlBase appendString:[NSString stringWithFormat:@"as_eq=%@&", escapedNSString(excludedTerms)]];
		if ([descriptor length] > 0)
			[descriptor appendString:NSLocalizedString(@" but not \"", @"")];
		else
			[descriptor appendString:NSLocalizedString(@"Not \"", @"")];
		[descriptor appendString:excludedTerms];
		[descriptor appendString:@"\""];
	}
	
	switch (colorSpace)
	{
		case anyColorSpace:
			[urlBase appendString:@"imgc=&"];
			break;
		case rgbColorSpace:
			[urlBase appendString:@"imgc=color&"];
			if ([descriptor length] > 0)
				[descriptor appendString:NSLocalizedString(@" color", @"")];
			else
				[descriptor appendString:NSLocalizedString(@"Color", @"")];
			break;
		case grayscaleColorSpace:
			[urlBase appendString:@"imgc=gray&"];
			if ([descriptor length] > 0)
				[descriptor appendString:NSLocalizedString(@" grayscale", @"")];
			else
				[descriptor appendString:NSLocalizedString(@"Grayscale", @"")];
			break;
		case blackAndWhiteColorSpace:
			[urlBase appendString:@"imgc=mono&"];
			if ([descriptor length] > 0)
				[descriptor appendString:NSLocalizedString(@" black & white", @"")];
			else
				[descriptor appendString:NSLocalizedString(@"Black & white", @"")];
			break;
	}
	
	if ([siteString length] > 0)
	{
		[urlBase appendString:[NSString stringWithFormat:@"as_sitesearch=%@&", escapedNSString(siteString)]];
		if ([descriptor length] > 0)
			[descriptor appendString:NSLocalizedString(@" images from ", @"")];
		else
			[descriptor appendString:NSLocalizedString(@"Images from ", @"")];
		[descriptor appendString:siteString];
	}
	else
		[descriptor appendString:NSLocalizedString(@" images", @"")];
	
	switch (adultContentFiltering)
	{
		case strictFiltering:
			[urlBase appendString:@"safe=active&"]; break;
		case moderateFiltering:
			[urlBase appendString:@"safe=images&"]; break;
		case noFiltering:
			[urlBase appendString:@"safe=off&"]; break;
	}
	[urlBase appendString:@"start="];
}


- (void)setRequiredTerms:(NSString *)terms
{
	[requiredTerms autorelease];
	requiredTerms = [terms copy];
	
	[self updateQueryAndDescriptor];
}


- (NSString *)requiredTerms
{
	return requiredTerms;
}


- (void)setOptionalTerms:(NSString *)terms
{
	[optionalTerms autorelease];
	optionalTerms = [terms copy];
	
	[self updateQueryAndDescriptor];
}


- (NSString *)optionalTerms
{
	return optionalTerms;
}


- (void)setExcludedTerms:(NSString *)terms
{
	[excludedTerms autorelease];
	excludedTerms = [terms copy];
	
	[self updateQueryAndDescriptor];
}


- (NSString *)excludedTerms
{
	return excludedTerms;
}


- (void)setKeywords:(NSDictionary *)dictionary
{
	[self setRequiredTerms:[dictionary valueForKey:@"Required Terms"]];
	[self setOptionalTerms:[dictionary valueForKey:@"Optional Terms"]];
	[self setExcludedTerms:[dictionary valueForKey:@"Excluded Terms"]];
}


- (void)setColorSpace:(GoogleColorSpace)inColorSpace
{
	colorSpace = inColorSpace;
	
	[self updateQueryAndDescriptor];
}


- (GoogleColorSpace)colorSpace
{
	return colorSpace;
}


- (void)setSiteString:(NSString *)string
{
	[siteString autorelease];
	siteString = [string copy];
	
	[self updateQueryAndDescriptor];
}


- (NSString *)siteString
{
	return siteString;
}


- (void)setAdultContentFiltering:(GoogleAdultContentFiltering)filtering
{
	adultContentFiltering = filtering;
	
	[self updateQueryAndDescriptor];
}


- (GoogleAdultContentFiltering)adultContentFiltering
{
	return adultContentFiltering;
}


- (void)reset
{
	[imageURLQueue removeAllObjects];
	startIndex = 0;
}


- (BOOL)imagesShouldBeRemovedForLastChange
{
	return YES;
}


- (NSImage *)image;
{
    return [MacOSaiXGoogleImageSourcePlugIn googleIcon];
}


- (id)briefDescription
{
    return descriptor;
}


- (NSNumber *)aspectRatio
{
	return nil;
}


- (void)populateImageQueueFromNextPage
{
	while ([imageURLQueue count] == 0 && startIndex >= 0 && 
		   ([[self requiredTerms] length] > 0 || 
		    [[self optionalTerms] length] > 0 || 
		    [[self excludedTerms] length] > 0 || 
		    [[self siteString] length] > 0))
	{
		NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
		NSString			*nextPage = [urlBase stringByAppendingString:[NSString stringWithFormat:@"%d", startIndex]];
		NSString			*URLcontent = [NSString stringWithContentsOfURL:[NSURL URLWithString:nextPage]];
		
		if (URLcontent)
		{
				// break up the HTML by img tags and look for image URLs
			NSEnumerator	*tagEnumerator = [[URLcontent componentsSeparatedByString:@"<img "] objectEnumerator];
			NSString		*tag = nil;
			
			[tagEnumerator nextObject];	// The first item didn't start with "<img ", the rest do.
			while (tag = [tagEnumerator nextObject])
			{
					// Find where the image URL starts.
				NSRange		src = [tag rangeOfString:@"src="];
				tag = [tag substringWithRange:NSMakeRange(src.location + 4, [tag length] - src.location - 4)];
				
					// Find where the image URL ends
				src = [tag rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" \">"]];
				if (src.location != NSNotFound)
					src.length = src.location;
				else
					src.length = [tag length];
				src.location = 0;
				
					// If the URL has the expected prefix then add it to the queue.
				NSString	*imageURL = [tag substringWithRange:src];
				NSRange		thumbnailIDLoc = [imageURL rangeOfString:@"/images?q=tbn:"];
				if (thumbnailIDLoc.location != NSNotFound)
					[imageURLQueue addObject:[imageURL substringFromIndex:thumbnailIDLoc.location + 14]];
			}
			
				// Check if there are any more pages of search results.
			if ([URLcontent rangeOfString:@"nav_next.gif"].location == NSNotFound)
				startIndex = -1;	// This was the last page of search results.
			else
				startIndex += 20;
		}
		[pool release];
	}
}


- (BOOL)hasMoreImages
{
	return ([imageURLQueue count] > 0 || startIndex >= 0);
}


- (NSNumber *)imageCount
{
	return nil;
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	NSImage		*image = nil;
    
	do
	{
		if ([imageURLQueue count] == 0)
			[self populateImageQueueFromNextPage];
		else
		{
				// Get the image for the first identifier in the queue.
			image = [self thumbnailForIdentifier:[imageURLQueue objectAtIndex:0]];
			if (image)
				*identifier = [[[imageURLQueue objectAtIndex:0] retain] autorelease];
			[imageURLQueue removeObjectAtIndex:0];
		}
	} while (!image && [self hasMoreImages]);
	
	return image;
}


- (BOOL)canRefetchImages
{
	return YES;
}


- (id<NSCopying>)universalIdentifierForIdentifier:(NSString *)identifier
{
	return [self urlForIdentifier:identifier];
}


- (NSString *)identifierForUniversalIdentifier:(id<NSObject,NSCoding,NSCopying>)universalIdentifier
{
	NSString	*prefix = @"http://tbn0.google.com/images?q=tbn:";
	
	if ([(NSString *)universalIdentifier hasPrefix:prefix])
		return [(NSString *)universalIdentifier substringFromIndex:[prefix length]];
	else
		return nil;
}


- (NSImage *)thumbnailForIdentifier:(NSString *)identifier
{
	NSImage		*thumbnail = nil;
	
		// First check if we have this thumbnail in the cache.
	thumbnail = [MacOSaiXGoogleImageSourcePlugIn cachedImageWithIdentifier:identifier getThumbnail:YES];
	
		// If the thumbnail couldn't be read from the cache then fetch it from Google.
	if (!thumbnail)
	{
		NSURL		*thumbnailURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://tbn0.google.com/images?q=tbn:%@", identifier]];
		NSData		*thumbnailData = [[NSData alloc] initWithContentsOfURL:thumbnailURL];
		
		if (thumbnailData)
		{
			thumbnail = [[[NSImage alloc] initWithData:thumbnailData] autorelease];
			
			if (thumbnail)
				[MacOSaiXGoogleImageSourcePlugIn cacheImageData:thumbnailData withIdentifier:identifier isThumbnail:YES];
			
			[thumbnailData release];
		}
	}
	
    return thumbnail;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
		// First check if we have this image in the cache.
	NSImage		*image = [MacOSaiXGoogleImageSourcePlugIn cachedImageWithIdentifier:identifier getThumbnail:NO];
	
		// If the image couldn't be read from the cache then fetch it from the original site.
	if (!image)
	{
		NSURL	*imageURL = [self urlForIdentifier:identifier];
		NSData	*imageData = [[NSData alloc] initWithContentsOfURL:imageURL];
		
		if (imageData)
		{
			image = [[[NSImage alloc] initWithData:imageData] autorelease];
			
			if (image)
				[MacOSaiXGoogleImageSourcePlugIn cacheImageData:imageData withIdentifier:identifier isThumbnail:NO];
			
			[imageData release];
		}
	}
	
    return image;
}


- (NSURL *)thumbnailURLForIdentifier:(NSString *)identifier
{
	return [NSURL URLWithString:[NSString stringWithFormat:@"http://images.google.com/%@", identifier]];
}	


- (NSURL *)urlForIdentifier:(NSString *)identifier
{
	return [NSURL URLWithString:[NSString stringWithFormat:@"http://tbn0.google.com/images?q=tbn:%@", identifier]];
}	


- (NSURL *)contextURLForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (NSString *)descriptionForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (void)dealloc
{
	[requiredTerms release];
	[optionalTerms release];
	[excludedTerms release];
	[siteString release];
	
	[imageURLQueue release];
	
	[super dealloc];
}


@end

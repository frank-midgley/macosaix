//
//  MacOSaiXDLItem.m
//  MacOSaiX
//
//  Created by Frank Midgley on 3/15/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXDLItem.h"

#import "MacOSaiXDLItemType.h"


static NSString	*sImagesPath = nil;


@implementation MacOSaiXDLItem


+ (void)initialize
{
	FSRef			appSupportRef;
	OSErr			err = FSFindFolder(kUserDomain, kApplicationSupportFolderType, NO, &appSupportRef);
	if (err == noErr)
	{
		CFURLRef	appSupportURL = CFURLCreateFromFSRef(kCFAllocatorDefault, &appSupportRef);
		if (appSupportURL)
		{
			NSString		*appSupportPath = [(NSURL *)appSupportURL path];
			
			sImagesPath = [[[appSupportPath stringByAppendingPathComponent:@"Delicious Library"] stringByAppendingPathComponent:@"Images"] retain];
			
			CFRelease(appSupportURL);
		}
	}
}


+ (MacOSaiXDLItem *)itemWithType:(MacOSaiXDLItemType *)inType 
						   title:(NSString *)inTitle 
							UUID:(NSString *)inUUID 
							ASIN:(NSString *)inIdentificationNumber
{
	return [[[self alloc] initWithType:inType title:inTitle UUID:inUUID ASIN:inIdentificationNumber] autorelease];
}


- (id)initWithType:(MacOSaiXDLItemType *)inType 
			 title:(NSString *)inTitle 
			  UUID:(NSString *)inUUID 
			  ASIN:(NSString *)inIdentificationNumber
{
	if (self = [super init])
	{
		type = [inType retain];
		title = [inTitle retain];
		UUID = [inUUID retain];
		ASIN = [inIdentificationNumber retain];
	}
	
	return self;
}


- (void)setCoverURL:(NSURL *)inCoverURL
{
	[coverURL autorelease];
	coverURL = [inCoverURL retain];
}


- (NSURL *)coverURL
{
	return coverURL;
}


- (MacOSaiXDLItemType *)type
{
	return type;
}


- (NSString *)title
{
	return title;
}


- (NSString *)UUID
{
	return UUID;
}


- (NSString *)ASIN
{
	return ASIN;
}


- (NSComparisonResult)compareTitle:(id)otherObject
{
	return [title compare:[otherObject title]];
}


- (NSImage *)image
{
	NSImage	*image = nil;
	
	if (coverURL)
		image = [[[NSImage alloc] initWithContentsOfURL:coverURL] autorelease];
	
	if (!image)
	{
		NSString	*imagePath = [[[sImagesPath stringByAppendingPathComponent:@"Plain Covers"] stringByAppendingPathComponent:[self UUID]] stringByAppendingPathExtension:@"jpg"];
		
		image = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
	}
	
	return image;
}


- (void)dealloc
{
	[type release];
	[title release];
	[UUID release];
	[ASIN release];
	[coverURL release];
	
	[super dealloc];
}


@end

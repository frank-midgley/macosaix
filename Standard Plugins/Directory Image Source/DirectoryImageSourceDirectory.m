//
//  DirectoryImageSourceDirectory.m
//  MacOSaiX
//
//  Created by Frank Midgley on 4/24/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "DirectoryImageSourceDirectory.h"

#import "NSFileManager+MacOSaiX.h"
#import "NSImage+MacOSaiX.h"


@implementation DirectoryImageSourceDirectory


+ (DirectoryImageSourceDirectory *)directoryWithPath:(NSString *)path imageCount:(int)count
{
	return [[[self alloc] initWithPath:path imageCount:count] autorelease];
}


- (id)initWithPath:(NSString *)path imageCount:(int)count
{
	if (self = [super init])
	{
		[self setPath:path];
		[self setImageCount:count];
	}
	
	return self;
}


- (void)setPath:(NSString *)path
{
	if (![path isEqualToString:directoryPath])
	{
		[directoryPath release];
		directoryPath = [path copy];
		
		[displayName release];
		displayName = nil;
		
		[icon release];
		icon = nil;
		
		[attributedLocation release];
		attributedLocation = nil;
		
		[locationDisplayName release];
		locationDisplayName = nil;
		
		[locationIcon release];
		locationIcon = nil;
	}
}


- (NSString *)path
{
	return directoryPath;
}


- (void)setImageCount:(int)count
{
	imageCount = count;
}


- (int)imageCount
{
	return imageCount;
}


- (NSString *)displayName
{
	if (!displayName)
		displayName = [[[NSFileManager defaultManager] displayNameAtPath:[self path]] retain];
	
	return displayName;
}


- (NSImage *)icon
{
	if (!icon)
		icon = [[[NSWorkspace sharedWorkspace] iconForFile:[self path]] copyWithLargestDimension:16];
	
	return icon;
}


- (NSAttributedString *)locationAttributedPath
{
	if (!attributedLocation)
		attributedLocation = [[[NSFileManager defaultManager] attributedPath:[self path] wraps:NO] retain];
	
	return attributedLocation;
}


- (NSString *)locationDisplayName
{
	if (!locationDisplayName)
		locationDisplayName = [[[NSFileManager defaultManager] displayNameAtPath:[[self path] stringByDeletingLastPathComponent]] retain];
	
	return locationDisplayName;
}


- (NSImage *)locationIcon
{
	if (!locationIcon)
		locationIcon = [[[NSWorkspace sharedWorkspace] iconForFile:[[self path] stringByDeletingLastPathComponent]] copyWithLargestDimension:16];
	
	return locationIcon;
}


- (NSComparisonResult)compare:(id)otherDirectory
{
	return [[self displayName] caseInsensitiveCompare:[otherDirectory displayName]];
}


- (void)dealloc
{
	[self setPath:nil];
	
	[super dealloc];
}

@end

/*
	iPhotoImageSource.m
	MacOSaiX

	Created by Frank Midgley on Wed Mar 15 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "iPhotoImageSource.h"
#import "iPhotoImageSourceController.h"
#import "NSString+MacOSaiX.h"


@implementation MacOSaiXiPhotoImageSource


static NSImage	*iPhotoImage = nil,
				*albumImage = nil;
static NSString	*iPhotoAlbumsPath = nil;

+ (void)initialize
{
	NSURL		*iPhotoAppURL = nil;
	LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.iPhoto"), NULL, NULL, (CFURLRef *)&iPhotoAppURL);
	NSBundle	*plugInBundle = [NSBundle bundleWithPath:[iPhotoAppURL path]];
	
	iPhotoImage = [[NSImage alloc] initWithContentsOfFile:[plugInBundle pathForImageResource:@"NSApplicationIcon"]];
	albumImage = [[NSImage alloc] initWithContentsOfFile:[plugInBundle pathForImageResource:@"album_local"]];
	[albumImage setScalesWhenResized:YES];
	[albumImage setSize:NSMakeSize(16.0, 16.0)];
	iPhotoAlbumsPath = [[[[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]
											 stringByAppendingPathComponent:@"iPhoto Library"] 
											 stringByAppendingPathComponent:@"Albums"] retain];
}


+ (NSString *)name
{
	return @"iPhoto Album";
}


+ (Class)editorClass
{
	return [MacOSaiXiPhotoImageSourceController class];
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


+ (NSString *)albumsPath
{
	return iPhotoAlbumsPath;
}


+ (NSImage *)albumImage
{
	return albumImage;
}


- (id)initWithAlbumName:(NSString *)name
{
	if (self = [super init])
	{
		[self setAlbumName:name];
		imagesHaveBeenEnumerated = YES;
	}

    return self;
}


- (NSString *)settingsAsXMLElement
{
	return [NSString stringWithFormat:@"<ALBUM NAME=\"%@\" LAST_IMAGE_NAME=\"%@\"/>", 
									  [NSString stringByEscapingXMLEntites:[self albumName]], 
									  [NSString stringByEscapingXMLEntites:lastEnumeratedImageName]];
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"NAME"])
		[self setAlbumName:[NSString stringByUnescapingXMLEntites:[[settingDict objectForKey:@"NAME"] description]]];
	else if ([settingType isEqualToString:@"LAST_IMAGE_NAME"])
	{
		lastEnumeratedImageName = [[NSString stringByUnescapingXMLEntites:[[settingDict objectForKey:@"LAST_IMAGE_NAME"] description]] retain];
		imagesHaveBeenEnumerated = NO;
	}
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	// not needed
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
	// not needed
}


- (NSString *)albumName
{
	return [[albumName retain] autorelease];
}


- (void)setAlbumName:(NSString *)name
{
	[albumName autorelease];
	albumName = [name copy];
	
		// Create the attributed description.
	[albumDescription autorelease];
	if (albumName)
	{
			// Start with the album icon.
		NSTextAttachment		*ta = [[[NSTextAttachment alloc] initWithFileWrapper:nil] autorelease];
		NSTextAttachmentCell	*taCell = [[[NSTextAttachmentCell alloc] initImageCell:albumImage] autorelease];
		[ta setAttachmentCell:taCell];
		albumDescription = [[NSAttributedString attributedStringWithAttachment:ta] mutableCopy];
		[(NSMutableAttributedString *)albumDescription addAttribute:NSBaselineOffsetAttributeName 
															  value:[NSNumber numberWithInt:-3] 
															  range:NSMakeRange(0, 1)];
		
			// Add the album name.
		NSString				*labelString = [NSString stringWithFormat:@" %@ photos", albumName];
		NSAttributedString		*labelAS = [[[NSAttributedString alloc] initWithString:labelString] autorelease];
		[(NSMutableAttributedString *)albumDescription appendAttributedString:labelAS];
	}
	else
	{
		albumDescription = [[NSAttributedString alloc] initWithString:@"All photos"];
	}
	
		// Set up the enumerator that lets us walk through the album's directory.
	enumerationRoot = [(albumName ? [iPhotoAlbumsPath stringByAppendingPathComponent:albumName] : 
									[iPhotoAlbumsPath stringByDeletingLastPathComponent]) retain];
	[albumEnumerator autorelease];
	albumEnumerator = [[[NSFileManager defaultManager] enumeratorAtPath:enumerationRoot] retain];
	haveMoreImages = (albumEnumerator != nil);
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[MacOSaiXiPhotoImageSource allocWithZone:zone] initWithAlbumName:albumName];
}


- (NSImage *)image;
{
	return iPhotoImage;
}


- (id)descriptor
{
	return [[albumDescription retain] autorelease];
}


- (BOOL)hasMoreImages
{
	return haveMoreImages;
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	NSImage			*image = nil;
	NSString		*imageName = nil;
	
	if (!imagesHaveBeenEnumerated)
	{
			// Enumerate past all of the images that were previously found.
		do
			imageName = [albumEnumerator nextObject];
		while (![imageName isEqualToString:lastEnumeratedImageName]);
			
		imagesHaveBeenEnumerated = YES;
	}
	
		// Enumerate the album's directory until we find a valid image file or run out of files.
	do
	{
		if (imageName = [albumEnumerator nextObject])
		{
			[lastEnumeratedImageName release];
			lastEnumeratedImageName = [imageName retain];
			
			NSString	*lastPathComponent = [imageName lastPathComponent];
			if ([lastPathComponent isEqualToString:@"Thumbs"] || 
				[lastPathComponent isEqualToString:@"Originals"] || 
				[lastPathComponent isEqualToString:@"Data"])
				[albumEnumerator skipDescendents];
			else
				image = [self imageForIdentifier:imageName];
		}
	}
	while (imageName && !image);
	
	if (imageName)
		*identifier = imageName;
	else
		haveMoreImages = NO;	// all done
	
    return image;	// This will still be nil unless we found a valid image file.
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	NSImage		*image = nil;
	NSString	*fullPath = [[enumerationRoot stringByAppendingPathComponent:identifier] stringByResolvingSymlinksInPath],
				*fileType = [[[NSFileManager defaultManager] fileAttributesAtPath:fullPath traverseLink:NO] fileType];
			
	if ([fileType isEqualToString:NSFileTypeRegular])
	{
		NSLog(@"Getting image at %@", fullPath);
		
		NS_DURING
			image = [[[NSImage alloc] initWithContentsOfFile:fullPath] autorelease];
			if (!image)
			{
					// The image might have the wrong or a missing file extension so 
					// try init'ing it based on its contents instead.  This requires 
					// more memory so only do this if initWithContentsOfFile fails.
				NSData	*data = [[NSData alloc] initWithContentsOfFile:fullPath];
				image = [[[NSImage alloc] initWithData:data] autorelease];
				[data release];
			}
		NS_HANDLER
			NSLog(@"%@ is not a valid image file.", fullPath);
		NS_ENDHANDLER
	}
	
    return image;
}


- (void)reset
{
	[self setAlbumName:albumName];
}


- (void)dealloc
{
	[albumName release];
	[lastEnumeratedImageName release];
	[albumDescription release];
	[albumEnumerator release];
	[enumerationRoot release];
	
	[super dealloc];
}


@end

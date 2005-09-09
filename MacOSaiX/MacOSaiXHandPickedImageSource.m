//
//  MacOSaiXHandPickedImageSource.m
//  MacOSaiX
//
//  Created by Frank Midgley on 9/5/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXHandPickedImageSource.h"


@implementation MacOSaiXHandPickedImageSource


+ (NSString *)name
{
	return @"Hand Picked Images";
}


+ (NSImage *)image
{
	return nil;
}


+ (Class)editorClass
{
	return nil;
}


+ (BOOL)allowMultipleImageSources
{
	return NO;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXHandPickedImageSource	*copy = [[MacOSaiXHandPickedImageSource alloc] init];
	
	return [copy autorelease];
}


- (NSString *)settingsAsXMLElement
{
	return @"";
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
}


- (NSImage *)image
{
	return nil;
}


- (id)descriptor
{
	return @"Hand picked images";
}


- (BOOL)hasMoreImages
{
	return NO;
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	*identifier = nil;
	return nil;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
		// The identifier is a full path to an image file.
	NSImage		*image = nil;
	NSString	*fileType = [[[NSFileManager defaultManager] fileAttributesAtPath:identifier traverseLink:NO] fileType];
	
	if ([fileType isEqualToString:NSFileTypeRegular])
	{
		NS_DURING
			image = [[[NSImage alloc] initWithContentsOfFile:identifier] autorelease];
			if (!image)
			{
					// The image might have the wrong or a missing file extension so 
					// try init'ing it based on its contents instead.  This requires 
					// more memory so only do this if initWithContentsOfFile fails.
				NSData	*data = [[NSData alloc] initWithContentsOfFile:identifier];
				image = [[[NSImage alloc] initWithData:data] autorelease];
				[data release];
			}
		NS_HANDLER
			NSLog(@"%@ is not a valid image file.", identifier);
		NS_ENDHANDLER
	}
	
    return image;
}


- (void)reset
{
}


@end

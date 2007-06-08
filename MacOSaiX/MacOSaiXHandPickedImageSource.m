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
	return NSLocalizedString(@"Hand Picked Images", @"");
}


+ (NSImage *)image
{
	return [NSImage imageNamed:@"HandPicked"];
}


+ (Class)editorClass
{
	return nil;
}


+ (Class)preferencesControllerClass
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


- (BOOL)settingsAreValid
{
	return YES;
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	return YES;
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	return YES;
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
	return [NSImage imageNamed:@"HandPicked"];
}


- (id)briefDescription
{
	return [[self class] name];
}


- (NSNumber *)aspectRatio
{
	return nil;
}


- (BOOL)hasMoreImages
{
	return NO;
}


- (NSNumber *)imageCount
{
	return nil;
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	*identifier = nil;
	return nil;
}


- (BOOL)canRefetchImages
{
	return YES;
}


- (id<NSCopying>)universalIdentifierForIdentifier:(NSString *)identifier
{
	return identifier;
}


- (NSImage *)thumbnailForIdentifier:(NSString *)identifier
{
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


- (BOOL)imagesShouldBeRemovedForLastChange
{
	return YES;
}


- (NSURL *)urlForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (NSURL *)contextURLForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (NSString *)descriptionForIdentifier:(NSString *)identifier
{
	NSString	*description = nil;
	
#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
	if (MDItemCreate)
#endif
	{
		MDItemRef	itemRef = MDItemCreate(kCFAllocatorDefault, (CFStringRef)identifier);
		if (itemRef)
		{
			CFTypeRef	valueRef = MDItemCopyAttribute(itemRef, kMDItemFinderComment);
			
			description = [(id)valueRef autorelease];
			CFRelease(itemRef);
		}
	}
	
	if (!description)
		description = [[NSFileManager defaultManager] displayNameAtPath:identifier];
	
	return description;
}	


@end

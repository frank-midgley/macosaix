/*
	MacOSaiXWatchedFolderImageSource.m
	MacOSaiX

	Created by Frank Midgley on Wed Oct 17 2007.
	Copyright (c) 2007 Frank M. Midgley. All rights reserved.
*/

#import "MacOSaiXWatchedFolderImageSource.h"

#import "MacOSaiXPopUpImageView.h"
#import "NSFileManager+MacOSaiX.h"
#import "NSString+MacOSaiX.h"
#import <pthread.h>


@implementation MacOSaiXWatchedFolderImageSource


+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObject:@"path"] triggerChangeNotificationsForDependentKey:@"attributedPath"];
}


+ (NSImage *)image
{
	NSImage	*image = [[NSWorkspace sharedWorkspace] iconForFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]];
	
	if (!image)
		image = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
	
	return image;
}


+ (Class)editorClass
{
	return NSClassFromString(@"MacOSaiXWatchedFolderImageSourceEditor");
}


+ (Class)preferencesControllerClass
{
	return nil;
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


- (id)init
{
	if (self = [super init])
	{
		NSDictionary	*defaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Watched Folder Image Source"];
		NSString		*defaultPath = [defaults objectForKey:@"Last Chosen Folder"];
		if (!defaultPath)
			defaultPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"];
		[self setPath:defaultPath];
	}

    return self;
}


- (NSString *)settingsAsXMLElement
{
	NSMutableString	*settings = [NSMutableString stringWithFormat:@"<WATCHED_FOLDER PATH=\"%@\">\n", [[self path] stringByEscapingXMLEntites]];
	NSEnumerator	*subPathEnumerator = [knownSubPaths objectEnumerator];
	NSString		*subPath = nil;
	
	while (subPath = [subPathEnumerator nextObject])
		[settings appendFormat:@"\t<WATCHED_IMAGE FILE_NAME=\"%@\" />\n", [subPath stringByEscapingXMLEntites]];
	
	[settings appendString:@"</WATCHED_FOLDER>"];
	
	return settings;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"WATCHED_FOLDER"])
	{
		[self setPath:[[[settingDict objectForKey:@"PATH"] description] stringByUnescapingXMLEntites]];
	}
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	if ([[childSettingDict objectForKey:@"Element Type"] isEqualToString:@"WATCHED_IMAGE"])
		[knownSubPaths addObject:[childSettingDict objectForKey:@"FILE_NAME"]];
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
	// not needed
}


- (void)setPath:(NSString *)path
{
	[folderPath autorelease];
	folderPath = [path copy];
	
		// Get the icon at this path for display in the sources table.
		// The table is refreshed often so we store the image in an ivar to avoid hitting the disk repeatedly.
	[folderImage autorelease];
	folderImage = (folderPath ? [[[NSWorkspace sharedWorkspace] iconForFile:folderPath] retain] : nil);
	
	[attributedFolderPath autorelease];
    attributedFolderPath = [[[NSFileManager defaultManager] attributedPath:folderPath] retain];
	
	[knownSubPaths autorelease];
	knownSubPaths = [[NSMutableSet set] retain];
}


- (NSString *)path
{
	return [[folderPath retain] autorelease];
}


- (NSAttributedString *)attributedPath
{
	return attributedFolderPath;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXWatchedFolderImageSource	*copy = [[MacOSaiXWatchedFolderImageSource allocWithZone:zone] init];
	
	[copy setPath:[self path]];
	
	return copy;
}


- (NSImage *)image;
{
	return [[folderImage retain] autorelease];
}


- (id)descriptor
{
	return [[attributedFolderPath retain] autorelease];
}


- (BOOL)hasMoreImages
{
	return YES;
}


- (NSError *)nextImage:(NSImage **)image andIdentifier:(NSString **)identifier
{
	NSError			*error = nil;
	NSString		*subPath = nil;
	NSFileManager	*fileManager = [NSFileManager defaultManager];
	NSMutableSet	*currentSubPaths = [NSMutableSet setWithArray:[fileManager directoryContentsAtPath:[self path]]];
	[currentSubPaths minusSet:knownSubPaths];
	
	*image = nil;
	*identifier = nil;
		
	if ([currentSubPaths count] > 0)
	{
		subPath = [currentSubPaths anyObject];
		
		NSString		*fullPath = [[self path] stringByAppendingPathComponent:subPath];
		NSDictionary	*attributes = [fileManager fileAttributesAtPath:fullPath traverseLink:NO];
		if ([attributes fileSize] == 0 || [[attributes objectForKey:NSFileBusy] boolValue])
		{
			do
			{
				#ifdef DEBUG
					NSLog(@"%@ is busy", subPath);
				#endif
				[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
				attributes = [fileManager fileAttributesAtPath:fullPath traverseLink:NO];
			}
			while ([fileManager fileExistsAtPath:fullPath] && ([attributes fileSize] == 0 || [[attributes objectForKey:NSFileBusy] boolValue]));
		}
		
		*image = [self imageForIdentifier:subPath];
		
		if ([*image isValid])
			*identifier = subPath;
		else
		{
			#ifdef DEBUG
				NSLog(@"%@ is not a valid image", subPath);
			#endif
			*image = nil;
		}
		
		[knownSubPaths addObject:subPath];
	}
	else
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	
    return error;
}


- (BOOL)canRefetchImages
{
	return YES;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	NSImage		*image = nil;
	NSString	*fullPath = [[self path] stringByAppendingPathComponent:identifier], 
				*fileType = [[[NSFileManager defaultManager] fileAttributesAtPath:fullPath traverseLink:NO] fileType];
	
	if ([fileType isEqualToString:NSFileTypeRegular])
	{
		NS_DURING
			image = [[[NSImage alloc] initWithContentsOfFile:fullPath] autorelease];
			if (!image)
			{
					// The image might have the wrong or a missing file extension so try init'ing it based on its contents instead.  This requires more memory so only do this if initWithContentsOfFile fails.
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
	NSString	*description = nil, 
				*fullPath = [folderPath stringByAppendingPathComponent:identifier];
	
	MDItemRef	itemRef = MDItemCreate(kCFAllocatorDefault, (CFStringRef)fullPath);
	if (itemRef)
	{
		CFTypeRef	valueRef = MDItemCopyAttribute(itemRef, kMDItemFinderComment);
		
		description = [(id)valueRef autorelease];
		CFRelease(itemRef);
	}
	
	if (!description)
		description = [[fullPath lastPathComponent] stringByDeletingPathExtension];
	
	return description;
}	


- (void)reset
{
	[self setPath:folderPath];
}


#pragma mark -


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[folderPath release];
	[folderImage release];
	[attributedFolderPath release];
	[knownSubPaths release];
	
	[super dealloc];
}


@end

/*
	MacOSaiXDLImageSource.h
	MacOSaiX

	Created by Frank Midgley on Sat Mar 15 2008.
	Copyright (c) 2008 Frank M. Midgley. All rights reserved.
*/

#import "MacOSaiXDLImageSource.h"

#import "MacOSaiXDeliciousLibrary.h"
#import "MacOSaiXDLImageSourceEditor.h"
#import "MacOSaiXDLItem.h"
#import "MacOSaiXDLItemType.h"
#import "MacOSaiXDLShelf.h"
#import "NSString+MacOSaiX.h"
#import <pthread.h>


@implementation MacOSaiXDLImageSource


+ (void)initialize
{
//	[MacOSaiXDeliciousLibrary sharedLibrary];
}


+ (NSImage *)image
{
	return [[MacOSaiXDeliciousLibrary sharedLibrary] image];
}


+ (Class)editorClass
{
	return [MacOSaiXDLImageSourceEditor class];
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
		queuedItems = [[NSMutableArray arrayWithArray:[[MacOSaiXDeliciousLibrary sharedLibrary] allItems]] retain];
		descriptor = @"All items in library";
	}

    return self;
}


- (NSString *)settingsAsXMLElement
{
	NSMutableString	*settings = [NSMutableString stringWithString:@"<ITEMS"];
	
	if ([self itemType])
		[settings appendFormat:@" TYPE=\"%d\">\n", [[self itemType] type]];
	else if ([self shelf])
		[settings appendFormat:@" SHELF=\"%@\">\n", [[self shelf] UUID]];
	else
		[settings appendString:@">\n"];
	
	NSEnumerator	*itemEnumerator = [queuedItems objectEnumerator];
	MacOSaiXDLItem	*item = nil;
	while (item = [itemEnumerator nextObject])
		[settings appendFormat:@"\t<ITEM UUID=\"%@\" />\n", [item UUID]];
	
	[settings appendString:@"</ITEMS>"];
	
	return settings;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"ITEMS"])
	{
		if ([settingDict objectForKey:@"TYPE"])
		{
			MacOSaiXDLItemType	*type = [[MacOSaiXDeliciousLibrary sharedLibrary] itemTypeWithType:(OSType)[[settingDict objectForKey:@"TYPE"] intValue]];
			
			if (type)
				[self setItemType:type];
		}
		else if ([settingDict objectForKey:@"SHELF"])
			[self setShelf:[[MacOSaiXDeliciousLibrary sharedLibrary] shelfWithUUID:[settingDict objectForKey:@"SHELF"]]];
		
			// Remove any default items that were added to the queue.
		[queuedItems removeAllObjects];
	}
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	NSString	*settingType = [childSettingDict objectForKey:@"Element Type"];
	
	if ([settingType isEqualToString:@"ITEM"])
	{
		NSString	*itemUUID = [childSettingDict objectForKey:@"UUID"];
		
		[queuedItems addObject:[[MacOSaiXDeliciousLibrary sharedLibrary] itemWithUUID:itemUUID]];
	}
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
//	[self updateQueryAndDescriptor];
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXDLImageSource	*copy = [[MacOSaiXDLImageSource allocWithZone:zone] init];
	
	if (itemType)
		[copy setItemType:itemType];
	else if (shelf)
		[copy setShelf:shelf];
	
	return copy;
}


- (void)setItemType:(MacOSaiXDLItemType *)type
{
	if (shelf)
	{
		[shelf release];
		shelf = nil;
	}
	
	[itemType release];
	itemType = [type retain];
	
	[descriptor autorelease];
	
	if (type)
	{
		[queuedItems setArray:[itemType items]];
		descriptor = [[NSString stringWithFormat:@"All %@", [itemType name]] retain];
	}
	else
	{
		[queuedItems setArray:[[MacOSaiXDeliciousLibrary sharedLibrary] allItems]];
		descriptor = @"All items";
	}
}


- (MacOSaiXDLItemType *)itemType
{
	return itemType;
}


- (void)setShelf:(MacOSaiXDLShelf *)inShelf
{
	if (itemType)
	{
		[itemType release];
		itemType = nil;
	}
	
	[shelf release];
	shelf = [inShelf retain];
	
	[queuedItems setArray:[shelf items]];
	[descriptor release];
	descriptor = [[NSString stringWithFormat:@"All items on the %@ shelf", [shelf name]] retain];
}


- (MacOSaiXDLShelf *)shelf
{
	return shelf;
}


- (float)aspectRatio
{
	// TBD: can this be determined?
	return 1.0;
}


	// return the image to be displayed in the list of image sources
- (NSImage *)image;
{
	return [[MacOSaiXDeliciousLibrary sharedLibrary] image];
}


	// return the text to be displayed in the list of image sources
- (id)descriptor
{
	return descriptor;
}


- (BOOL)hasMoreImages
{
	return ([queuedItems count] > 0);
}


- (NSError *)nextImage:(NSImage **)image andIdentifier:(NSString **)identifier
{
	NSError	*error = nil;
	
	*image = nil;
	*identifier = nil;
	
	if ([queuedItems count] > 0)
	{
		MacOSaiXDLItem	*nextItem = [queuedItems objectAtIndex:0];
		
		*identifier = [nextItem UUID];
		*image = [self imageForIdentifier:*identifier];
		
		if (!*image)
			*identifier = nil;
		
		[queuedItems removeObjectAtIndex:0];
	}
	
	return error;
}


- (BOOL)canReenumerateImages
{
	return YES;
}


- (BOOL)canRefetchImages
{
	return YES;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	MacOSaiXDLItem	*item = [[MacOSaiXDeliciousLibrary sharedLibrary] itemWithUUID:identifier];
	
	return [item image];
}


- (NSURL *)urlForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (NSURL *)contextURLForIdentifier:(NSString *)identifier
{
	MacOSaiXDLItem	*item = [[MacOSaiXDeliciousLibrary sharedLibrary] itemWithUUID:identifier];
	
	return [NSURL URLWithString:[NSString stringWithFormat:@"http://www.amazon.com/exec/obidos/ASIN/%@", [item ASIN]]];
}	


- (NSString *)descriptionForIdentifier:(NSString *)identifier
{
	MacOSaiXDLItem	*item = [[MacOSaiXDeliciousLibrary sharedLibrary] itemWithUUID:identifier];
	
	return [item title];
}	


- (void)reset
{
	if ([self shelf])
	{
		NSString	*shelfID = [[self shelf] UUID];
		
		[[MacOSaiXDeliciousLibrary sharedLibrary] loadLibrary];
		while ([[MacOSaiXDeliciousLibrary sharedLibrary] isLoading])
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		[self setShelf:[[MacOSaiXDeliciousLibrary sharedLibrary] shelfWithUUID:shelfID]];
		// TODO: handle case of shelf having been deleted
	}
	else if ([self itemType])
	{
		OSType	itemTypeOSType = [[self itemType] type];
		
		[[MacOSaiXDeliciousLibrary sharedLibrary] loadLibrary];
		while ([[MacOSaiXDeliciousLibrary sharedLibrary] isLoading])
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		[self setItemType:[[MacOSaiXDeliciousLibrary sharedLibrary] itemTypeWithType:itemTypeOSType]];
	}
	else
	{
		[[MacOSaiXDeliciousLibrary sharedLibrary] loadLibrary];
		while ([[MacOSaiXDeliciousLibrary sharedLibrary] isLoading])
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		[queuedItems setArray:[[MacOSaiXDeliciousLibrary sharedLibrary] allItems]];
	}
}


- (void)dealloc
{
	[itemType release];
	[shelf release];
	[descriptor release];
	[queuedItems release];
	
	[super dealloc];
}


@end

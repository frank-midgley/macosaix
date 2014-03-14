//
//  MacOSaiXDeliciousLibrary.m
//  MacOSaiX
//
//  Created by Frank Midgley on 3/15/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXDeliciousLibrary.h"

#import "MacOSaiXDLItem.h"
#import "MacOSaiXDLItemType.h"
#import "MacOSaiXDLShelf.h"


NSString	*MacOSaiXDLDidChangeStateNotification = @"MacOSaiXDLDidChangeStateNotification";


@implementation MacOSaiXDeliciousLibrary


+ (MacOSaiXDeliciousLibrary *)sharedLibrary
{
	static MacOSaiXDeliciousLibrary	*library = nil;
	
	if (!library)
		library = [[MacOSaiXDeliciousLibrary alloc] init];
	
	return library;
}


- (id)init
{
	if (self = [super init])
	{
		shelves = [[NSMutableDictionary alloc] init];
		allItems = [[NSMutableDictionary alloc] init];
		typeImages = [[NSMutableDictionary alloc] init];
		itemTypes = [[NSMutableArray alloc] init];
		
//		[self loadLibrary];
		
		NSURL		*dlAppURL = nil;
		OSStatus	status = LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.delicious-monster.library2"), NULL, NULL, (CFURLRef *)&dlAppURL);
		if (status != noErr || !dlAppURL)
			status = LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.delicious-monster.library"), NULL, NULL, (CFURLRef *)&dlAppURL);
		if (status == noErr && dlAppURL)
		{
			NSBundle	*dlBundle = [NSBundle bundleWithPath:[dlAppURL path]];
			deliciousLibraryImage = [[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"Delicious Library"]];
			CFRelease(dlAppURL);
		}
		if (!deliciousLibraryImage)
			deliciousLibraryImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForImageResource:@"Delicious Library"]];
	}
	
	return self;
}


- (BOOL)isLoading
{
	return isLoading;
}


- (BOOL)isInstalled
{
	return isInstalled;
}


- (NSImage *)image
{
	return [[deliciousLibraryImage retain] autorelease];
}


- (NSImage *)shelfImage
{
	return [[shelfImage retain] autorelease];
}


- (NSImage *)smartShelfImage
{
	return [[smartShelfImage retain] autorelease];
}


#pragma mark -
#pragma mark Library loading


- (void)loadVersion1Library:(NSURL *)appURL
{
		// Start up an XML parser if the library file can be found.
	FSRef			appSupportRef;
	OSErr			err = FSFindFolder(kUserDomain, kApplicationSupportFolderType, NO, &appSupportRef);
	if (err == noErr)
	{
		CFURLRef	appSupportURL = CFURLCreateFromFSRef(kCFAllocatorDefault, &appSupportRef);
		if (appSupportURL)
		{
			NSString		*appSupportPath = [(NSURL *)appSupportURL path], 
							*xmlPath = [[appSupportPath stringByAppendingPathComponent:@"Delicious Library"] stringByAppendingPathComponent:@"Library Media Data.xml"];
			
			if ([[NSFileManager defaultManager] fileExistsAtPath:xmlPath])
			{
				NSXMLParser		*xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:[NSURL fileURLWithPath:xmlPath]];
				[xmlParser setDelegate:self];
				[xmlParser parse];
			}
			else
				loadingError = [[NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObject:@"Could not locate the Delicious Library file." forKey:NSLocalizedDescriptionKey]] retain];
			
			CFRelease(appSupportURL);
		}
		else
			loadingError = [[NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObject:@"Could not locate your Application Support folder." forKey:NSLocalizedDescriptionKey]] retain];
	}
	else
		loadingError = [[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:[NSDictionary dictionaryWithObject:@"Could not locate your Application Support folder." forKey:NSLocalizedDescriptionKey]] retain];
	
		// Load various images.
	NSBundle	*dlBundle = [NSBundle bundleWithPath:[appURL path]];
	shelfImage = [[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"shelf_lg"]];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"books_lg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'B00K']];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"games_lg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'V1DE']];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"movies_lg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'M0VE']];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"music_lg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'MUS3']];
}


- (void)loadVersion2Library:(NSURL *)appURL
{
	BOOL					smartShelvesPopulated = NO;
	
		// Load any user defined shelves.
	NSAppleScript			*getShelvesScript = [[[NSAppleScript alloc] initWithSource:@"tell application \"Delicious Library 2\" to get {uuid, class, name} of (user shelves of document 1)"] autorelease];
	NSDictionary			*getShelvesError = nil;
	NSAppleEventDescriptor	*getShelvesResult = [getShelvesScript executeAndReturnError:&getShelvesError];
	if (!getShelvesError)
	{
		NSAppleEventDescriptor	*uuidDescriptors = [getShelvesResult descriptorAtIndex:1], 
								*shelfTypeDescriptors = [getShelvesResult descriptorAtIndex:2], 
								*nameDescriptors = [getShelvesResult descriptorAtIndex:3];
		int						shelfCount = [uuidDescriptors numberOfItems],
								shelfIndex;
		for (shelfIndex = 1; shelfIndex <= shelfCount; shelfIndex++)
		{
			NSString		*uuid = [[uuidDescriptors descriptorAtIndex:shelfIndex] stringValue], 
							*name = [[nameDescriptors descriptorAtIndex:shelfIndex] stringValue];
			OSType			shelfType = [[shelfTypeDescriptors descriptorAtIndex:shelfIndex] typeCodeValue];
			MacOSaiXDLShelf	*shelf = [MacOSaiXDLShelf shelfWithName:name UUID:uuid isSmart:(shelfType == 'SHLF')];
			
			[shelves setObject:shelf forKey:uuid];
		}
	}
	
		// Load the media items.
	NSAppleScript			*getItemsScript = [[[NSAppleScript alloc] initWithSource:@"tell application \"Delicious Library 2\" to get {uuid, class, asin, title, cover URL, uuid of shelves} of (media of document 1)"] autorelease];
	NSDictionary			*getItemsError = nil;
	NSAppleEventDescriptor	*getItemsResult = [getItemsScript executeAndReturnError:&getItemsError];
	
	if (!getItemsError)
	{
		NSAppleEventDescriptor	*uuidDescriptors = [getItemsResult descriptorAtIndex:1], 
								*itemTypeDescriptors = [getItemsResult descriptorAtIndex:2], 
								*asinDescriptors = [getItemsResult descriptorAtIndex:3], 
								*titleDescriptors = [getItemsResult descriptorAtIndex:4], 
								*coverURLDescriptors = [getItemsResult descriptorAtIndex:5], 
								*shelvesUUIDsDescriptors = [getItemsResult descriptorAtIndex:6];
		int						itemCount = [uuidDescriptors numberOfItems],
								itemIndex;
		
		for (itemIndex = 1; itemIndex <= itemCount; itemIndex++)
		{
				// Create the item.
			OSType					itemType = [[itemTypeDescriptors descriptorAtIndex:itemIndex] typeCodeValue];
			NSString				*uuid = [[uuidDescriptors descriptorAtIndex:itemIndex] stringValue], 
									*asin = [[asinDescriptors descriptorAtIndex:itemIndex] stringValue], 
									*title = [[titleDescriptors descriptorAtIndex:itemIndex] stringValue], 
									*coverURL = [[coverURLDescriptors descriptorAtIndex:itemIndex] stringValue];
			MacOSaiXDLItem			*item = [MacOSaiXDLItem itemWithType:[self itemTypeWithType:itemType] title:title UUID:uuid ASIN:asin];
			
			if (coverURL)
				[item setCoverURL:[NSURL URLWithString:coverURL]];
			
			[allItems setObject:item forKey:uuid];
			[[item type] addItem:item];
			
				// Add the item to any shelves.
			NSAppleEventDescriptor	*shelfUUIDsDescriptors = [shelvesUUIDsDescriptors descriptorAtIndex:itemIndex];
			int						shelfCount = [shelfUUIDsDescriptors numberOfItems],
									shelfIndex;
			for (shelfIndex = 1; shelfIndex <= shelfCount; shelfIndex++)
			{
				NSString		*shelfUUID = [[shelfUUIDsDescriptors descriptorAtIndex:shelfIndex] stringValue];
				MacOSaiXDLShelf	*shelf = [self shelfWithUUID:shelfUUID];
				
				[shelf addItem:item];
				
				if ([shelf isSmart])
					smartShelvesPopulated = YES;
			}
		}
	}
	
	if (!smartShelvesPopulated)
	{
		NSEnumerator	*shelfEnumerator = [[self shelves] objectEnumerator];
		MacOSaiXDLShelf	*shelf = nil;
		
		while (shelf = [shelfEnumerator nextObject])
			if ([shelf isSmart])
			{
				NSString				*getShelfItemsString = [NSString stringWithFormat:@"tell application \"Delicious Library 2\" to get uuid of (media of (shelf 1 of document 1 whose uuid is \"%@\"))", [shelf UUID]];
				NSAppleScript			*getShelfItemsScript = [[[NSAppleScript alloc] initWithSource:getShelfItemsString] autorelease];
				NSDictionary			*getShelfItemsError = nil;
				NSAppleEventDescriptor	*getShelfItemsResult = [getShelfItemsScript executeAndReturnError:&getShelfItemsError];
				if (!getShelfItemsError)
				{
					int		itemCount = [getShelfItemsResult numberOfItems], 
							itemIndex;
					for (itemIndex = 1; itemIndex <= itemCount; itemIndex++)
					{
						NSString		*itemUUID = [[getShelfItemsResult descriptorAtIndex:itemIndex] stringValue];
						MacOSaiXDLItem	*item = [self itemWithUUID:itemUUID];
						
						if (item)
							[shelf addItem:item];
					}
				}
			}
	}
	
	[itemTypes sortUsingSelector:@selector(compare:)];
	
		// Load various images.
	NSBundle	*dlBundle = [NSBundle bundleWithPath:[appURL path]];
	deliciousLibraryImage = [[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"Delicious Library"]];
	shelfImage = [[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"YourShelf_lg"]];
	smartShelfImage = [[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"SmartShelf_lg"]];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"Apparel_xlg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'CL07']];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"Book_xlg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'B00K']];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"Gadget_xlg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'3LCT']];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"Movie_xlg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'M0VE']];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"Music_xlg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'MUS3']];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"Software_xlg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'WR3Z']];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"Tool_xlg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'T00L']];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"Toy_xlg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'AT0Y']];
	[typeImages setObject:[[[NSImage alloc] initWithContentsOfFile:[dlBundle pathForImageResource:@"VideoGame_xlg"]] autorelease] 
				   forKey:[NSNumber numberWithUnsignedInt:'V1DE']];
}


- (void)loadLibrary
{
	isLoading = YES;
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXDLDidChangeStateNotification object:nil];
	
		// Clear out all of the previous content.
		// TBD: Try to preserve objects that still exist? (test by UUID)
	[shelves removeAllObjects];
	[allItems removeAllObjects];
	[typeImages removeAllObjects];
	[itemTypes removeAllObjects];
	
	[loadingError autorelease];
	loadingError = nil;
		
		// Check if version 2 is installed.
	NSURL		*dlAppURL = nil;
	OSStatus	status = LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.delicious-monster.library2"), NULL, NULL, (CFURLRef *)&dlAppURL);
	
	if (status == noErr && dlAppURL)
	{
		isInstalled = YES;
		
		[self loadVersion2Library:dlAppURL];
		
		// The library is now loaded.
		
		isLoading = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXDLDidChangeStateNotification object:nil];
		
		CFRelease(dlAppURL);
	}
	else
	{
			// Check if version 1 is installed.
		status = LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.delicious-monster.library"), NULL, NULL, (CFURLRef *)&dlAppURL);
		
		if (status == noErr && dlAppURL)
		{
			isInstalled = YES;
			
			[self loadVersion1Library:dlAppURL];
			
			// The library will now be loading asynchrously.
			
			CFRelease(dlAppURL);
		}
		else
		{
			// Neither version is installed.
			isLoading = NO;
			[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXDLDidChangeStateNotification object:nil];
		}
	}
	
	if (loadingError)
	{
		isLoading = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXDLDidChangeStateNotification object:nil];
	}
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"library"])
	{
		if (![[attributeDict objectForKey:@"version"] isEqualToString:@"1"])
		{
			loadingError = [[NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObject:@"MacOSaiX cannot read this version of the Delicious Library." forKey:NSLocalizedDescriptionKey]] retain];
			[parser abortParsing];
		}
	}
	else if (!inRecommendations)
	{
		if ([elementName isEqualToString:@"shelf"])
		{
			MacOSaiXDLShelf	*shelf = [MacOSaiXDLShelf shelfWithName:[attributeDict objectForKey:@"name"]
															   UUID:[attributeDict objectForKey:@"uuid"]
															isSmart:NO];
			
			[shelves setObject:shelf forKey:[shelf UUID]];
			currentShelf = shelf;
		}
		else if ([elementName isEqualToString:@"linkto"])
		{
			MacOSaiXDLItem	*item = [self itemWithUUID:[attributeDict objectForKey:@"uuid"]];
			
			[currentShelf addItem:item];
		}
		else if ([elementName isEqualToString:@"book"])
		{
			MacOSaiXDLItem	*book = [MacOSaiXDLItem itemWithType:[self itemTypeWithType:'B00K'] 
														   title:[attributeDict objectForKey:@"fullTitle"] 
															UUID:[attributeDict objectForKey:@"uuid"] 
															ASIN:[attributeDict objectForKey:@"asin"]];
			
			[allItems setObject:book forKey:[book UUID]];
			[[book type] addItem:book];
		}
		else if ([elementName isEqualToString:@"game"])
		{
			MacOSaiXDLItem	*game = [MacOSaiXDLItem itemWithType:[self itemTypeWithType:'V1DE'] 
														   title:[attributeDict objectForKey:@"fullTitle"] 
															UUID:[attributeDict objectForKey:@"uuid"] 
															ASIN:[attributeDict objectForKey:@"asin"]];
			
			[allItems setObject:game forKey:[game UUID]];
			[[game type] addItem:game];
		}
		else if ([elementName isEqualToString:@"movie"])
		{
			MacOSaiXDLItem	*movie = [MacOSaiXDLItem itemWithType:[self itemTypeWithType:'M0VE'] 
															title:[attributeDict objectForKey:@"fullTitle"] 
															 UUID:[attributeDict objectForKey:@"uuid"] 
															 ASIN:[attributeDict objectForKey:@"asin"]];
			
			[allItems setObject:movie forKey:[movie UUID]];
			[[movie type] addItem:movie];
		}
		else if ([elementName isEqualToString:@"music"])
		{
			MacOSaiXDLItem	*musicItem = [MacOSaiXDLItem itemWithType:[self itemTypeWithType:'MUS3'] 
																title:[attributeDict objectForKey:@"fullTitle"] 
																 UUID:[attributeDict objectForKey:@"uuid"] 
																 ASIN:[attributeDict objectForKey:@"asin"]];
			
			[allItems setObject:musicItem forKey:[musicItem UUID]];
			[[musicItem type] addItem:musicItem];
		}
		else if ([elementName isEqualToString:@"recommendations"])
			inRecommendations = YES;
	}
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if ([elementName isEqualToString:@"recommendations"])
		inRecommendations = NO;
	else if ([elementName isEqualToString:@"shelf"])
		currentShelf = nil;
}


- (void)parserDidEndDocument:(NSXMLParser *)parser
{
	[itemTypes sortUsingSelector:@selector(compare:)];
	
	if (!loadingError && [parser parserError])
		loadingError = [[parser parserError] retain];
	
	isLoading = NO;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXDLDidChangeStateNotification object:nil];
}


- (NSError *)loadingError
{
	return loadingError;
}


#pragma mark -
#pragma mark Shelves


- (NSArray *)shelves
{
	return [[shelves allValues] sortedArrayUsingSelector:@selector(compare:)];
}


- (MacOSaiXDLShelf *)shelfWithUUID:(NSString *)shelfUUID
{
	return [shelves objectForKey:shelfUUID];
}


#pragma mark -
#pragma mark Item types


- (NSArray *)itemTypes
{
	return [itemTypes sortedArrayUsingSelector:@selector(compare:)];
}


- (NSImage *)imageOfType:(OSType)type
{
	return [typeImages objectForKey:[NSNumber numberWithUnsignedInt:type]];
}


- (MacOSaiXDLItemType *)itemTypeWithType:(OSType)type
{
	NSEnumerator		*itemTypeEnumerator = [itemTypes objectEnumerator];
	MacOSaiXDLItemType	*itemType = nil;
	
	while (itemType = [itemTypeEnumerator nextObject])
		if ([itemType type] == type)
			break;
	
	if (!itemType)
	{
		itemType = [[[MacOSaiXDLItemType alloc] initWithType:type] autorelease];
		[itemTypes addObject:itemType];
		[itemTypes sortUsingSelector:@selector(compare:)];
	}
	
	return itemType;
}


#pragma mark -
#pragma mark Items


- (NSArray *)allItems
{
	return [allItems allValues];
}


- (MacOSaiXDLItem *)itemWithUUID:(NSString *)itemUUID
{
	return [allItems objectForKey:itemUUID];
}


@end

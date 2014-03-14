//
//  FlickrPreferencesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 1/28/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "FlickrPreferencesController.h"
#import "FlickrImageSource.h"
#import "MacOSaiXFlickrCategory.h"
#import "MacOSaiXFlickrGroup.h"

#import <sys/mount.h>


@interface FlickrPreferencesController (PrivateMethods)
- (void)getMatchingGroups;
@end


@implementation FlickrPreferencesController


- (NSView *)mainView
{
	if (!mainView)
	{
		[[NSBundle bundleForClass:[self class]] loadNibFile:@"Preferences" 
										  externalNameTable:[NSDictionary dictionaryWithObject:self forKey:@"NSOwner"] 
												   withZone:[self zone]];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showFavoriteGroups:) name:MacOSaiXFlickrShowFavoriteGroupsNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authenticationDidChange:) name:MacOSaiXFlickrAuthenticationDidChangeNotification object:nil];
		
		CFURLRef	browserURL = nil;
		OSStatus	status = LSGetApplicationForURL((CFURLRef)[NSURL URLWithString:@"http://www.apple.com/"], 
													kLSRolesViewer,
													NULL,
													&browserURL);
		if (status == noErr)
			browserIcon = [[[NSWorkspace sharedWorkspace] iconForFile:[(NSURL *)browserURL path]] retain];
		else
		{
			NSString	*safariPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Safari"];
			
			if (safariPath)
				browserIcon = [[[NSWorkspace sharedWorkspace] iconForFile:safariPath] retain];
			// TBD: else ???
		}
		
		[browserIcon setSize:NSMakeSize(16.0, 16.0)];
		
		[[[favoriteGroupsTable tableColumnWithIdentifier:@"Visit Group Page"] dataCell] setImage:browserIcon];
		[[[searchGroupsView tableColumnWithIdentifier:@"Visit Group Page"] dataCell] setImage:browserIcon];
		[[[browseGroupsView tableColumnWithIdentifier:@"Visit Group Page"] dataCell] setImage:browserIcon];
	}
	
	return mainView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(420.0, 200.0);
}


- (NSResponder *)firstResponder
{
	return maxCacheSizeField;
}


- (void)willSelect
{
		// Make sure the nib is loaded.
	[self mainView];
	
	unsigned long long	maxCacheSize = [FlickrImageSource maxCacheSize], 
						minFreeSpace = [FlickrImageSource minFreeSpace];

	NSEnumerator		*magnitudeEnumerator = [[maxCacheSizePopUp itemArray] reverseObjectEnumerator];
	NSMenuItem			*item = nil;
	while (item = [magnitudeEnumerator nextObject])
	{
		float	magnitude = pow(2.0, [item tag]);
		
		if (maxCacheSize >= magnitude)
		{
			[maxCacheSizeField setIntValue:maxCacheSize / magnitude];
			[maxCacheSizePopUp selectItem:item];
			break;
		}
	}
	magnitudeEnumerator = [[minFreeSpacePopUp itemArray] reverseObjectEnumerator];
	item = nil;
	while (item = [magnitudeEnumerator nextObject])
	{
		float	magnitude = pow(2.0, [item tag]);
		
		if (minFreeSpace >= magnitude)
		{
			[minFreeSpaceField setIntValue:minFreeSpace / magnitude];
			[minFreeSpacePopUp selectItem:item];
			break;
		}
	}
	
		// Get the name and icon of the volume the cache lives on.
	struct statfs	fsStruct;
	statfs([[FlickrImageSource imageCachePath] fileSystemRepresentation], &fsStruct);
	NSString		*volumeRootPath = [NSString stringWithCString:fsStruct.f_mntonname];
	[volumeImageView setImage:[[NSWorkspace sharedWorkspace] iconForFile:volumeRootPath]];
	[volumeNameField setStringValue:[[NSFileManager defaultManager] displayNameAtPath:volumeRootPath]];
}


- (void)didSelect
{
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == maxCacheSizeField)
		[FlickrImageSource setMaxCacheSize:[maxCacheSizeField intValue] * pow(2.0, [[maxCacheSizePopUp selectedItem] tag])];
	else if ([notification object] == minFreeSpaceField)
		[FlickrImageSource setMinFreeSpace:[minFreeSpaceField intValue] * pow(2.0, [[minFreeSpacePopUp selectedItem] tag])];
	else if ([notification object] == searchTextField)
		[self getMatchingGroups];
}


- (void)showFavoriteGroups:(NSNotification *)notification
{
	[mainTabView selectTabViewItemWithIdentifier:@"Favorite Groups"];
}


- (void)showSignedInState
{
	if ([FlickrImageSource signedIn])
	{
		[signInOutButton setTitle:@"Sign Out"];
		[signInOutField setStringValue:([FlickrImageSource signedInUserName] ? [FlickrImageSource signedInUserName] : @"")];
	}
	else
	{
		[signInOutButton setTitle:@"Sign In"];
		[signInOutField setStringValue:@""];
	}
}


#pragma mark -
#pragma mark Local Copies tab


- (IBAction)setMaxCacheSizeMagnitude:(id)sender
{
	[FlickrImageSource setMaxCacheSize:[maxCacheSizeField intValue] * pow(2.0, [[maxCacheSizePopUp selectedItem] tag])];
}


- (IBAction)setMinFreeSpaceMagnitude:(id)sender
{
	[FlickrImageSource setMinFreeSpace:[minFreeSpaceField intValue] * pow(2.0, [[minFreeSpacePopUp selectedItem] tag])];
}


- (IBAction)deleteCachedImages:(id)sender
{
	[FlickrImageSource purgeCache];
}


#pragma mark -
#pragma mark Favorite Groups tab


- (int)numberOfRowsInFavoritesTableView
{
	return [[FlickrImageSource favoriteGroups] count];
}


- (id)objectValueForFavoritesTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	MacOSaiXFlickrGroup	*group = [[FlickrImageSource favoriteGroups] objectAtIndex:row];
	
	if ([[tableColumn identifier] isEqualToString:@"Name"])
		return [group name];
	
	return nil;
}


- (IBAction)visitGroupPage:(id)sender
{
	MacOSaiXFlickrGroup	*group = nil;
	
	if (sender == favoriteGroupsTable)
		group = [[FlickrImageSource favoriteGroups] objectAtIndex:[favoriteGroupsTable selectedRow]];
	else if (sender == searchGroupsView)
		group = [matchingGroups objectAtIndex:[searchGroupsView selectedRow]];
	else if (sender == browseGroupsView)
		group = [browseGroupsView itemAtRow:[browseGroupsView selectedRow]];
	
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.flickr.com/groups/%@/", [group groupID]]]];
}


- (IBAction)showAddGroups:(id)sender
{
	categories = [[NSMutableArray alloc] init];
	
	[self showSignedInState];
	
	[NSApp beginSheet:addGroupsSheet 
	   modalForWindow:[removeGroupsButton window] 
		modalDelegate:self 
	   didEndSelector:@selector(addGroupsSheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}


- (NSArray *)selectedGroupsToAdd
{
	NSMutableArray	*selectedGroups = [NSMutableArray array];
	
	if ([[[addGroupsTabView selectedTabViewItem] identifier] isEqualToString:@"Search"])
	{
		NSIndexSet		*indexSet = [searchGroupsView selectedRowIndexes];
		unsigned long	currentIndex = [indexSet firstIndex];
		while (currentIndex != NSNotFound)
		{
			[selectedGroups addObject:[matchingGroups objectAtIndex:currentIndex]];
			currentIndex = [indexSet indexGreaterThanIndex:currentIndex];
		}
	}
	else	// Browse
	{
		NSIndexSet		*indexSet = [browseGroupsView selectedRowIndexes];
		unsigned long	currentIndex = [indexSet firstIndex];
		while (currentIndex != NSNotFound)
		{
			id	rowItem = [browseGroupsView itemAtRow:currentIndex];
			
			if ([rowItem isKindOfClass:[MacOSaiXFlickrGroup class]])
				[selectedGroups addObject:rowItem];
			currentIndex = [indexSet indexGreaterThanIndex:currentIndex];
		}
	}
	
	return selectedGroups;
}

- (void)addGroupsSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton)
	{
		NSEnumerator		*groupEnumerator = [[self selectedGroupsToAdd] objectEnumerator];
		MacOSaiXFlickrGroup	*group = nil;
		
		while (group = [groupEnumerator nextObject])
			[FlickrImageSource addFavoriteGroup:group];
		
		[favoriteGroupsTable reloadData];
	}
	
	[categories release];
	categories = nil;
	[myGroups release];
	myGroups = nil;
}


- (IBAction)removeGroups:(id)sender
{
	NSArray			*favoriteGroups = [FlickrImageSource favoriteGroups];
	NSIndexSet		*indexSet = [favoriteGroupsTable selectedRowIndexes];
	unsigned long	currentIndex = [indexSet firstIndex];
	while (currentIndex != NSNotFound)
	{
		[FlickrImageSource removeFavoriteGroup:[favoriteGroups objectAtIndex:currentIndex]];
		currentIndex = [indexSet indexGreaterThanIndex:currentIndex];
	}
	
	[favoriteGroupsTable reloadData];
}


#pragma mark -
#pragma mark Group searching


- (void)getMatchingGroups
{
	[[self class] cancelPreviousPerformRequestsWithTarget:self];
	
	[self performSelector:@selector(getMatchingGroupsAfterDelay) withObject:nil afterDelay:0.5];
}


- (void)getMatchingGroupsAfterDelay
{
	[matchingGroupsCountField setStringValue:@"Searching..."];
	[matchingGroupsIndicator startAnimation:self];
	
	if (matchingGroups)
		[matchingGroups removeAllObjects];
	else
		matchingGroups = [[NSMutableArray alloc] init];
	
	[searchGroupsView reloadData];
	
	[NSThread detachNewThreadSelector:@selector(getMatchingGroupsInThread:) toTarget:self withObject:[NSString stringWithString:[searchTextField stringValue]]];
}


void *createGetMatchingGroupsStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	volatile id			newObject = nil;
	
	NS_DURING
		if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeElement)
		{
			NSString			*elementType = (NSString *)CFXMLNodeGetString(node);
			CFXMLElementInfo	*nodeInfo = (CFXMLElementInfo *)CFXMLNodeGetInfoPtr(node);
			NSDictionary		*nodeAttributes = (NSDictionary *)nodeInfo->attributes;
			
			if ([elementType isEqualToString:@"groups"])
				newObject = (NSMutableArray *)info;
			else if ([elementType isEqualToString:@"group"])
			{
				NSMutableString	*groupName = [nodeAttributes objectForKey:@"name"];
				
				[groupName replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, [groupName length])];
				[groupName replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, [groupName length])];
				[groupName replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, [groupName length])];
				[groupName replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, [groupName length])];
				
				newObject = [[MacOSaiXFlickrGroup groupWithName:groupName 
														groupID:[nodeAttributes objectForKey:@"nsid"]
													   is18Plus:(![[nodeAttributes objectForKey:@"eighteenplus"] isEqualToString:@"0"])] retain];
			}
		}
	NS_HANDLER
		CFXMLParserAbort(parser, kCFXMLErrorMalformedStartTag, 
						 (CFStringRef)[NSString stringWithFormat:@"Could not create structure (%@)", [localException reason]]);
	NS_ENDHANDLER
	
	[pool release];
	
	// Return the object that will be passed to the addChild and endStructure callbacks.
	return (void *)newObject;
}


void addGetMatchingGroupsChild(CFXMLParserRef parser, void *parent, void *child, void *info)
{
	if (parent)
	{
		[(NSMutableArray *)parent addObject:(MacOSaiXFlickrGroup *)child];
		[(MacOSaiXFlickrGroup *)child release];
	}
}


void endGetMatchingGroupsStructure(CFXMLParserRef parser, void *newObject, void *info)
{
}


- (void)getMatchingGroupsInThread:(NSString *)queryString
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSError				*error = nil;
	
	if ([queryString length] > 0)
	{
		WSMethodInvocationRef	flickrInvocation = WSMethodInvocationCreate((CFURLRef)[NSURL URLWithString:@"http://www.flickr.com/services/xmlrpc/"],
																			CFSTR("flickr.groups.search"),
																			kWSXMLRPCProtocol);
		NSDictionary			*parameters = [FlickrImageSource authenticatedParameters:[NSDictionary dictionaryWithObjectsAndKeys:
																								queryString, @"text", 
																								@"500", @"per_page", 
																								nil]], 
								*wrappedParameters = [NSDictionary dictionaryWithObject:parameters forKey:@"foo"];
		WSMethodInvocationSetParameters(flickrInvocation, (CFDictionaryRef)wrappedParameters, nil);
		CFDictionaryRef			results = WSMethodInvocationInvoke(flickrInvocation);
		
		if (WSMethodResultIsFault(results))
		{
			error = [FlickrImageSource errorFromWSMethodResults:(NSDictionary *)results];
		}
		else
		{
				// Create a parser with the option to skip whitespace.
			NSString				*xmlString = [(NSDictionary *)results objectForKey:(NSString *)kWSMethodInvocationResult];
			NSData					*xmlData = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
			CFXMLParserCallBacks	callbacks = {0, createGetMatchingGroupsStructure, addGetMatchingGroupsChild, endGetMatchingGroupsStructure, NULL, NULL};
			CFXMLParserContext		context = {0, matchingGroups, NULL, NULL, NULL};
			CFXMLParserRef			parser = CFXMLParserCreate(kCFAllocatorDefault, 
															   (CFDataRef)xmlData, 
															   NULL, // data source URL for resolving external refs
															   kCFXMLParserSkipWhitespace, 
															   kCFXMLNodeCurrentVersion, 
															   &callbacks, 
															   &context);
			
				// Invoke the parser.
			if (!CFXMLParserParse(parser))
			{
					// An error occurred parsing the XML.
				NSString	*parserError = (NSString *)CFXMLParserCopyErrorDescription(parser);
				
				NSString	*errorMessage = [NSString stringWithFormat:@"Error at line %d: %@", CFXMLParserGetLineNumber(parser), parserError];
				
				error = [NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																			errorMessage, NSLocalizedDescriptionKey, 
																			nil]];
				
				[parserError release];
			}
			
			CFRelease(parser);
		}
		
		CFRelease(results);
	}
	
	[matchingGroups sortUsingSelector:@selector(compare:)];
	[self performSelectorOnMainThread:@selector(displayMatchingGroups:) withObject:error waitUntilDone:NO];
	
	[pool release];
}


- (void)displayMatchingGroups:(NSError *)error
{
	[matchingGroupsIndicator stopAnimation:self];
	if ([matchingGroups count] == 0)
		[matchingGroupsCountField setStringValue:@"No matching groups found."];
	else
		[matchingGroupsCountField setStringValue:[NSString stringWithFormat:@"%d groups", [matchingGroups count]]];
	[searchGroupsView reloadData];
}


- (int)numberOfRowsInMatchingGroupsTableView
{
	return [matchingGroups count];
}


- (id)objectValueForMatchingGroupsTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	MacOSaiXFlickrGroup	*group = [matchingGroups objectAtIndex:row];
	
	if ([[tableColumn identifier] isEqualToString:@"Name"])
		return [group name];
	else if ([[tableColumn identifier] isEqualToString:@"18+"])
		return ([group is18Plus] ? @"18+" : @"");
	
	return nil;
}


#pragma mark -
#pragma mark Group browsing


void *createGetGroupsStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	volatile id			newObject = nil;
	
	NS_DURING
		if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeElement)
		{
			NSString			*elementType = (NSString *)CFXMLNodeGetString(node);
			CFXMLElementInfo	*nodeInfo = (CFXMLElementInfo *)CFXMLNodeGetInfoPtr(node);
			NSDictionary		*nodeAttributes = (NSDictionary *)nodeInfo->attributes;
			
			if ([elementType isEqualToString:@"groups"])
				newObject = (NSMutableArray *)info;
			else if ([elementType isEqualToString:@"group"])
			{
				NSMutableString	*groupName = [nodeAttributes objectForKey:@"name"];
				
				[groupName replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, [groupName length])];
				[groupName replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, [groupName length])];
				[groupName replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, [groupName length])];
				[groupName replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, [groupName length])];
				
				newObject = [[MacOSaiXFlickrGroup groupWithName:groupName 
														groupID:[nodeAttributes objectForKey:@"nsid"]
													   is18Plus:NO] retain];	// TBD: need to send additional query to determine 18+ status?
			}
		}
	NS_HANDLER
		CFXMLParserAbort(parser, kCFXMLErrorMalformedStartTag, 
						 (CFStringRef)[NSString stringWithFormat:@"Could not create structure (%@)", [localException reason]]);
	NS_ENDHANDLER
	
	[pool release];
	
	// Return the object that will be passed to the addChild and endStructure callbacks.
	return (void *)newObject;
}


void addGetGroupsChild(CFXMLParserRef parser, void *parent, void *child, void *info)
{
	if (parent)
	{
		[(MacOSaiXFlickrCategory *)parent addGroup:(MacOSaiXFlickrGroup *)child];
		[(MacOSaiXFlickrGroup *)child release];
	}
}


void endGetGroupsStructure(CFXMLParserRef parser, void *newObject, void *info)
{
}


- (NSError *)getMyGroups
{
	NSError					*error = nil;
	
	[myGroups removeAllGroups];
	
	WSMethodInvocationRef	flickrInvocation = WSMethodInvocationCreate((CFURLRef)[NSURL URLWithString:@"http://www.flickr.com/services/xmlrpc/"],
																		CFSTR("flickr.groups.pools.getGroups"),
																		kWSXMLRPCProtocol);
	NSDictionary			*parameters = [FlickrImageSource authenticatedParameters:[NSDictionary dictionary]], 
							*wrappedParameters = [NSDictionary dictionaryWithObject:parameters forKey:@"foo"];
	WSMethodInvocationSetParameters(flickrInvocation, (CFDictionaryRef)wrappedParameters, nil);
	CFDictionaryRef			results = WSMethodInvocationInvoke(flickrInvocation);
	
	if (WSMethodResultIsFault(results))
		error = [FlickrImageSource errorFromWSMethodResults:(NSDictionary *)results];
	else
	{
			// Create a parser with the option to skip whitespace.
		NSString				*xmlString = [(NSDictionary *)results objectForKey:(NSString *)kWSMethodInvocationResult];
		NSData					*xmlData = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
		CFXMLParserCallBacks	callbacks = {0, createGetGroupsStructure, addGetGroupsChild, endGetGroupsStructure, NULL, NULL};
		CFXMLParserContext		context = {0, myGroups, NULL, NULL, NULL};
		CFXMLParserRef			parser = CFXMLParserCreate(kCFAllocatorDefault, 
														   (CFDataRef)xmlData, 
														   NULL, // data source URL for resolving external refs
														   kCFXMLParserSkipWhitespace, 
														   kCFXMLNodeCurrentVersion, 
														   &callbacks, 
														   &context);
		
			// Invoke the parser.
		if (!CFXMLParserParse(parser))
		{
				// An error occurred parsing the XML.
			NSString	*parserError = (NSString *)CFXMLParserCopyErrorDescription(parser);
			
			NSString	*errorMessage = [NSString stringWithFormat:@"Error at line %d: %@", CFXMLParserGetLineNumber(parser), parserError];
			
			error = [NSError errorWithDomain:@"" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																		errorMessage, NSLocalizedDescriptionKey, 
																		nil]];
			
			[parserError release];
		}
		
		CFRelease(parser);
	}
	
	CFRelease(results);
	
	return error;
}


- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (!item)
	{
		if ([categories count] == 0)
		{
				// Fetch the root categories
//			MacOSaiXFlickrCategory	*dummy = [MacOSaiXFlickrCategory categoryWithName:nil catID:@"0"];
//			[categories addObjectsFromArray:[dummy children]];
			
			myGroups = [[MacOSaiXFlickrCategory categoryWithName:@"My Groups" catID:@"-1"] retain];
			[categories addObject:myGroups];

			if ([FlickrImageSource signedIn])
			{
				NSError	*error = [self getMyGroups];
				
				if (error)
					NSRunAlertPanel(@"Could not get your list of groups.", [error localizedDescription], @"OK", nil, nil, [browseGroupsView window]);
			}
			else if ([FlickrImageSource signingIn])
				[myGroups addGroup:[MacOSaiXFlickrGroup groupWithName:@"Signing in..." groupID:nil is18Plus:NO]];
			else
				[myGroups addGroup:[MacOSaiXFlickrGroup groupWithName:@"Sign in to get the list of your groups." groupID:nil is18Plus:NO]];
			
//			[browseGroupsView reloadItem:myGroups reloadChildren:YES];
		}
		
		return [categories count];
	}
	else if ([item isKindOfClass:[MacOSaiXFlickrCategory class]])
		return [[item children] count];
	else
		return 0;
}


- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	if (!item)
		return [categories objectAtIndex:index];
	else if ([item isKindOfClass:[MacOSaiXFlickrCategory class]])
		return [[item children] objectAtIndex:index];
	else
		return nil;
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [item isKindOfClass:[MacOSaiXFlickrCategory class]];
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([[tableColumn identifier] isEqualToString:@"Name"])
		return [item name];
	else	
		return nil;
}	


- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([cell isKindOfClass:[NSButtonCell class]])
	{
		if ([[tableColumn identifier] isEqualToString:@"Visit Group Page"] && 
			[item isKindOfClass:[MacOSaiXFlickrGroup class]] && 
			[item groupID] != nil)
		{
			[cell setEnabled:YES];
			[cell setImagePosition:NSImageOnly];
		}
		else
		{
			[cell setEnabled:NO];
			[cell setImagePosition:NSNoImage];
		}
	}
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == browseGroupsView)
		[addGroupsButton setEnabled:([[self selectedGroupsToAdd] count] > 0)];
}


#pragma mark -


- (IBAction)signInOut:(id)sender
{
	if ([FlickrImageSource signedIn])
		[FlickrImageSource signOut];
	else
	{
		NSError	*signInError = [FlickrImageSource signIn];
		
		if (signInError)
			NSRunAlertPanel(@"Could not sign in to flickr", [signInError localizedDescription], @"OK", nil, nil, [signInOutButton window]);
	}
	
	[self showSignedInState];
}


- (void)authenticationDidChange:(NSNotification *)notification
{
	[self showSignedInState];
	
	if ([FlickrImageSource signedIn])
	{
		if ([[myGroups children] count] == 1 && ![[[myGroups children] lastObject] groupID])
			[self getMyGroups];
		
		[browseGroupsView reloadData];
	}
}


- (IBAction)cancelAddGroups:(id)sender
{
	[NSApp endSheet:addGroupsSheet returnCode:NSCancelButton];
}


- (IBAction)addGroups:(id)sender
{
	[NSApp endSheet:addGroupsSheet returnCode:NSOKButton];
}


#pragma mark -


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (tableView == favoriteGroupsTable)
		return [self numberOfRowsInFavoritesTableView];
	else if (tableView == searchGroupsView)
		return [self numberOfRowsInMatchingGroupsTableView];
	
	return 0;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if (tableView == favoriteGroupsTable)
		return [self objectValueForFavoritesTableColumn:tableColumn row:row];
	else if (tableView == searchGroupsView)
		return [self objectValueForMatchingGroupsTableColumn:tableColumn row:row];
	
	return nil;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == favoriteGroupsTable)
		[removeGroupsButton setEnabled:([favoriteGroupsTable selectedRow] != -1)];
	else if ([notification object] == searchGroupsView)
		[addGroupsButton setEnabled:([[self selectedGroupsToAdd] count] > 0)];
}


#pragma mark -


- (void)willUnselect
{
}


- (void)didUnselect
{
}


@end

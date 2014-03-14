/*
	FlickrImageSourceController.h
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "FlickrImageSourceController.h"

#import "MacOSaiXFlickrGroup.h"


@interface FlickrImageSourceController (PrivateMethods)
- (void)getCountOfMatchingPhotos;
@end


@implementation FlickrImageSourceController


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"Flickr Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(374.0, 253.0);
}


- (NSResponder *)firstResponder
{
	return queryField;
}


- (void)populateGroupPopUp
{
	[groupPopUp removeAllItems];
	
	NSMenuItem	*anyGroupItem = [[[NSMenuItem alloc] initWithTitle:@"Any Group" action:@selector(setGroup:) keyEquivalent:@""] autorelease];
	[anyGroupItem setTarget:self];
	[[groupPopUp menu] addItem:anyGroupItem];
	
	NSMutableArray		*favoriteGroups = [NSMutableArray arrayWithArray:[FlickrImageSource favoriteGroups]];
	
	if ([currentImageSource queryGroup] && ![favoriteGroups containsObject:[currentImageSource queryGroup]])
	{
		[favoriteGroups addObject:[currentImageSource queryGroup]];
		[favoriteGroups sortUsingSelector:@selector(compare:)];
	}
	
	if ([favoriteGroups count] > 0)
	{
		[[groupPopUp menu] addItem:[NSMenuItem separatorItem]];
		
		NSEnumerator		*groupEnumerator = [favoriteGroups objectEnumerator];
		MacOSaiXFlickrGroup	*group = nil;
		while (group = [groupEnumerator nextObject])
		{
			NSMenuItem	*groupItem = [[[NSMenuItem alloc] initWithTitle:[group name] action:@selector(setGroup:) keyEquivalent:@""] autorelease];
			[groupItem setTarget:self];
			[groupItem setRepresentedObject:group];
			[[groupPopUp menu] addItem:groupItem];
		}
	}
	
	[[groupPopUp menu] addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem	*setupFavoritesItem = [[[NSMenuItem alloc] initWithTitle:@"Choose Another Group..." action:@selector(setupFavorites:) keyEquivalent:@""] autorelease];
	[setupFavoritesItem setTarget:self];
	[[groupPopUp menu] addItem:setupFavoritesItem];
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	currentImageSource = (FlickrImageSource *)imageSource;
	
	[self populateGroupPopUp];
	
	[queryField setStringValue:([currentImageSource queryString] ? [currentImageSource queryString] : @"")];
	[queryTypeMatrix selectCellAtRow:[currentImageSource queryType] column:0];
	
	if ([currentImageSource queryGroup])
		[groupPopUp selectItemAtIndex:[groupPopUp indexOfItemWithRepresentedObject:[currentImageSource queryGroup]]];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(favoriteGroupsDidChange:) 
												 name:MacOSaiXFlickrFavoriteGroupsDidChangeNotification 
											   object:nil];
	
	if ([[queryField stringValue] length] > 0)
		[self getCountOfMatchingPhotos];
}


- (void)favoriteGroupsDidChange:(NSNotification *)notification
{
	[self populateGroupPopUp];
}


- (BOOL)settingsAreValid
{
	return ([[currentImageSource queryString] length] > 0 || [currentImageSource queryGroup]);
}


- (IBAction)visitFlickr:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.flickr.com/"]];
}


#pragma mark
#pragma mark Count of matching photos


- (void)getCountOfMatchingPhotos
{
	[[self class] cancelPreviousPerformRequestsWithTarget:self];
	
	[self performSelector:@selector(getCountOfMatchingPhotos:) withObject:nil afterDelay:0.5];
}


- (void)getCountOfMatchingPhotos:(NSTimer *)timer
{
	if (currentImageSource)
	{
		[matchingPhotosCount setStringValue:@""];
		[matchingPhotosIndicator startAnimation:self];
		
		[NSThread detachNewThreadSelector:@selector(getPhotoCount:) toTarget:self withObject:[NSString stringWithString:[currentImageSource queryString]]];
	}
}


- (void)getPhotoCount:(NSString *)queryString
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSString			*photoCount = NSLocalizedString(@"unknown", @"");
	
	if ([queryString length] > 0)
	{
		WSMethodInvocationRef	flickrInvocation = WSMethodInvocationCreate((CFURLRef)[NSURL URLWithString:@"http://www.flickr.com/services/xmlrpc/"],
																			CFSTR("flickr.photos.search"),
																			kWSXMLRPCProtocol);
		NSMutableDictionary		*parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
													@"514c14062bc75c91688dfdeacc6252c7", @"api_key", 
													[NSNumber numberWithInt:1], @"page", 
													[NSNumber numberWithInt:1], @"per_page", 
													nil];
		
		if ([currentImageSource queryType] == matchAllTags)
		{
			[parameters setObject:queryString forKey:@"tags"];
			[parameters setObject:@"all" forKey:@"tag_mode"];
		}
		else if ([currentImageSource queryType] == matchAnyTags)
		{
			[parameters setObject:queryString forKey:@"tags"];
			[parameters setObject:@"any" forKey:@"tag_mode"];
		}
		else
			[parameters setObject:queryString forKey:@"text"];
		
		NSDictionary			*wrappedParameters = [NSDictionary dictionaryWithObject:parameters forKey:@"foo"];
		WSMethodInvocationSetParameters(flickrInvocation, (CFDictionaryRef)wrappedParameters, nil);
		CFDictionaryRef			results = WSMethodInvocationInvoke(flickrInvocation);
		
		if (!WSMethodResultIsFault(results))
		{
				// Extract the count of photos from the XML response.
			NSString	*xmlString = [(NSDictionary *)results objectForKey:(NSString *)kWSMethodInvocationResult];
			NSScanner	*xmlScanner = [NSScanner scannerWithString:xmlString];
			
			if ([xmlScanner scanUpToString:@"total=\"" intoString:nil] &&
				[xmlScanner scanString:@"total=\"" intoString:nil])
				[xmlScanner scanUpToString:@"\"" intoString:&photoCount];
		}
		else if ([[(NSDictionary *)results objectForKey:(id)kWSFaultString] isEqualToString:(NSString *)kWSNetworkStreamFaultString])
			photoCount = NSLocalizedString(@"Can't reach flickr.", @"");
		
		CFRelease(results);
	}
	
	[self performSelectorOnMainThread:@selector(displayMatchingPhotoCount:) withObject:photoCount waitUntilDone:NO];
	
	[pool release];
}


- (void)displayMatchingPhotoCount:(NSString *)photoCount
{
	[matchingPhotosIndicator stopAnimation:self];
	[matchingPhotosCount setStringValue:photoCount];
}


#pragma mark


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == queryField)
	{
		NSString	*queryString = [[queryField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		[currentImageSource setQueryString:queryString];
		
		[self getCountOfMatchingPhotos];
	}
}


- (IBAction)setQueryType:(id)sender
{
	[currentImageSource setQueryType:[queryTypeMatrix selectedRow]];
	
	[self getCountOfMatchingPhotos];
}


- (IBAction)setGroup:(id)sender
{
	MacOSaiXFlickrGroup	*group = [[groupPopUp selectedItem] representedObject];
	
	[currentImageSource setQueryGroup:group];
}


- (IBAction)setupFavorites:(id)sender
{
		// Hack: open our pref panel
	[[NSApp delegate] performSelector:@selector(openPreferences:) withObject:[currentImageSource class]];
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXFlickrShowFavoriteGroupsNotification object:nil];
	[groupPopUp selectItemAtIndex:0];
}


- (void)editingComplete
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[self class] cancelPreviousPerformRequestsWithTarget:self];
	
	currentImageSource = nil;
}


- (void)dealloc
{
	[editorView release];
	
	[super dealloc];
}


@end

/*
	FlickrImageSourceController.h
	MacOSaiX

	Created by Frank Midgley on Mon Nov 14 2005.
	Copyright (c) 2005 Frank M. Midgley. All rights reserved.
*/

#import "FlickrImageSourceController.h"

#import "FlickrImageSource.h"


@interface MacOSaiXFlickrImageSourceEditor (PrivateMethods)
- (void)getCountOfMatchingPhotos;
@end


@implementation MacOSaiXFlickrImageSourceEditor


- (id)initWithDelegate:(id<MacOSaiXEditorDelegate>)inDelegate;
{
	if (self = [super init])
		delegate = inDelegate;
	
	return self;
}


- (id<MacOSaiXEditorDelegate>)delegate
{
	return delegate;
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"Flickr Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(275.0, 137.0);
}


- (NSSize)maximumSize
{
	return NSMakeSize(374.0, 137.0);
}


- (NSResponder *)firstResponder
{
	return queryField;
}


- (void)editDataSource:(id<MacOSaiXImageSource>)imageSource
{
	currentImageSource = (MacOSaiXFlickrImageSource *)imageSource;
	
	[self refresh];
}


- (IBAction)visitFlickr:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.flickr.com"]];
}


- (void)getCountOfMatchingPhotos
{
	if (matchingPhotosTimer)
	{
		[matchingPhotosTimer invalidate];
		[matchingPhotosTimer release];
	}
	
	matchingPhotosTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5 
															target:self 
														  selector:@selector(getCountOfMatchingPhotos:) 
														  userInfo:nil 
														   repeats:NO] retain];
}


- (void)getCountOfMatchingPhotos:(NSTimer *)timer
{
	if (currentImageSource)
	{
		[matchingPhotosCount setHidden:YES];
		[matchingPhotosIndicator setHidden:NO];
		[matchingPhotosIndicator startAnimation:self];
		
		[NSThread detachNewThreadSelector:@selector(getPhotoCount) toTarget:self withObject:nil];
	}
	
	[matchingPhotosTimer release];
	matchingPhotosTimer = nil;
}


- (void)getPhotoCount
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSString			*queryString = [currentImageSource queryString], 
						*photoCount = NSLocalizedString(@"unknown", @"");
	
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
		else if ([currentImageSource queryType] == matchAnyTag)
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
		
		CFRelease(results);
	}
	
	[self performSelectorOnMainThread:@selector(displayMatchingPhotoCount:) withObject:photoCount waitUntilDone:NO];
	
	[pool release];
}


- (void)displayMatchingPhotoCount:(NSString *)photoCount
{
	[matchingPhotosIndicator stopAnimation:self];
	[matchingPhotosIndicator setHidden:YES];
	[matchingPhotosCount setStringValue:photoCount];
	[matchingPhotosCount setHidden:NO];
	
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == queryField)
	{
		NSString	*previousValue = [[[currentImageSource queryString] retain] autorelease], 
					*queryString = [[queryField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		[currentImageSource setQueryString:queryString];
		
		[self getCountOfMatchingPhotos];
		
		[[self delegate] dataSource:currentImageSource 
					   didChangeKey:@"queryString" 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Change QueryString", @"")]; 
	}
}


- (IBAction)setQueryType:(id)sender
{
	int	previousValue = [currentImageSource queryType];
	
	[currentImageSource setQueryType:[queryTypeMatrix selectedRow]];
	
	[self getCountOfMatchingPhotos];
	
	[[self delegate] dataSource:currentImageSource 
				   didChangeKey:@"queryType" 
					  fromValue:[NSNumber numberWithInt:previousValue] 
					 actionName:NSLocalizedString(@"Change Query Type", @"")]; 
}


- (BOOL)mouseDownInMosaic:(NSEvent *)event
{
	return NO;
}


- (BOOL)mouseDraggedInMosaic:(NSEvent *)event
{
	return NO;
}


- (BOOL)mouseUpInMosaic:(NSEvent *)event
{
	return NO;
}


- (void)refresh
{
	if ([currentImageSource queryString])
	{
		[queryField setStringValue:[currentImageSource queryString]];
		if ([[currentImageSource queryString] length] > 0)
			[self getCountOfMatchingPhotos];
	}
	else
		[queryField setStringValue:@""];
	
	[queryTypeMatrix selectCellAtRow:[currentImageSource queryType] column:0];
}


- (void)editingDidComplete
{
	delegate = nil;
}


@end

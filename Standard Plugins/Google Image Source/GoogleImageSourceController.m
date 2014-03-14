/*
	GoogleImageSourceController.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

#import "GoogleImageSourceController.h"


@implementation GoogleImageSourceController


- (NSView *)editorView
{
	if (!editorView)
	{
		[NSBundle loadNibNamed:@"Google Image Source" owner:self];
		
		[[collectionPopUpButton itemAtIndex:0] setRepresentedObject:@""];
		
		NSArray			*collections = [GoogleImageSource collections];
		NSEnumerator	*collectionEnumerator = [collections objectEnumerator];
		NSDictionary	*collectionDict;
		
		while (collectionDict = [collectionEnumerator nextObject])
		{
			[collectionPopUpButton addItemWithTitle:[collectionDict objectForKey:@"Name"]];
			[[collectionPopUpButton lastItem] setRepresentedObject:[collectionDict objectForKey:@"Query value"]];
		}
	}
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(486.0, 350.0);
}


- (NSResponder *)firstResponder
{
	return requiredTermsTextField;
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	currentImageSource = (GoogleImageSource *)imageSource;
	
	[requiredTermsTextField setStringValue:([currentImageSource requiredTerms] ? [currentImageSource requiredTerms] : @"")];
	[optionalTermsTextField setStringValue:([currentImageSource optionalTerms] ? [currentImageSource optionalTerms] : @"")];
	[excludedTermsTextField setStringValue:([currentImageSource excludedTerms] ? [currentImageSource excludedTerms] : @"")];
	[contentTypePopUpButton selectItemAtIndex:[currentImageSource contentType]];
	[colorSpacePopUpButton selectItemAtIndex:[currentImageSource colorSpace]];
	[siteTextField setStringValue:([currentImageSource siteString] ? [currentImageSource siteString] : @"")];
	[adultContentFilteringPopUpButton selectItemAtIndex:[currentImageSource adultContentFiltering]];
	[collectionPopUpButton selectItemAtIndex:[collectionPopUpButton indexOfItemWithRepresentedObject:[currentImageSource collectionQueryValue]]];
}


- (BOOL)settingsAreValid
{
	return ([[currentImageSource requiredTerms] length] > 0 || 
			[[currentImageSource optionalTerms] length] > 0 || 
			[[currentImageSource excludedTerms] length] > 0 || 
			[[currentImageSource siteString] length] > 0);
}


- (void)editingComplete
{
	currentImageSource = nil;
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == requiredTermsTextField)
		[currentImageSource setRequiredTerms:[requiredTermsTextField stringValue]];
	else if ([notification object] == optionalTermsTextField)
		[currentImageSource setOptionalTerms:[optionalTermsTextField stringValue]];
	else if ([notification object] == excludedTermsTextField)
		[currentImageSource setExcludedTerms:[excludedTermsTextField stringValue]];
	else if ([notification object] == siteTextField)
		[currentImageSource setSiteString:[siteTextField stringValue]];
}


- (IBAction)setContentType:(id)sender
{
	[currentImageSource setContentType:[contentTypePopUpButton indexOfSelectedItem]];
}


- (IBAction)setColorSpace:(id)sender
{
	[currentImageSource setColorSpace:[colorSpacePopUpButton indexOfSelectedItem]];
}


- (IBAction)setAdultContentFiltering:(id)sender
{
	[currentImageSource setAdultContentFiltering:[adultContentFilteringPopUpButton indexOfSelectedItem]];
}


- (IBAction)setCollection:(id)sender
{
	[currentImageSource setCollectionQueryValue:[[collectionPopUpButton selectedItem] representedObject]];
}


- (void)dealloc
{
	[editorView release];
	
	[super dealloc];
}


@end

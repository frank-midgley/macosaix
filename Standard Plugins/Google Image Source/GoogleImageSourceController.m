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
		[NSBundle loadNibNamed:@"Google Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(523.0, 290.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
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
	[colorSpacePopUpButton selectItemAtIndex:[currentImageSource colorSpace]];
	[siteTextField setStringValue:([currentImageSource siteString] ? [currentImageSource siteString] : @"")];
	[adultContentFilteringPopUpButton selectItemAtIndex:[currentImageSource adultContentFiltering]];
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


- (IBAction)setColorSpace:(id)sender
{
	[currentImageSource setColorSpace:[colorSpacePopUpButton indexOfSelectedItem]];
}


- (IBAction)setAdultContentFiltering:(id)sender
{
	[currentImageSource setAdultContentFiltering:[adultContentFilteringPopUpButton indexOfSelectedItem]];
}


- (void)dealloc
{
	[super dealloc];
}


@end

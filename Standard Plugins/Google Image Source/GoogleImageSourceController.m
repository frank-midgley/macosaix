/*
	GoogleImageSourceController.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

#import "GoogleImageSourceController.h"


@implementation GoogleImageSourceController


- (NSView *)imageSourceView
{
	if (!imageSourceView)
		[NSBundle loadNibNamed:@"Google Image Source" owner:self];
	
	return imageSourceView;
}


- (void)setOKButton:(NSButton *)button
{
	okButton = button;
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[currentImageSource autorelease];
	currentImageSource = [imageSource retain];
	
	[requiredTermsTextField setStringValue:([currentImageSource requiredTerms] ? [currentImageSource requiredTerms] : @"")];
	[optionalTermsTextField setStringValue:([currentImageSource optionalTerms] ? [currentImageSource optionalTerms] : @"")];
	[excludedTermsTextField setStringValue:([currentImageSource excludedTerms] ? [currentImageSource excludedTerms] : @"")];
	[colorSpacePopUpButton selectItemAtIndex:[currentImageSource colorSpace]];
	[siteTextField setStringValue:([currentImageSource siteString] ? [currentImageSource siteString] : @"")];
	[adultContentFilteringPopUpButton selectItemAtIndex:[currentImageSource adultContentFiltering]];
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
	[currentImageSource setColorSpace:[adultContentFilteringPopUpButton indexOfSelectedItem]];
}


- (void)dealloc
{
	[currentImageSource release];
	
	[super dealloc];
}


@end

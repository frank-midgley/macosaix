/*
	GoogleImageSourceController.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

#import "GoogleImageSourceController.h"

#import "GoogleImageSource.h"


@implementation MacOSaiXGoogleImageSourceEditor


- (id)initWithDelegate:(id<MacOSaiXDataSourceEditorDelegate>)inDelegate;
{
	if (self = [super init])
		delegate = inDelegate;
	
	return self;
}


- (id<MacOSaiXDataSourceEditorDelegate>)delegate
{
	return delegate;
}


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


- (void)editDataSource:(id<MacOSaiXImageSource>)imageSource
{
	currentImageSource = (MacOSaiXGoogleImageSource *)imageSource;
	
	// TODO: deal with simple options fields
	
	[requiredTermsTextField setStringValue:([currentImageSource requiredTerms] ? [currentImageSource requiredTerms] : @"")];
	[optionalTermsTextField setStringValue:([currentImageSource optionalTerms] ? [currentImageSource optionalTerms] : @"")];
	[excludedTermsTextField setStringValue:([currentImageSource excludedTerms] ? [currentImageSource excludedTerms] : @"")];
	[colorSpacePopUpButton selectItemAtIndex:[currentImageSource colorSpace]];
	[siteTextField setStringValue:([currentImageSource siteString] ? [currentImageSource siteString] : @"")];
	[adultContentFilteringPopUpButton selectItemAtIndex:[currentImageSource adultContentFiltering]];
}


- (IBAction)setKeywordsMatching:(id)sender
{
	if ([keywordsMatchingMatrix selectedRow] == 0)
	{
		[currentImageSource setRequiredTerms:[keywordsTextField stringValue]];
		[currentImageSource setOptionalTerms:nil];
	}
	else
	{
		[currentImageSource setRequiredTerms:nil];
		[currentImageSource setOptionalTerms:[keywordsTextField stringValue]];
	}
}


- (IBAction)showMoreOptions:(id)sender
{
	[NSApp beginSheet:moreOptionsPanel 
	   modalForWindow:[[self editorView] window] 
		modalDelegate:self 
	   didEndSelector:@selector(moreOptionsSheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == keywordsTextField)
	{
		if ([keywordsMatchingMatrix selectedRow] == 0)
		{
			[currentImageSource setRequiredTerms:[keywordsTextField stringValue]];
			[currentImageSource setOptionalTerms:nil];
		}
		else
		{
			[currentImageSource setRequiredTerms:nil];
			[currentImageSource setOptionalTerms:[keywordsTextField stringValue]];
		}
	}
	else
		[okButton setEnabled:([[currentImageSource requiredTerms] length] > 0 || 
							  [[currentImageSource optionalTerms] length] > 0 || 
							  [[currentImageSource excludedTerms] length] > 0 || 
							  [[currentImageSource siteString] length] > 0)];
}


- (IBAction)saveMoreOptions:(id)sender
{
	[NSApp endSheet:moreOptionsPanel returnCode:NSOKButton];
}


- (IBAction)cancelMoreOptions:(id)sender
{
	[NSApp endSheet:moreOptionsPanel returnCode:NSCancelButton];
}


- (void)moreOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[currentImageSource setRequiredTerms:[requiredTermsTextField stringValue]];
		[currentImageSource setOptionalTerms:[optionalTermsTextField stringValue]];
		[currentImageSource setExcludedTerms:[excludedTermsTextField stringValue]];
		[currentImageSource setColorSpace:[colorSpacePopUpButton indexOfSelectedItem]];
		[currentImageSource setSiteString:[siteTextField stringValue]];
		[currentImageSource setAdultContentFiltering:[adultContentFilteringPopUpButton indexOfSelectedItem]];
	}
}


- (void)editingDidComplete
{
	delegate = nil;
}


- (void)dealloc
{
	[super dealloc];
}


@end

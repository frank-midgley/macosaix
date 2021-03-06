/*
	GoogleImageSourceController.h
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

#import "GoogleImageSourceController.h"

#import "GoogleImageSource.h"


@implementation MacOSaiXGoogleImageSourceEditor


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
		[NSBundle loadNibNamed:@"Google Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(200.0, 130.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return requiredTermsTextField;
}


- (void)refresh
{
	if ([[currentImageSource requiredTerms] length] > 0 && [[currentImageSource optionalTerms] length] == 0)
	{
		[keywordsTextField setStringValue:[currentImageSource requiredTerms]];
		[keywordsMatchingMatrix selectCellAtRow:0 column:0];
	}
	else if ([[currentImageSource requiredTerms] length] == 0 && [[currentImageSource optionalTerms] length] > 0)
	{
		[keywordsTextField setStringValue:[currentImageSource optionalTerms]];
		[keywordsMatchingMatrix selectCellAtRow:1 column:0];
	}
	
	NSMutableArray	*moreOptions = [NSMutableArray array];
	
	if ([[currentImageSource excludedTerms] length] > 0)
		[moreOptions addObject:[NSString stringWithFormat:NSLocalizedString(@"Excluded: %@", @""), [currentImageSource excludedTerms]]];
	
	if ([currentImageSource colorSpace] == rgbColorSpace)
		[moreOptions addObject:NSLocalizedString(@"Color only", @"")];
	else if ([currentImageSource colorSpace] == grayscaleColorSpace)
		[moreOptions addObject:NSLocalizedString(@"Grayscale only", @"")];
	else if ([currentImageSource colorSpace] == blackAndWhiteColorSpace)
		[moreOptions addObject:NSLocalizedString(@"B&W only", @"")];
	
	if ([[currentImageSource siteString] length] > 0)
		[moreOptions addObject:[NSString stringWithFormat:NSLocalizedString(@"Site: %@", @""), [currentImageSource siteString]]];
	
	if ([currentImageSource adultContentFiltering] == moderateFiltering)
		[moreOptions addObject:NSLocalizedString(@"Mild adult content allowed", @"")];
	else if ([currentImageSource adultContentFiltering] == noFiltering)
		[moreOptions addObject:NSLocalizedString(@"Adult content allowed", @"")];
	
	[moreOptionsTextField setStringValue:[moreOptions componentsJoinedByString:@", "]];
}


- (void)editDataSource:(id<MacOSaiXImageSource>)imageSource
{
	currentImageSource = (MacOSaiXGoogleImageSource *)imageSource;
	
	[self refresh];
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
	[requiredTermsTextField setStringValue:([currentImageSource requiredTerms] ? [currentImageSource requiredTerms] : @"")];
	[optionalTermsTextField setStringValue:([currentImageSource optionalTerms] ? [currentImageSource optionalTerms] : @"")];
	[excludedTermsTextField setStringValue:([currentImageSource excludedTerms] ? [currentImageSource excludedTerms] : @"")];
	[colorSpacePopUpButton selectItemAtIndex:[currentImageSource colorSpace]];
	[siteTextField setStringValue:([currentImageSource siteString] ? [currentImageSource siteString] : @"")];
	[adultContentFilteringPopUpButton selectItemAtIndex:[currentImageSource adultContentFiltering]];
	
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
		NSMutableDictionary	*previousValue = [NSMutableDictionary dictionary];
		if ([currentImageSource requiredTerms])
			[previousValue setValue:[currentImageSource requiredTerms] forKey:@"Required Terms"];
		if ([currentImageSource optionalTerms])
			[previousValue setValue:[currentImageSource optionalTerms] forKey:@"Optional Terms"];
		if ([currentImageSource excludedTerms])
			[previousValue setValue:[currentImageSource excludedTerms] forKey:@"Excluded Terms"];
		
		if ([keywordsMatchingMatrix selectedRow] == 0)
		{
			[currentImageSource setRequiredTerms:[keywordsTextField stringValue]];
			[currentImageSource setOptionalTerms:nil];
			[currentImageSource setExcludedTerms:nil];
		}
		else
		{
			[currentImageSource setRequiredTerms:nil];
			[currentImageSource setOptionalTerms:[keywordsTextField stringValue]];
			[currentImageSource setExcludedTerms:nil];
		}
		
		[[self delegate] dataSource:currentImageSource 
					   didChangeKey:@"keywords" 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Change Keywords", @"")];
	}
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
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton)
	{
		[currentImageSource setRequiredTerms:[requiredTermsTextField stringValue]];
		[currentImageSource setOptionalTerms:[optionalTermsTextField stringValue]];
		[currentImageSource setExcludedTerms:[excludedTermsTextField stringValue]];
		[currentImageSource setColorSpace:[colorSpacePopUpButton indexOfSelectedItem]];
		[currentImageSource setSiteString:[siteTextField stringValue]];
		[currentImageSource setAdultContentFiltering:[adultContentFilteringPopUpButton indexOfSelectedItem]];
		
		[self refresh];
	}
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


- (void)editingDidComplete
{
	delegate = nil;
}


- (void)dealloc
{
	[super dealloc];
}


@end

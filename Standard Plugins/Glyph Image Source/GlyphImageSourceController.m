//
//  GlyphImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "GlyphImageSourceController.h"

#import "GlyphImageSource.h"
#import "NSString+MacOSaiX.h"


#define MIN_ASPECT_RATIO	0.1
#define MAX_ASPECT_RATIO	10.0


@interface MacOSaiXGlyphImageSourceEditor (PrivateMethods)
- (void)populateFontsPopUpButton;
- (void)populateColorsPopUpButton;
- (void)populateSizeControls;
@end


@implementation MacOSaiXGlyphImageSourceEditor


- (id)initWithDelegate:(id<MacOSaiXEditorDelegate>)inDelegate;
{
	if (self = [super init])
	{
		delegate = inDelegate;
	}
	
	return self;
}


- (id<MacOSaiXEditorDelegate>)delegate
{
	return delegate;
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"Glyph Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(217.0, 300.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return fontsPopUp;
}


- (void)updateSampleImage:(NSTimer *)timer
{
	[sampleImageView setImage:[currentImageSource nextImageAndIdentifier:nil]];
	
	if (![sampleImageView image])
		[timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}


- (void)editDataSource:(id<MacOSaiXDataSource>)dataSource
{
	currentImageSource = (MacOSaiXGlyphImageSource *)dataSource;
	
		// Start a timer to show sample images for the current settings.
	sampleTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 
													target:self 
												  selector:@selector(updateSampleImage:) 
												  userInfo:nil 
												   repeats:YES] retain];
	
	[self refresh];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(colorListDidChange:)
												 name:NSColorListDidChangeNotification 
											   object:nil];
}


#pragma mark -
#pragma mark Fonts


- (void)populateFontsPopUpButton
{
		// Remove any previous collections or families from the pop-up.
	while ([fontsPopUp numberOfItems] > 2)
		[fontsPopUp removeItemAtIndex:2];
	
	NSMenuItem		*itemToSelect = [fontsPopUp itemAtIndex:0];
	
	if ([[NSFontManager class] instancesRespondToSelector:@selector(collectionNames)])
	{
			// Add the available font collections to the pop-up.
		NSMenuItem		*collectionsMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Use a font collection:", @"") action:@selector(dummySelector:) keyEquivalent:@""];
		[[fontsPopUp menu] addItem:collectionsMenuItem];
		NSArray			*collectionNames = [[[NSFontManager sharedFontManager] collectionNames] 
										sortedArrayUsingSelector:@selector(compare:)];
		NSEnumerator	*collectionNameEnumerator = [collectionNames objectEnumerator];
		NSString		*collectionName = nil;
		while (collectionName = [collectionNameEnumerator nextObject])
		{
			NSMenuItem	*collectionMenuItem = [[NSMenuItem alloc] initWithTitle:collectionName action:@selector(useFontCollection:) keyEquivalent:@""];
			[collectionMenuItem setTarget:self];
			[collectionMenuItem setRepresentedObject:collectionName];
			
			[[fontsPopUp menu] addItem:collectionMenuItem];
			
			if ([currentImageSource fontsType] == fontCollection && [[currentImageSource fontCollectionName] isEqualToString:collectionName])
				itemToSelect = collectionMenuItem;
		}
		
		NSMenuItem		*editCollectionsMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Edit font collections...", @"") action:@selector(editFontCollections:) keyEquivalent:@""];
		[editCollectionsMenuItem setTarget:self];
		[[fontsPopUp menu] addItem:editCollectionsMenuItem];
		
		[[fontsPopUp menu] addItem:[NSMenuItem separatorItem]];
	}
	
		// Add the available families to the pop-up.
	NSMenuItem		*familiesMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Use a single font:", @"") action:@selector(dummySelector:) keyEquivalent:@""];
	[[fontsPopUp menu] addItem:familiesMenuItem];
	NSArray			*familyNames = [[[NSFontManager sharedFontManager] availableFontFamilies] 
									sortedArrayUsingSelector:@selector(compare:)];
	NSEnumerator	*familyNameEnumerator = [familyNames objectEnumerator];
	NSString		*familyName = nil;
	while (familyName = [familyNameEnumerator nextObject])
	{
		NSMenuItem	*familyMenuItem = [[NSMenuItem alloc] initWithTitle:familyName action:@selector(useFontFamily:) keyEquivalent:@""];
		[familyMenuItem setTarget:self];
		[familyMenuItem setRepresentedObject:familyName];
		
		[[fontsPopUp menu] addItem:familyMenuItem];
		
		if ([currentImageSource fontsType] == fontFamily && [[currentImageSource fontFamilyName] isEqualToString:familyName])
			itemToSelect = familyMenuItem;
	}
	
	[fontsPopUp selectItem:itemToSelect];
}


- (void)setFontsPopUpFromSource
{
	NSMenuItem	*itemToSelect = nil;
	
	if ([currentImageSource fontsType] == allFonts)
		itemToSelect = (NSMenuItem *)[fontsPopUp itemAtIndex:0];
	else
	{
		SEL				setFontAction;
		NSString		*fontObject = nil;
		
		if ([currentImageSource fontsType] == fontCollection)
		{
			setFontAction = @selector(setFontCollection:);
			fontObject = [currentImageSource fontCollectionName];
		}
		else
		{
			setFontAction = @selector(setFontFamily:);
			fontObject = [currentImageSource fontFamilyName];
		}
		
		NSEnumerator	*itemEnumerator = [[fontsPopUp itemArray] objectEnumerator];
		while (itemToSelect = [itemEnumerator nextObject])
			if ([itemToSelect action] == setFontAction && [[itemToSelect representedObject] isEqualTo:fontObject])
				break;
	}
	
	[fontsPopUp selectItem:itemToSelect];
}


- (IBAction)useAllFonts:(id)sender
{
	NSString	*key = nil;
	id			previousValue = nil;
	
	if ([currentImageSource fontsType] == allFonts)
	{
		key = @"useAllFonts";
		previousValue = [NSNumber numberWithBool:YES];
	}
	else if ([currentImageSource fontsType] == fontCollection)
	{
		key = @"fontCollectionName";
		previousValue = [[[currentImageSource fontCollectionName] retain] autorelease];;
	}
	else if ([currentImageSource fontsType] == fontFamily)
	{
		key = @"fontFamilyName";
		previousValue = [[[currentImageSource fontFamilyName] retain] autorelease];;
	}

	[currentImageSource setUseAllFonts:YES];
	
	[[self delegate] dataSource:currentImageSource 
				   didChangeKey:key 
					  fromValue:previousValue 
					 actionName:NSLocalizedString(@"Use All Fonts", @"")];
}


- (IBAction)useFontCollection:(id)sender
{
	NSString	*key = nil;
	id			previousValue = nil;
	
	if ([currentImageSource fontsType] == allFonts)
	{
		key = @"useAllFonts";
		previousValue = [NSNumber numberWithBool:YES];
	}
	else if ([currentImageSource fontsType] == fontCollection)
	{
		key = @"fontCollectionName";
		previousValue = [[[currentImageSource fontCollectionName] retain] autorelease];;
	}
	else if ([currentImageSource fontsType] == fontFamily)
	{
		key = @"fontFamilyName";
		previousValue = [[[currentImageSource fontFamilyName] retain] autorelease];;
	}

	[currentImageSource setFontCollectionName:[sender representedObject]];
	
	[[self delegate] dataSource:currentImageSource 
				   didChangeKey:key 
					  fromValue:previousValue 
					 actionName:NSLocalizedString(@"Use Font Collection", @"")];
}


- (IBAction)useFontFamily:(id)sender
{
	NSString	*key = nil;
	id			previousValue = nil;
	
	if ([currentImageSource fontsType] == allFonts)
	{
		key = @"useAllFonts";
		previousValue = [NSNumber numberWithBool:YES];
	}
	else if ([currentImageSource fontsType] == fontCollection)
	{
		key = @"fontCollectionName";
		previousValue = [[[currentImageSource fontCollectionName] retain] autorelease];;
	}
	else if ([currentImageSource fontsType] == fontFamily)
	{
		key = @"fontFamilyName";
		previousValue = [[[currentImageSource fontFamilyName] retain] autorelease];;
	}
	
	[currentImageSource setFontFamilyName:[sender representedObject]];

	[[self delegate] dataSource:currentImageSource 
				   didChangeKey:key 
					  fromValue:previousValue 
					 actionName:NSLocalizedString(@"Use Font Family", @"")];
}


- (IBAction)editFontCollections:(id)sender
{
	[self setFontsPopUpFromSource];	// don't select the "Edit Collections..." item
	[[NSWorkspace sharedWorkspace] launchApplication:@"Font Book"];
}


#pragma mark -
#pragma mark Colors


- (void)populateColorsPopUpButton
{
	[colorsPopUp removeAllItems];
	
	NSMenuItem		*itemToSelect = nil;
	
		// Add the built-in colors.
	NSArray			*builtInNames = [[MacOSaiXGlyphImageSource builtInColorListNames] sortedArrayUsingSelector:@selector(compare:)];
	NSEnumerator	*builtInNameEnumerator = [builtInNames objectEnumerator];
	NSString		*builtInName = nil;
	while (builtInName = [builtInNameEnumerator nextObject])
	{
		NSMenuItem	*builtInMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(builtInName, @"") action:@selector(useBuiltInColors:) keyEquivalent:@""];
		[builtInMenuItem setTarget:self];
		[builtInMenuItem setRepresentedObject:builtInName];
		
		[[colorsPopUp menu] addItem:builtInMenuItem];
		
		if ([[currentImageSource colorListClass] isEqualToString:@"Built-in"] && [[currentImageSource colorListName] isEqualToString:builtInName])
			itemToSelect = builtInMenuItem;
	}
	
	[[colorsPopUp menu] addItem:[NSMenuItem separatorItem]];
	
		// Add the system-wide colors.
	NSEnumerator	*colorListEnumerator = [[NSColorList availableColorLists] objectEnumerator];
	NSColorList		*colorList = nil;
	while (colorList = [colorListEnumerator nextObject])
	{
		NSMenuItem	*colorListMenuItem = [[NSMenuItem alloc] initWithTitle:[colorList name] action:@selector(useSystemWideColors:) keyEquivalent:@""];
		[colorListMenuItem setTarget:self];
		[colorListMenuItem setRepresentedObject:colorList];
		
		[[colorsPopUp menu] addItem:colorListMenuItem];
		
		if ([[currentImageSource colorListClass] isEqualToString:@"System-wide"] && [[currentImageSource colorListName] isEqualToString:[colorList name]])
			itemToSelect = colorListMenuItem;
	}
	
	[colorsPopUp selectItem:itemToSelect];
}


- (IBAction)useBuiltInColors:(id)sender
{
	NSArray	*previousValue = [NSArray arrayWithObjects:[currentImageSource colorListName], [currentImageSource colorListClass], nil];
	
	[currentImageSource setColorListName:[sender representedObject] ofClass:@"Built-in"];
	
	[[self delegate] dataSource:currentImageSource 
				   didChangeKey:@"colorListAndClass" 
					  fromValue:previousValue 
					 actionName:NSLocalizedString(@"Use Built-In Colors", @"")];
}


- (IBAction)useSystemWideColors:(id)sender
{
	NSArray	*previousValue = [NSArray arrayWithObjects:[currentImageSource colorListName], [currentImageSource colorListClass], nil];
	
	[currentImageSource setColorListName:[[sender representedObject] name] ofClass:@"System-wide"];
	
	[[self delegate] dataSource:currentImageSource 
				   didChangeKey:@"colorListAndClass" 
					  fromValue:previousValue 
					 actionName:NSLocalizedString(@"Use System-Wide Colors", @"")];
}


- (IBAction)editSystemWideColors:(id)sender
{
	[NSColorPanel setPickerMode:NSColorListModeColorPanel];
	[NSApp orderFrontColorPanel:sender];
}


- (void)colorListDidChange:(NSNotification *)notification
{
	[self populateColorsPopUpButton];
}
	

#pragma mark -
#pragma mark Size


- (void)populateSizeControls
{
	NSNumber	*aspectRatio = [currentImageSource aspectRatio];
	
	if (!aspectRatio)
	{
		[sizePopUp setEnabled:NO];
		[[sizePopUp itemAtIndex:0] setTitle:@"--"];
		
		[sizeSlider setEnabled:NO];
		[sizeSlider setFloatValue:1.0];
	}
	else
	{
		[sizePopUp setEnabled:YES];
		[[sizePopUp itemAtIndex:0] setTitle:[NSString stringWithAspectRatio:[aspectRatio floatValue]]];
		
		[sizeSlider setEnabled:YES];
			// Map the aspect ratio to the slider position.
		float	mappedRatio = 0.0;
		if ([aspectRatio floatValue] < 1.0)
			mappedRatio = ([aspectRatio floatValue] - MIN_ASPECT_RATIO) / (1.0 - MIN_ASPECT_RATIO);
		else
			mappedRatio = ([aspectRatio floatValue] - 1.0) / (MAX_ASPECT_RATIO - 1.0) + 1.0;
		[sizeSlider setFloatValue:mappedRatio];
	}
}


- (IBAction)setSize:(id)sender
{
	NSNumber	*previousAspectRatio = [currentImageSource aspectRatio], 
				*newAspectRatio = nil;
	
	if (sender == sizeMatrix)
		newAspectRatio = ([sizeMatrix selectedRow] == 0 ? nil : [NSNumber numberWithFloat:1.0]);
	else
	{
		newAspectRatio = [NSNumber numberWithFloat:1.0];
		
		if (sender == sizePopUp)
		{
			if ([sizePopUp selectedTag] == 2)
				newAspectRatio = [NSNumber numberWithFloat:3.0 / 4.0];
			else if ([sizePopUp selectedTag] == 3)
				newAspectRatio = [NSNumber numberWithFloat:4.0 / 3.0];
		}
		else	// sender == sizeSlider
		{
				// Map from the slider's scale to the actual ratio.
			if ([sizeSlider floatValue] <= 1.0)
				newAspectRatio = [NSNumber numberWithFloat:MIN_ASPECT_RATIO + (1.0 - MIN_ASPECT_RATIO) * [sizeSlider floatValue]];
			else
				newAspectRatio = [NSNumber numberWithFloat:1.0 + (MAX_ASPECT_RATIO - 1.0) * ([sizeSlider floatValue] - 1.0)];
		}
	}
	
	if (previousAspectRatio != newAspectRatio || ![previousAspectRatio isEqualTo:newAspectRatio])
	{
		[currentImageSource setAspectRatio:newAspectRatio];
		
		[self populateSizeControls];
		
		[[self delegate] dataSource:currentImageSource 
					   didChangeKey:@"aspectRatio" 
						  fromValue:previousAspectRatio 
						 actionName:NSLocalizedString(@"Set Glyphs Size", @"")];
	}
}


#pragma mark -


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


#pragma mark -
#pragma mark Text delegate methods


- (void)textDidChange:(NSNotification *)notification
{
	if ([notification object] == lettersView)
	{
		NSString	*previousValue = [[[currentImageSource letterPool] retain] autorelease];
		
		if ([[lettersView string] length] > 0)
			[currentImageSource setLetterPool:[lettersView string]];
		else
			[currentImageSource setLetterPool:nil];
		
		[[self delegate] dataSource:currentImageSource 
					   didChangeKey:@"letterPool" 
						  fromValue:previousValue 
						 actionName:NSLocalizedString(@"Use Glyph Letters", @"")];
	}
}


#pragma mark -


- (void)refresh
{
	[self populateFontsPopUpButton];
	[self populateColorsPopUpButton];
	[self populateSizeControls];
	[lettersView setString:([currentImageSource letterPool] ? [currentImageSource letterPool] : @"")];
}


- (void)editingDidComplete
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSColorListDidChangeNotification object:nil];
	
	[sampleTimer invalidate];
	[sampleTimer release];
	sampleTimer = nil;
	
	currentImageSource = nil;
}


- (void)dealloc
{
	[sampleTimer invalidate];	// which will also release it
	
	[super dealloc];
}


@end

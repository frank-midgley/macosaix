//
//  GlyphImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "GlyphImageSourceController.h"
#import "NSString+MacOSaiX.h"


@implementation MacOSaiXGlyphImageSourceController


- (id)init
{
	if (self = [super init])
	{
		availableFontMembers = [[NSMutableDictionary dictionary] retain];
		
		builtinColorLists = [[NSMutableArray array] retain];
		NSEnumerator	*colorListNameEnumerator = [[MacOSaiXGlyphImageSource builtInColorListNames] objectEnumerator];
		NSString		*colorListName = nil;
		while (colorListName = [colorListNameEnumerator nextObject])
			[builtinColorLists addObject:[[[NSColorList alloc] initWithName:colorListName] autorelease]];
	}
	
	return self;
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"Glyph Image Source" owner:self];
	
	return editorView;
}


- (NSSize)editorViewMinimumSize
{
	return NSMakeSize(450.0, 375.0);
}


- (NSResponder *)editorViewFirstResponder
{
	return fontsOutlineView;
}


- (void)awakeFromNib
{
	NSButtonCell	*fontCheckboxCell = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
	[fontCheckboxCell setButtonType:NSSwitchButton];
	[fontCheckboxCell setAllowsMixedState:YES];
	[fontCheckboxCell setTarget:self];
	[fontCheckboxCell setAction:@selector(toggleFont:)];
	[[[fontsOutlineView tableColumns] objectAtIndex:0] setDataCell:fontCheckboxCell];
	
	NSButtonCell	*colorCheckboxCell = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
	[colorCheckboxCell setButtonType:NSSwitchButton];
	[colorCheckboxCell setTarget:self];
	[colorCheckboxCell setAction:@selector(toggleColor:)];
	[[[colorsOutlineView tableColumns] objectAtIndex:0] setDataCell:colorCheckboxCell];
}


- (void)setOKButton:(NSButton *)button
{
	okButton = button;
}


- (void)updateSample:(NSTimer *)timer
{
	[currentImageSource reset];
	
	[sampleImageView setImage:[currentImageSource nextImageAndIdentifier:nil]];
	
	if (![sampleImageView image])
		[timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}


- (void)updateSizeField
{
	NSSize	sourceSize = [currentImageSource glyphsSize];
	[sizeTextField setStringValue:[NSString stringWithFormat:@"Size: %@", 
										[NSString stringWithAspectRatio:sourceSize.width / sourceSize.height]]];
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	if (imageSource)
	{
		currentImageSource = (MacOSaiXGlyphImageSource *)imageSource;
		
			// Start a timer to show sample images for the current settings.
		sampleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 
													   target:self 
													 selector:@selector(updateSample:) 
													 userInfo:nil 
													  repeats:YES];
		
			// Get the list of all current font family names on this system.
		[fontFamilyNames autorelease];
		fontFamilyNames = [[[[NSFontManager sharedFontManager] availableFontFamilies] 
									sortedArrayUsingSelector:@selector(compare:)] retain];
		[fontsOutlineView reloadData];
		
			// Get the list of font names currently used by the image source.
		NSEnumerator	*fontNameEnumerator = [[currentImageSource fontNames] objectEnumerator];
		NSString		*fontName = nil;
		chosenFonts = [[NSMutableArray arrayWithCapacity:[[currentImageSource fontNames] count]] retain];
		while (fontName = [fontNameEnumerator nextObject])
		{
			NSFont	*font = [NSFont fontWithName:fontName size:12.0];
			
			if (font)
				[chosenFonts addObject:font];
		}
		
			// Get the list of colors defined by the NSColorPanel.
		[systemWideColorLists autorelease];
		systemWideColorLists = [[NSColorList availableColorLists] retain];
		
			// Populate the GUI with this source's settings.
		if ([[currentImageSource letterPool] length] == 0)
		{
			[lettersMatrix selectCellAtRow:0 column:1];
			[lettersView setString:@""];
		}
		else
		{
			[lettersMatrix selectCellAtRow:1 column:1];
			[lettersView setString:[currentImageSource letterPool]];
		}
		
		if ([currentImageSource imageCountLimit] == 0)
		{
			[countMatrix selectCellAtRow:0 column:1];
			[countTextField setStringValue:@""];
		}
		else
		{
			[countMatrix selectCellAtRow:1 column:1];
			[countTextField setIntValue:[currentImageSource imageCountLimit]];
		}
	}
	else
	{
		[sampleTimer invalidate];
		sampleTimer = nil;
	}
}


#pragma mark Fonts tab


- (NSArray *)fontsInFamily:(NSString *)familyName
{
	NSArray	*fontMembers = [availableFontMembers objectForKey:familyName];
	
	if (!fontMembers)
	{
		fontMembers = [NSMutableArray array];
		[availableFontMembers setObject:fontMembers forKey:familyName];
		
		NSEnumerator	*memberEnumerator = [[[NSFontManager sharedFontManager] availableMembersOfFontFamily:familyName]
												objectEnumerator];
		NSArray			*member = nil;
		while (member = [memberEnumerator nextObject])
			[(NSMutableArray *)fontMembers addObject:[NSFont fontWithName:[member objectAtIndex:0] size:12.0]];
	}
	
	return fontMembers;
}


- (IBAction)setFontsOption:(id)sender
{
	
}


- (IBAction)toggleFont:(id)sender
{
	id			selectedItem = [fontsOutlineView itemAtRow:[fontsOutlineView selectedRow]];
	
	if ([selectedItem isKindOfClass:[NSString class]])
	{
			// Add or remove all members of the font family.
		NSArray			*members = [self fontsInFamily:selectedItem];
		BOOL			removing = ([members firstObjectCommonWithArray:chosenFonts] != nil);
		NSEnumerator	*memberEnumerator = [members objectEnumerator];
		NSFont			*member = nil;
		while (member = [memberEnumerator nextObject])
			if (removing)
			{
				[chosenFonts removeObject:member];
				[currentImageSource removeFontWithName:[member fontName]];
			}
			else if (![chosenFonts containsObject:member])
			{
				[chosenFonts addObject:member];
				[currentImageSource addFontWithName:[member fontName]];
			}
	}
	else if ([selectedItem isKindOfClass:[NSFont class]])
	{
			// Add or remove just the one font
		NSString	*fontName = [(NSFont *)selectedItem fontName];
		if ([[currentImageSource fontNames] containsObject:fontName])
		{
			[chosenFonts removeObject:selectedItem];
			[currentImageSource removeFontWithName:fontName];
		}
		else
		{
			[chosenFonts addObject:selectedItem];
			[currentImageSource addFontWithName:fontName];
		}
	}
	
	[fontsOutlineView reloadData];
	[self updateSizeField];
}


- (IBAction)chooseNoFonts:(id)sender
{
	
}


- (IBAction)chooseAllFonts:(id)sender
{
	
}


#pragma mark Colors tab


- (IBAction)setColorsOption:(id)sender
{
}


- (IBAction)toggleColor:(id)sender
{
	NSColorList		*list = [colorsOutlineView itemAtRow:[colorsOutlineView selectedRow]];
	NSString		*listClass = nil;
	
	if ([builtinColorLists containsObject:list])
		listClass = @"Built-in";
	else if ([systemWideColorLists containsObject:list])
		listClass = @"System-wide";
	else if ([photoshopColorLists containsObject:list])
		listClass = @"Photoshop";
	
	if ([[currentImageSource colorListsOfClass:listClass] containsObject:[list name]])
		[currentImageSource removeColorList:[list name] ofClass:listClass];
	else
		[currentImageSource addColorList:[list name] ofClass:listClass];
}


#pragma mark Letters tab


- (IBAction)setLettersOption:(id)sender
{
}


#pragma mark Fonts tab


- (IBAction)setCountOption:(id)sender
{
}


#pragma mark -
#pragma mark Table view data source methods


- (void)textDidChange:(NSNotification *)notification
{
	if ([notification object] == lettersView)
	{
		if ([[lettersView string] length] > 0)
		{
			[lettersMatrix selectCellAtRow:1 column:1];
			[currentImageSource setLetterPool:[lettersView string]];
		}
		else
		{
			[lettersMatrix selectCellAtRow:0 column:1];
			[currentImageSource setLetterPool:nil];
		}
	}
}


#pragma mark -
#pragma mark Outline view data source methods


- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (outlineView == fontsOutlineView)
	{
		if (!item)
			return [fontFamilyNames count];
		else
			return [[self fontsInFamily:item] count];
	}
	else
	{
		if (!item)
			return [builtinColorLists count] + 1;
		else
			return [systemWideColorLists count];
	}
}


- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	if (outlineView == fontsOutlineView)
	{
		if (!item)
			return [fontFamilyNames objectAtIndex:index];
		else
			return [[self fontsInFamily:item] objectAtIndex:index];
	}
	else
	{
		if (!item)
		{
			if (index < [builtinColorLists count])
				return [builtinColorLists objectAtIndex:index];
			else
				return @"System-wide Colors";
		}
		else
			return [systemWideColorLists objectAtIndex:index];
	}
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [item isKindOfClass:[NSString class]];
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	return nil;
}


- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell 
												  forTableColumn:(NSTableColumn *)tableColumn 
															item:(id)item
{
	if (outlineView == fontsOutlineView)
	{
		if ([item isKindOfClass:[NSString class]])
		{
			NSArray			*fonts = [self fontsInFamily:item];
			NSEnumerator	*fontEnumerator = [fonts objectEnumerator];
			NSFont			*font = nil;
			int				count = 0;
			while (font = [fontEnumerator nextObject])
				if ([chosenFonts containsObject:font])
					count++;
			
			if (count == 0)
				[cell setState:NSOffState];
			else if (count == [fonts count])
				[cell setState:NSOnState];
			else
				[cell setState:NSMixedState];
			
			[cell setTitle:item];
		}
		else
		{
			[cell setState:([[currentImageSource fontNames] containsObject:[(NSFont *)item fontName]] ? NSOnState : NSOffState)];

			NSString	*title = [(NSFont *)item displayName],
						*familyName = [(NSFont *)item familyName];
			
			if ([title hasPrefix:familyName])
				title = [title substringFromIndex:[familyName length] + 1];
			
			[cell setTitle:title];
		}
	}
	else
	{
		if ([item isKindOfClass:[NSString class]])
		{
			[cell setState:NSOffState];
			[cell setEnabled:NO];
			[cell setTitle:@"System-wide Color Lists"];
		}
		else
		{
			NSString	*listClass = nil;
			if ([builtinColorLists containsObject:item])
				listClass = @"Built-in";
			else if ([systemWideColorLists containsObject:item])
				listClass = @"System-wide";
			else if ([photoshopColorLists containsObject:item])
				listClass = @"Photoshop";
			
			if ([[currentImageSource colorListsOfClass:listClass] containsObject:[(NSColorList *)item name]])
				[cell setState:NSOnState];
			else
				[cell setState:NSOffState];
			[cell setEnabled:YES];
			[cell setTitle:[(NSColorList *)item name]];
		}
	}
}


#pragma mark -


- (void)dealloc
{
	[sampleTimer invalidate];	// which will also release it
	
	[fontFamilyNames release];
	[availableFontMembers release];
	
	[builtinColorLists release];
	
	[super dealloc];
}


@end

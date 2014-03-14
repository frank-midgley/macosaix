//
//  MacOSaiXDLImageSourceEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 15 2008.
//  Copyright (c) 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXDLImageSourceEditor.h"

#import "MacOSaiXDeliciousLibrary.h"
#import "MacOSaiXDLImageSource.h"
#import "MacOSaiXDLItemType.h"
#import "MacOSaiXDLShelf.h"

#import "NSImage+MacOSaiX.h"


@implementation MacOSaiXDLImageSourceEditor


- (void)synchronizeUI
{
	[iconView setImage:[[MacOSaiXDeliciousLibrary sharedLibrary] image]];
	
	if ([[MacOSaiXDeliciousLibrary sharedLibrary] isLoading])
	{
		[reloadButton setEnabled:NO];
		[loadingIndicator startAnimation:nil];
		[tabView selectTabViewItemWithIdentifier:@"Loading"];
	}
	else
	{
		[reloadButton setEnabled:YES];
		[loadingIndicator stopAnimation:nil];
		
		if ([[MacOSaiXDeliciousLibrary sharedLibrary] loadingError])
		{
			[errorField setStringValue:[[[MacOSaiXDeliciousLibrary sharedLibrary] loadingError] localizedDescription]];
			[tabView selectTabViewItemWithIdentifier:@"Load Failed"];
		}
		else if (![[MacOSaiXDeliciousLibrary sharedLibrary] isInstalled])
			[tabView selectTabViewItemWithIdentifier:@"Not Installed"];
		else
		{
				// Update the library item count.
			[itemCountField setStringValue:[NSString stringWithFormat:@"(%d)", [[[MacOSaiXDeliciousLibrary sharedLibrary] allItems] count]]];
			
				// Populate the "Item Types" pop-up menu.
			[itemTypesPopUp removeAllItems];
			NSArray			*itemTypes = [[MacOSaiXDeliciousLibrary sharedLibrary] itemTypes];
			if ([itemTypes count] == 0)
			{
				[[sourceTypeMatrix cellAtRow:1 column:0] setEnabled:NO];
				[itemTypesPopUp setEnabled:NO];
				
				[itemTypesPopUp addItemWithTitle:@"No items in library"];
			}
			else
			{
				[[sourceTypeMatrix cellAtRow:1 column:0] setEnabled:YES];
				[itemTypesPopUp setEnabled:YES];
				
				NSEnumerator		*itemTypeEnumerator = [itemTypes objectEnumerator];
				MacOSaiXDLItemType	*itemType = nil;
				while (itemType = [itemTypeEnumerator nextObject])
				{
					NSString	*menuTitle = [NSString stringWithFormat:@"%@ (%d)", [[itemType name] capitalizedString], [[itemType items] count]];
					NSMenuItem	*typeMenuItem = [[[NSMenuItem alloc] initWithTitle:menuTitle 
																			action:@selector(setItemType:) 
																	 keyEquivalent:@""] autorelease];
					
					[typeMenuItem setTarget:self];
					[typeMenuItem setImage:[[[itemType image] copyWithLargestDimension:16] autorelease]];
					[typeMenuItem setRepresentedObject:itemType];
						
					[[itemTypesPopUp menu] addItem:typeMenuItem];
				}
			}
			
				// Populate the "Shelves" pop-up menu.
			[shelvesPopUp removeAllItems];
			NSArray			*shelves = [[MacOSaiXDeliciousLibrary sharedLibrary] shelves];
			if ([shelves count] == 0)
			{
				[[sourceTypeMatrix cellAtRow:2 column:0] setEnabled:NO];
				[shelvesPopUp addItemWithTitle:@"No shelves defined"];
				[shelvesPopUp setEnabled:NO];
			}
			else
			{
				[[sourceTypeMatrix cellAtRow:2 column:0] setEnabled:YES];
				[shelvesPopUp setEnabled:YES];
				
				NSImage			*shelfImage = [[[[MacOSaiXDeliciousLibrary sharedLibrary] shelfImage] copyWithLargestDimension:16] autorelease], 
								*smartShelfImage = [[[[MacOSaiXDeliciousLibrary sharedLibrary] smartShelfImage] copyWithLargestDimension:16] autorelease];
				NSEnumerator	*shelvesEnumerator = [[[MacOSaiXDeliciousLibrary sharedLibrary] shelves] objectEnumerator];
				MacOSaiXDLShelf	*shelf = nil;
				while (shelf = [shelvesEnumerator nextObject])
				{
					int	itemCount = [[shelf items] count];
					
					if (itemCount > 0)
					{
						NSMenuItem	*shelfMenuItem = [[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%d)", [shelf name], itemCount] 
																				 action:@selector(setShelf:) 
																		  keyEquivalent:@""] autorelease];
						[shelfMenuItem setTarget:self];
						[shelfMenuItem setRepresentedObject:shelf];
						[shelfMenuItem setImage:([shelf isSmart] ? smartShelfImage : shelfImage)];
						
						[[shelvesPopUp menu] addItem:shelfMenuItem];
					}
				}
			}
			
			if ([currentImageSource shelf])
			{
				[sourceTypeMatrix selectCellAtRow:2 column:0];
				[shelvesPopUp selectItemAtIndex:[shelvesPopUp indexOfItemWithRepresentedObject:[currentImageSource shelf]]];
			}
			else if ([currentImageSource itemType])
			{
				[sourceTypeMatrix selectCellAtRow:1 column:0];
				[itemTypesPopUp selectItemAtIndex:[itemTypesPopUp indexOfItemWithRepresentedObject:[currentImageSource itemType]]];
			}
			else
				[sourceTypeMatrix selectCellAtRow:0 column:0];
			
			[tabView selectTabViewItemWithIdentifier:@"Settings"];
		}
	}
}


- (void)awakeFromNib
{
	[self synchronizeUI];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(libraryDidChangeState:) name:MacOSaiXDLDidChangeStateNotification object:nil];
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"Delicious Library Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(430.0, 128.0);
}


- (NSResponder *)firstResponder
{
	return sourceTypeMatrix;
}


- (void)libraryDidChangeState:(NSNotification *)notification
{
	[self synchronizeUI];
}


#pragma mark -


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[currentImageSource release];
	currentImageSource = [imageSource retain];
	
		// Make sure we're working with the latest and greatest.
	if (![[MacOSaiXDeliciousLibrary sharedLibrary] isLoading])
		[[MacOSaiXDeliciousLibrary sharedLibrary] loadLibrary];
	
	[self synchronizeUI];
}


- (BOOL)settingsAreValid
{
	return [[MacOSaiXDeliciousLibrary sharedLibrary] isInstalled] && ![[MacOSaiXDeliciousLibrary sharedLibrary] loadingError];
}


- (IBAction)reloadLibrary:(id)sender
{
	if (![[MacOSaiXDeliciousLibrary sharedLibrary] isLoading])
		[[MacOSaiXDeliciousLibrary sharedLibrary] loadLibrary];
}


- (IBAction)setSourceType:(id)sender
{
	if ([sourceTypeMatrix selectedRow] == 0)
	{
		if ([currentImageSource itemType])
			[currentImageSource setItemType:nil];
		else
			[currentImageSource setShelf:nil];
	}
	else if ([sourceTypeMatrix selectedRow] == 1)
		[currentImageSource setItemType:[[itemTypesPopUp selectedItem] representedObject]];
	else if ([sourceTypeMatrix selectedRow] == 2)
		[currentImageSource setShelf:[[shelvesPopUp selectedItem] representedObject]];
	
	[self synchronizeUI];
}


- (IBAction)setItemType:(id)sender
{
	[currentImageSource setItemType:[[itemTypesPopUp selectedItem] representedObject]];
	
	[self synchronizeUI];
}


- (IBAction)setShelf:(id)sender
{
	[currentImageSource setShelf:[[shelvesPopUp selectedItem] representedObject]];
	
	[self synchronizeUI];
}


- (IBAction)visitWebSite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.delicious-monster.com/"]];
}


- (void)editingComplete
{
	[currentImageSource release];
	currentImageSource = nil;
}


#pragma mark -


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[currentImageSource release];
	
	[editorView release];
	
	[super dealloc];
}


@end

//
//  PreferencesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "PreferencesController.h"


@implementation PreferencesController

- (void)windowDidLoad
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
    
    [autosaveFrequencyField setStringValue:[defaults objectForKey:@"Autosave Frequency"]];

    // set the tile defaults
    _tileShapes = [[defaults objectForKey:@"Tile Shapes"] retain];
    [tileShapesPopup selectItemWithTitle:_tileShapes];

    // set the image sources defaults
    _imageSources = [[NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"Image Sources"]] retain];
    [imageSourcesView setDataSource:self];
    [[imageSourcesView tableColumnWithIdentifier:@"type"] setDataCell:[[NSImageCell alloc] init]];
}


/*
- (void)addDirectoryImageSource:(id)sender
{
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:NO];
    [oPanel setCanChooseDirectories:YES];
    [oPanel beginSheetForDirectory:NSHomeDirectory()
			      file:nil
			     types:nil
		    modalForWindow:[self window]
		     modalDelegate:self
		    didEndSelector:@selector(addDirectoryImageSourceOpenPanelDidEnd:returnCode:contextInfo:)
		       contextInfo:nil];
}


- (void)addDirectoryImageSourceOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context
{
    if (returnCode != NSOKButton) return;

    [_imageSources addObject:[[[DirectoryImageSource alloc]
			      initWithObject:[[sheet filenames] objectAtIndex:0]] autorelease]];
    [imageSourcesView reloadData];
}


- (void)addGoogleImageSource:(id)sender
{
    [NSApp beginSheet:googleTermPanel
       modalForWindow:[self window]
	modalDelegate:nil
       didEndSelector:nil
	  contextInfo:nil];
}


- (void)cancelAddGoogleImageSource:(id)sender;
{
    [NSApp endSheet:googleTermPanel];
    [googleTermPanel orderOut:nil];
}


- (void)okAddGoogleImageSource:(id)sender;
{
    [_imageSources addObject:[[[GoogleImageSource alloc] initWithObject:[googleTermField stringValue]] autorelease]];
    [NSApp endSheet:googleTermPanel];
    [googleTermPanel orderOut:nil];
    [imageSourcesView reloadData];
}


- (void)addGlyphImageSource:(id)sender
{
    [_imageSources addObject:[[[GlyphImageSource alloc] initWithObject:nil] autorelease]];
    [imageSourcesView reloadData];
}


- (void)setTileShapes:(id)sender
{
    _tileShapes = [tileShapesPopup titleOfSelectedItem];
}
*/


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return (_imageSources == nil) ? 0 : [_imageSources count] - 1;
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
	    row:(int)rowIndex
{
    if ([[aTableColumn identifier] isEqualToString:@"type"])
		return nil;	// [[_imageSources objectAtIndex:rowIndex + 1] typeImage];
    else
		return nil;	// [[_imageSources objectAtIndex:rowIndex + 1] descriptor];
}


- (void)removeImageSource:(id)sender
{
    int		i;
    
    for (i = [_imageSources count] - 1; i >= 0; i--)
	if ([imageSourcesView isRowSelected:i])
	    [_imageSources removeObjectAtIndex:i + 1];
    [imageSourcesView reloadData];
}


- (void)setCropLimit:(id)sender
{
    
}


- (void)userCancelled:(id)sender
{
    [self close];
}


- (void)savePreferences:(id)sender
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:[autosaveFrequencyField stringValue] forKey:@"Autosave Frequency"];
    [defaults setObject:_tileShapes forKey:@"Tile Shapes"];
    [defaults setObject:[NSString stringWithFormat:@"%d", _tilesWide] forKey:@"Tiles Wide"];
    [defaults setObject:[NSString stringWithFormat:@"%d", _tilesHigh] forKey:@"Tiles High"];
    [defaults setObject:[NSArchiver archivedDataWithRootObject:_imageSources] forKey:@"Image Sources"];
    [defaults synchronize];
    
    [self close];
}


- (void)dealloc
{
    [_tileShapes release];
    [_imageSources release];
    [super dealloc];
}

@end

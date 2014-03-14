//
//  MacOSaiXAnimationSettingsController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 10/23/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXAnimationSettingsController.h"

#import "MacOSaiXMosaic.h"
#import "NSString+MacOSaiX.h"


@implementation MacOSaiXAnimationSettingsController


+ (NSString *)imageDescriptionPlaceholder
{
	static NSString	*placeholderString = nil;
	
	if (!placeholderString)
	{
		unichar	placeholder = 0x233D;
		
		placeholderString = [[NSString stringWithCharacters:&placeholder length:1] retain];
	}
	
	return placeholderString;
}


- (NSString *)windowNibName
{
	return @"Animation Settings";
}


- (void)showAnimationSettingsForMosaic:(MacOSaiXMosaic *)inMosaic 
						modalForWindow:(NSWindow *)window 
						 modalDelegate:(id)inDelegate
						didEndSelector:(SEL)inDidEndSelector;
{
	mosaic = inMosaic;
	delegate = inDelegate;
	didEndSelector = inDidEndSelector;
	
	[self window];
	
		// Populate the GUI with the current settings.
	[animateAllImagesMatrix selectCellAtRow:([mosaic animateAllImagePlacements] ? 1 : 0) column:0];
	[fullSizedDisplayDurationPopUp selectItemAtIndex:[fullSizedDisplayDurationPopUp indexOfItemWithTag:[mosaic imagePlacementFullSizedDuration]]];
	[messageField setStringValue:([mosaic imagePlacementMessage] ? [mosaic imagePlacementMessage] : @"")];
	[includeSourceImageButton setState:([mosaic includeSourceImageWithImagePlacementMessage] ? NSOnState : NSOffState)];
	[animationDelayPopUp selectItemAtIndex:[animationDelayPopUp indexOfItemWithTag:[mosaic delayBetweenImagePlacements]]];
	[messageField setStringValue:([mosaic imagePlacementMessage] ? [mosaic imagePlacementMessage] : @"")];
	
	[NSApp beginSheet:[self window] 
	   modalForWindow:window
		modalDelegate:self 
	   didEndSelector:@selector(animationSettingsDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}


- (MacOSaiXMosaic *)mosaic
{
	return mosaic;
}


- (NSImage *)originalImage
{
	return [mosaic originalImage];
}


- (IBAction)insertImageDescriptionPlaceholder:(id)sender
{
	NSString	*phString = [[self class] imageDescriptionPlaceholder], 
				*message = [messageField stringValue];
	
	if ([messageField currentEditor])
		[[messageField currentEditor] insertText:phString];
	else if ([message length] == 0)
		[messageField setStringValue:phString];
	else if ([message hasSuffix:@" "])
		[messageField setStringValue:[message stringByAppendingString:phString]];
	else
		[messageField setStringValue:[message stringByAppendingFormat:@" %@", phString]];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
	[insertDescriptionButton setEnabled:([[messageField stringValue] rangeOfString:[[self class] imageDescriptionPlaceholder]].location == NSNotFound)];
}


- (IBAction)cancel:(id)sender
{
	[NSApp endSheet:[self window] returnCode:NSCancelButton];
}


- (IBAction)ok:(id)sender;
{
	[NSApp endSheet:[self window] returnCode:NSOKButton];
}


- (void)animationSettingsDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton)
	{
			// Update the mosaic
		[[self mosaic] setAnimateAllImagePlacements:([animateAllImagesMatrix selectedRow] == 1)];
		[[self mosaic] setImagePlacementFullSizedDuration:[fullSizedDisplayDurationPopUp selectedTag]];
		[[self mosaic] setImagePlacementMessage:[messageField stringValue]];
		[[self mosaic] setIncludeSourceImageWithImagePlacementMessage:([includeSourceImageButton state] == NSOnState)];
		[[self mosaic] setDelayBetweenImagePlacements:[animationDelayPopUp selectedTag]];
		
			// Update the defaults
		NSDictionary	*animationDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
													[NSNumber numberWithBool:([mosaic animateImagePlacements])], @"Animate Placements", 
													[NSNumber numberWithBool:([animateAllImagesMatrix selectedRow] == 1)], @"Animate All Placements", 
													[NSNumber numberWithInt:[fullSizedDisplayDurationPopUp selectedTag]], @"Full Size Display Duration", 
													[NSNumber numberWithInt:[animationDelayPopUp selectedTag]], @"Delay Between Placements", 
													[NSNumber numberWithBool:([includeSourceImageButton state] == NSOnState)], @"Include Source Image with Message", 
													[messageField stringValue], @"Message", 
													nil];
		[[NSUserDefaults standardUserDefaults] setObject:animationDefaults forKey:@"Image Placement Settings"];
	}
	
	if ([delegate respondsToSelector:@selector(didEndSelector)])
		[delegate performSelector:didEndSelector];
	
	mosaic = nil;
	delegate = nil;
	didEndSelector = nil;
}


@end

//
//  MacOSaiXTargetImageEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTargetImageEditor.h"

#import "MacOSaiXDocument.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXWarningController.h"
#import "MacOSaiXWindowController.h"

#import "NSBezierPath+MacOSaiX.h"
#import "NSFileManager+MacOSaiX.h"
#import "NSImage+MacOSaiX.h"


static NSComparisonResult compareWithKey(NSDictionary *dict1, NSDictionary *dict2, void *context)
{
	id	value1 = [dict1 objectForKey:context], 
	value2 = [dict2 objectForKey:context];
	
	if ([value1 isKindOfClass:[NSString class]] && [value2 isKindOfClass:[NSString class]])
		return [(NSString *)value1 caseInsensitiveCompare:value2];
	else
		return [(NSNumber *)value1 compare:(NSNumber *)value2];
}


@implementation MacOSaiXTargetImageEditor


+ (void)load
{
	[super load];
}


+ (NSImage *)image
{
	return [NSImage imageNamed:@"Target Image"];
}


+ (NSString *)title
{
	return NSLocalizedString(@"Target Image", @"");
}


+ (NSString *)description
{
	return NSLocalizedString(@"This setting lets you choose the image that the mosaic will try to look like.  It also keeps track of previously chosen images for quick access.", @"");
}


+ (NSString *)sortKey
{
	return @"0";
}


- (void)addTargetImage:(NSImage *)targetImage fromPath:(NSString *)targetImagePath
{
	NSImage			*thumbnailImage = [[targetImage copyWithLargestDimension:32.0] autorelease];
	
//	NSImage			*thumbnailImage = [[[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)] autorelease], 
//					*scaledImage = [targetImage copyWithLargestDimension:32.0];
//	
//	[thumbnailImage lockFocus];
//	if ([scaledImage size].width > [scaledImage size].height)
//		[scaledImage compositeToPoint:NSMakePoint(0.0, 16.0 - [scaledImage size].height / 2.0) 
//							operation:NSCompositeCopy];
//	else
//		[scaledImage compositeToPoint:NSMakePoint(16.0 - [scaledImage size].width / 2.0, 0.0) 
//							operation:NSCompositeCopy];
//	[thumbnailImage unlockFocus];
//	[scaledImage release];
	
	{
		// Update the recent targets in the user's defaults.
		
		NSMutableArray	*recentTargetImageDicts = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Recent Target Images"] mutableCopy];
		if (recentTargetImageDicts)
		{
				// Remove any previous entry from the defaults for the image at this path.
			NSEnumerator	*targetEnumerator = [recentTargetImageDicts objectEnumerator];
			NSDictionary	*targetDict = nil;
			while (targetDict = [targetEnumerator nextObject])
			{
				if ([[targetDict objectForKey:@"Path"] isEqualToString:targetImagePath])
				{
					[recentTargetImageDicts removeObject:targetDict];
					break;
				}
			}
			
			[recentTargetImageDicts autorelease];
		}
		else
			recentTargetImageDicts = [NSMutableArray array];
		
		[recentTargetImageDicts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
											targetImagePath, @"Path", 
											[[targetImagePath lastPathComponent] stringByDeletingPathExtension], @"Name", 
											[thumbnailImage TIFFRepresentation], @"Thumbnail Data",
											nil]];
		[[NSUserDefaults standardUserDefaults] setObject:recentTargetImageDicts forKey:@"Recent Target Images"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	{
		// Update the in-memory and on-screen data.
		
			// Remove any previous entry for the image at this path.
		NSEnumerator	*targetEnumerator = [targetImageDicts objectEnumerator];
		NSDictionary	*targetDict = nil;
		while (targetDict = [targetEnumerator nextObject])
		{
			if ([[targetDict objectForKey:@"Path"] isEqualToString:targetImagePath])
			{
				[targetImageDicts removeObject:targetDict];
				break;
			}
		}
		
		NSDictionary	*newTargetImageDict = [NSDictionary dictionaryWithObjectsAndKeys:
												targetImagePath, @"Path", 
												[[targetImagePath lastPathComponent] stringByDeletingPathExtension], @"Name", 
												thumbnailImage, @"Thumbnail",
												nil];
		[targetImageDicts addObject:newTargetImageDict];
		[targetImageDicts sortUsingFunction:compareWithKey context:@"Name"];
		[targetImagesTableView reloadData];
		[targetImagesTableView selectRow:[targetImageDicts indexOfObject:newTargetImageDict] byExtendingSelection:NO];
	}
}


- (void)removeTargetImageAtPath:(NSString *)targetImagePath
{
	{
		// Update the recent targets in the user's defaults.
		
		NSMutableArray	*recentTargetImageDicts = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Recent Target Images"] mutableCopy];
		
		if (recentTargetImageDicts)
		{
			NSEnumerator	*targetEnumerator = [recentTargetImageDicts objectEnumerator];
			NSDictionary	*targetDict = nil;
			while (targetDict = [targetEnumerator nextObject])
			{
				if ([[targetDict objectForKey:@"Path"] isEqualToString:targetImagePath])
				{
					[recentTargetImageDicts removeObject:targetDict];
					[[NSUserDefaults standardUserDefaults] setObject:recentTargetImageDicts forKey:@"Recent Target Images"];
					[[NSUserDefaults standardUserDefaults] synchronize];
					break;
				}
			}
		}
	}
	
	{
		// Update the in-memory and on-screen data.
		
		// Remove any previous entry for the image at this path.
		NSEnumerator	*targetEnumerator = [targetImageDicts objectEnumerator];
		NSDictionary	*targetDict = nil;
		while (targetDict = [targetEnumerator nextObject])
		{
			if ([[targetDict objectForKey:@"Path"] isEqualToString:targetImagePath])
			{
				[targetImageDicts removeObject:targetDict];
				[targetImagesTableView reloadData];
				[self tableViewSelectionDidChange:nil];
				break;
			}
		}
	}
}


- (id)initWithDelegate:(id<MacOSaiXMosaicEditorDelegate>)delegate
{
	if (self = [super initWithDelegate:delegate])
	{
		targetImageDicts = [[NSMutableArray alloc] initWithCapacity:16];
		
		NSArray			*recentTargetImageDicts = [[NSUserDefaults standardUserDefaults] objectForKey:@"Recent Target Images"];
		
		if (!recentTargetImageDicts)
		{
				// Check for the old key.
			recentTargetImageDicts = [[NSUserDefaults standardUserDefaults] objectForKey:@"Recent Originals"];
			if (recentTargetImageDicts)
			{
				[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Recent Originals"];
				[[NSUserDefaults standardUserDefaults] setObject:recentTargetImageDicts forKey:@"Recent Target Images"];
				[[NSUserDefaults standardUserDefaults] synchronize];
			}
		}
		
		if (!recentTargetImageDicts)
		{
				// Default to any pictures in ~/Pictures.
			FSRef			picturesRef;
			if (FSFindFolder(kUserDomain, kPictureDocumentsFolderType, false, &picturesRef) == noErr)
			{
				CFURLRef		picturesURLRef = CFURLCreateFromFSRef(kCFAllocatorDefault, &picturesRef);
				if (picturesURLRef)
				{
					NSString		*picturesPath = [(NSURL *)picturesURLRef path];
					NSEnumerator	*pictureNameEnumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:picturesPath] objectEnumerator];
					NSString		*pictureName = nil;
					
					while (pictureName = [pictureNameEnumerator nextObject])
					{
						NSString	*picturePath = [picturesPath stringByAppendingPathComponent:pictureName];
						NSImage		*picture = [[[NSImage alloc] initWithContentsOfFile:picturePath] autorelease];
						
						if (picture)
							[self addTargetImage:picture fromPath:picturePath];
					}
				}
			}
		}
		else
		{
			NSArray			*sortedRecents = [recentTargetImageDicts sortedArrayUsingFunction:compareWithKey context:@"Name"];
			NSEnumerator	*targetEnumerator = [sortedRecents objectEnumerator];
			NSDictionary	*targetDict = nil;
			while (targetDict = [targetEnumerator nextObject])
			{
				NSString	*targetImagePath = [targetDict objectForKey:@"Path"];
				
				if ([[NSFileManager defaultManager] fileExistsAtPath:targetImagePath])
				{
					NSMutableDictionary	*mutableDict = [NSMutableDictionary dictionaryWithDictionary:targetDict];
					NSImage				*thumbnail = [[NSImage alloc] initWithData:[targetDict objectForKey:@"Thumbnail Data"]];
					
					if (thumbnail)
					{
						[mutableDict setObject:thumbnail forKey:@"Thumbnail"];
						[thumbnail release];
						[targetImageDicts addObject:mutableDict];
					}
					else
					{
						NSImage	*targetImage = [[NSImage alloc] initWithContentsOfFile:targetImagePath];
						
						if (targetImage)
						{
							[mutableDict setObject:[[targetImage copyWithLargestDimension:32.0] autorelease] 
											forKey:@"Thumbnail"];
							[targetImageDicts addObject:mutableDict];
						}
					}
				}
			}
		}
	}
	
	return self;
}


- (NSString *)editorNibName
{
	return @"Target Image Editor";
}


- (NSSize)minimumViewSize
{
	return NSMakeSize(200.0, 100.0);
}


- (NSNumber *)targetImageOpacity
{
	return [NSNumber numberWithFloat:1.0];
}


- (void)beginEditing
{
	[super beginEditing];
	
	if ([[[self delegate] mosaic] targetImagePath])
	{
		NSString		*targetImagePath = [[[self delegate] mosaic] targetImagePath];
		NSEnumerator	*targetEnumerator = [targetImageDicts objectEnumerator];
		NSDictionary	*targetDict = nil;
		while (targetDict = [targetEnumerator nextObject])
		{
			if ([[targetDict objectForKey:@"Path"] isEqualToString:targetImagePath])
			{
				[targetImagesTableView selectRow:[targetImageDicts indexOfObject:targetDict] byExtendingSelection:NO];
				break;
			}
		}
	}
	else
		[self tableViewSelectionDidChange:nil];
}


// TODO: find new home
//- (void)updateRecentTargetImages
//{
//	[self removeRecentTargetImages];
//	
//	NSMenu			*mainRecentTargetsMenu = [[mosaicMenu itemWithTag:kTargetImageItemTag] submenu];
//	NSArray			*recentTargetDicts = [[NSUserDefaults standardUserDefaults] objectForKey:@"Recent Targets Images"], 
//		*sortedRecents = [recentTargetDicts sortedArrayUsingFunction:compareWithKey context:@"Name"];
//	NSEnumerator	*targetEnumerator = [sortedRecents reverseObjectEnumerator];
//	NSDictionary	*targetDict = nil;
//	while (targetDict = [targetEnumerator nextObject])
//	{
//		NSString	*targetImagePath = [targetDict objectForKey:@"Path"];
//		
//		if ([[NSFileManager defaultManager] fileExistsAtPath:targetImagePath])
//		{
//			NSMenuItem	*targetItem = [[[NSMenuItem alloc] initWithTitle:[targetDict objectForKey:@"Name"] 
//																	action:@selector(setTargetImageFromMenu:) 
//															 keyEquivalent:@""] autorelease];
//			[targetItem setRepresentedObject:targetImagePath];
//			[targetItem setTarget:self];
//			NSImage		*thumbnail = [[[NSImage alloc] initWithData:[targetDict objectForKey:@"Thumbnail Data"]] autorelease];
//			[targetItem setImage:thumbnail];
//			[recentTargetsMenu insertItem:targetItem atIndex:2];
//			[mainRecentTargetsMenu insertItem:[[targetItem copy] autorelease] atIndex:2];
//		}
//	}
//}


- (IBAction)addTargetImage:(id)sender
{
		// Prompt the user to choose an image from which to make a mosaic.
	NSOpenPanel	*openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAccessoryView:openTargetImageAccessoryView];
	[openPanel beginSheetForDirectory:nil
								 file:nil
								types:[NSImage imageFileTypes]
					   modalForWindow:[(NSView *)[self delegate] window]	// TODO: modify delegate protocol?
						modalDelegate:self
					   didEndSelector:@selector(chooseTargetImagePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
}


- (void)chooseTargetImagePanelDidEnd:(NSOpenPanel *)sheet 
						  returnCode:(int)returnCode
						 contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
	{
		NSString		*targetImagePath = [[sheet filenames] objectAtIndex:0];
		NSImage			*targetImage = [[NSImage alloc] initWithContentsOfFile:targetImagePath];
		
		[self addTargetImage:targetImage fromPath:targetImagePath];
		
// TODO:		[[self document] setTargetImagePath:targetImagePath];
		[[[self delegate] mosaic] setTargetImage:targetImage];
		[targetImage release];
	}
}


- (IBAction)removeTargetImage:(id)sender
{
	int				index = [targetImagesTableView selectedRow];
	
	if (index != -1)
	{
		NSDictionary	*imageDict = [targetImageDicts objectAtIndex:index];
		NSString		*targetImagePath = [imageDict objectForKey:@"Path"];
			
		[self removeTargetImageAtPath:targetImagePath];
	}
	else
		NSBeep();
}


- (void)embellishMosaicView:(MosaicView *)mosaicView inRect:(NSRect)rect;
{
	[super embellishMosaicView:mosaicView inRect:rect];
	
	int	selectedRow = [targetImagesTableView selectedRow];
	
	if (selectedRow >= 0)
	{
		NSRect				mosaicBounds = [mosaicView imageBounds];
		mosaicBounds.origin.x = [mosaicView bounds].origin.x + 10.0;
		mosaicBounds.size.width = [mosaicView bounds].size.width - 20.0;
		mosaicBounds = NSIntersectionRect(mosaicBounds, NSInsetRect([mosaicView visibleRect], 10.0, 0.0));
		float				width = NSWidth(mosaicBounds);
		NSString			*imagePath = [[targetImageDicts objectAtIndex:selectedRow] objectForKey:@"Path"];
		NSAttributedString	*attributedPath = [[NSFileManager defaultManager] attributedPath:imagePath wraps:NO];
		NSSize				size = [attributedPath size];
		
		if (size.width > width - 20.0)
			size.width = width - 20.0;
		
		NSRect				pathBounds = NSMakeRect(NSMidX(mosaicBounds) - size.width / 2.0 - 10.0, 
													NSMinY(mosaicBounds) - 10.0 - size.height - 10.0, 
													size.width + 20.0, 
													size.height + 10.0);
		if (NSMinY(pathBounds) < NSMinY(mosaicBounds) + 10.0)
			pathBounds.origin.y = NSMinY(mosaicBounds) + 10.0;
		
		NSBezierPath		*pathPath = [NSBezierPath bezierPathWithRoundedRect:pathBounds radius:10.0];
		[[NSColor colorWithCalibratedWhite:1.0 alpha:.75] set];
		[pathPath fill];
		[[NSColor colorWithCalibratedWhite:0.0 alpha:.5] set];
		[pathPath stroke];
		
		[attributedPath drawInRect:NSInsetRect(pathBounds, 10.0, 5.0)];
	}
}


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [targetImageDicts count];
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	return [[targetImageDicts objectAtIndex:row] objectForKey:[tableColumn identifier]];
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	int				index = [targetImagesTableView selectedRow];
	
	if (index != -1)
	{
		NSDictionary	*imageDict = [targetImageDicts objectAtIndex:index];
		NSString		*existingTargetImagePath = [[[self delegate] mosaic] targetImagePath], 
						*newTargetImagePath = [imageDict objectForKey:@"Path"];
		BOOL			changeTargetImage = ![existingTargetImagePath isEqualToString:newTargetImagePath];
		
		if (existingTargetImagePath && changeTargetImage && [MacOSaiXWarningController warningIsEnabled:@"Changing Target Image"])
			changeTargetImage = ([MacOSaiXWarningController runAlertForWarning:@"Changing Target Image" 
																		 title:NSLocalizedString(@"Do you wish to change the target image?", @"") 
																	   message:NSLocalizedString(@"All work in the current mosaic will be lost.", @"") 
																  buttonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Change", @""), NSLocalizedString(@"Cancel", @""), nil]] == 0);
		
		if (changeTargetImage)
		{
			[[[self delegate] mosaic] setTargetImagePath:newTargetImagePath];
			
			[[NSUserDefaults standardUserDefaults] setObject:newTargetImagePath forKey:@"Last Chosen Target Image Path"];
			
			NSImage		*targetImage = [[NSImage alloc] initWithContentsOfFile:newTargetImagePath];
			[[[self delegate] mosaic] setTargetImage:targetImage];
			[targetImage release];
		}
	}
}


- (void)dealloc
{
	[targetImageDicts release];
	
	[super dealloc];
}


@end

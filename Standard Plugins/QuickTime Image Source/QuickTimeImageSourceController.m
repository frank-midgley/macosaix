//
//  QuickTimeImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "QuickTimeImageSourceController.h"
#import "QuickTimeImageSource.h"
#import "QuickTimeImageSourceMovie.h"


@implementation QuickTimeImageSourceController


- (void)saveSettings
{
	NSMutableDictionary	*settings = [[[NSUserDefaults standardUserDefaults] objectForKey:@"QuickTime Image Source"] mutableCopy];
	
		// Remember the current movie paths and poster frames.
	NSMutableArray				*movieDicts = [NSMutableArray array];
	NSEnumerator				*movieEnumerator = [[moviesController arrangedObjects] objectEnumerator];
	QuickTimeImageSourceMovie	*movie = nil;
	while (movie = [movieEnumerator nextObject])
		[movieDicts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[movie path], @"Path", 
									[movie title], @"Title", 
									[movie posterFrame], @"Poster Frame", 
									nil]];
	[settings setObject:movieDicts forKey:@"Movies"];
	
	if (currentImageSource)
		[settings setObject:[NSNumber numberWithBool:![currentImageSource canRefetchImages]] 
					 forKey:@"Save Frames"];
	
	[[NSUserDefaults standardUserDefaults] setObject:settings forKey:@"QuickTime Image Source"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[settings release];
}


- (void)sizeMovieView
{
	if ([[moviesController selectedObjects] count] == 1)
	{
		[[movieView superview] setNeedsDisplayInRect:[movieView frame]];
		
		NSSize	maxSize = NSMakeSize(NSWidth([[movieView superview] frame]) - 3.0 - 3.0, 
									 NSHeight([[movieView superview] frame]) - 3.0 - 36.0 - 16.0);
		
		float	aspectRatio = [(QuickTimeImageSourceMovie *)[[moviesController selectedObjects] lastObject] aspectRatio];
		
		if (maxSize.width > maxSize.height * aspectRatio)
		{
			float	scaledWidth = maxSize.height * aspectRatio, 
					halfWidthDiff = (maxSize.width - scaledWidth) / 2.0;
			[movieView setFrame:NSMakeRect(3.0 + halfWidthDiff, 33.0, scaledWidth, maxSize.height + 16.0)];
		}
		else
		{
			float	scaledHeight = maxSize.width / aspectRatio, 
					halfHeightDiff = (maxSize.height - scaledHeight) / 2.0;
			[movieView setFrame:NSMakeRect(3.0, 33.0 + halfHeightDiff, maxSize.width, scaledHeight + 16.0)];
		}
	}
}


- (void)movieSuperViewDidChangeFrame:(NSNotification *)notification
{
	[self sizeMovieView];
}


- (void)awakeFromNib
{
	NSSortDescriptor	*sortDescriptor  = [[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES] autorelease];
	[moviesController setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	
	NSMutableArray	*movies = [NSMutableArray array];
	NSDictionary	*settings = [[NSUserDefaults standardUserDefaults] objectForKey:@"QuickTime Image Source"];
	NSMutableArray	*movieDicts = [settings objectForKey:@"Movies"];
	
	if (movieDicts)
	{
		NSEnumerator	*movieDictEnumerator = [movieDicts objectEnumerator];
		NSDictionary	*movieDict = nil;
		while (movieDict = [movieDictEnumerator nextObject])
		{
			QuickTimeImageSourceMovie	*movie = [QuickTimeImageSourceMovie movieWithPath:[movieDict objectForKey:@"Path"]];
			[movie setPosterFrame:[movieDict objectForKey:@"Path"]];
			[movie setTitle:[movieDict objectForKey:@"Title"]];
			[movies addObject:movie];
		}
	}
	else
	{
		movieDicts = [NSMutableArray array];
		
			// Use the contents of ~/Movies by default.
		FSRef	moviesRef;
		if (FSFindFolder(kUserDomain, kMovieDocumentsFolderType, false, &moviesRef) == noErr)
		{
			CFURLRef		moviesURLRef = CFURLCreateFromFSRef(kCFAllocatorDefault, &moviesRef);
			if (moviesURLRef)
			{
				NSString		*moviesPath = [(NSURL *)moviesURLRef path];
				NSFileManager	*fileManager = [NSFileManager defaultManager];
				NSWorkspace		*workspace = [NSWorkspace sharedWorkspace];
				NSEnumerator	*moviePathEnumerator = [fileManager enumeratorAtPath:moviesPath];
				NSString		*subPath = nil;
				while (subPath = [moviePathEnumerator nextObject])
				{
					NSString	*moviePath = [moviesPath stringByAppendingPathComponent:subPath];
					BOOL		isDirectory = NO;
					
					if ([workspace isFilePackageAtPath:moviePath] ||
						([fileManager fileExistsAtPath:moviePath isDirectory:&isDirectory] && !isDirectory))
						[movies addObject:[QuickTimeImageSourceMovie movieWithPath:moviePath]];
				}
			}
		}
	}
	
	[moviesController setContent:movieDicts];
	
	[self saveSettings];	// must be done after setting the content of the controller
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"QuickTime Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(504.0, 286.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return moviesTable;
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[currentImageSource release];
	currentImageSource = [imageSource retain];
	
	NSString					*imageSourcePath = [(QuickTimeImageSource *)imageSource path];
	QuickTimeImageSourceMovie	*movie = nil;
	
	if (!imageSourcePath)
	{
		if ([[moviesController selectedObjects] count] > 0)
			[currentImageSource setPath:[[moviesController selection] valueForKey:@"path"]];
	}
	else
	{
		NSEnumerator	*movieEnumerator = [[moviesController arrangedObjects] objectEnumerator];
		while (movie = [movieEnumerator nextObject])
			if ([[movie path] isEqualToString:imageSourcePath])
				break;
		
		if (movie)
			[moviesController setSelectedObjects:[NSArray arrayWithObject:movie]];
		else
		{
			movie = [QuickTimeImageSourceMovie movieWithPath:imageSourcePath];
			[moviesController addObject:movie];
			
			[self saveSettings];
		}
	}
	
	[saveFramesCheckBox setState:([currentImageSource canRefetchImages] ? NSOffState : NSOnState)];
	
		// Set up to get notified when the window changes size so that we can adjust the
		// width of the movie view in a way that preserves the movie's aspect ratio.
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(movieSuperViewDidChangeFrame:) 
												 name:NSViewFrameDidChangeNotification 
											   object:[movieView superview]];
}


- (BOOL)settingsAreValid
{
	return ([[moviesController selectedObjects] count] == 1);
}


- (void)editingComplete
{
	[movieView setMovie:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:nil];
}


- (void)chooseAnotherMovie:(id)sender
{
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel beginSheetForDirectory:nil
							  file:nil
							 types:nil	//[NSMovie movieUnfilteredFileTypes]
					modalForWindow:[editorView window] 
					 modalDelegate:self
					didEndSelector:@selector(chooseAnotherMovieDidEnd:returnCode:contextInfo:)
					   contextInfo:nil];
}


- (void)chooseAnotherMovieDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
	{
        NSEnumerator				*moviePathEnumerator = [[sheet filenames] objectEnumerator];
		NSString					*moviePath = nil;
		QuickTimeImageSourceMovie	*movie = nil;
        BOOL						settingsChanged = NO;
        
        while (moviePath = [moviePathEnumerator nextObject])
        {
			NSEnumerator	*movieEnumerator = [[moviesController arrangedObjects] objectEnumerator];
			while (movie = [movieEnumerator nextObject])
				if ([[movie path] isEqualToString:moviePath])
					break;
			
			if (!movie)
			{
				movie = [QuickTimeImageSourceMovie movieWithPath:moviePath];
				[moviesController addObject:movie];
				settingsChanged = YES;
			}
        }
		
        if (!movie)
			NSRunAlertPanel(@"The file you chose does not contain a movie.", nil, @"OK", nil, nil);
        else
            [moviesController setSelectedObjects:[NSArray arrayWithObject:movie]];
        
		if (settingsChanged)
			[self saveSettings];
	}
}


- (IBAction)setSaveFrames:(id)sender
{
	[currentImageSource setCanRefetchImages:([saveFramesCheckBox state] == NSOffState)];
	
	[self saveSettings];
}


#pragma mark -
#pragma mark Table view delegate methods


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	NSArray	*selectedMovies = [moviesController selectedObjects];
	
	if ([selectedMovies count] == 1)
	{
		[self sizeMovieView];
		[currentImageSource setPath:[[selectedMovies lastObject] path]];
	}
	else
		[currentImageSource setPath:nil];
}


#pragma mark -
#pragma mark Split view delegate methods


- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedCoord ofSubviewAt:(int)offset
{
	return MAX(226.0, proposedCoord);
}


- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedCoord ofSubviewAt:(int)offset
{
	return MIN(NSWidth([sender frame]) - 226.0, proposedCoord);
}


- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return NO;
}


#pragma mark -


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[currentImageSource release];
	
	[super dealloc];
}


@end

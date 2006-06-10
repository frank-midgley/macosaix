//
//  QuickTimeImageSourceController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "QuickTimeImageSourceController.h"
#import "QuickTimeImageSource.h"


@implementation QuickTimeImageSourceController


- (NSDictionary *)dictionaryForMovieAtPath:(NSString *)moviePath
{
	if (!moviePath)
		return nil;
	
	NSMutableDictionary	*movieDict = nil;

		// Check if we already have a dictionary for this movie.
	NSEnumerator		*movieDictEnumerator = [[moviesController arrangedObjects] objectEnumerator];
	while (movieDict = [movieDictEnumerator nextObject])
		if ([[movieDict valueForKey:@"path"] isEqualToString:moviePath])
			break;
	
	if (!movieDict)
	{
			// Create a new dictionary if the file at moviePath contains a movie.
		NSMovie				*movie = [[NSMovie alloc] initWithURL:[NSURL fileURLWithPath:moviePath] byReference:YES];
		
		if (movie)
		{
			Movie				qtMovie = [movie QTMovie];
			
			movieDict = [NSMutableDictionary dictionaryWithObject:movie forKey:@"movie"];
			[movieDict setObject:moviePath forKey:@"path"];
			[movieDict setObject:[[moviePath lastPathComponent] stringByDeletingPathExtension] forKey:@"title"];
			
				// Get the movie's aspect ratio.
			Rect				movieBounds;
			GetMovieBox(qtMovie, &movieBounds);
			float				aspectRatio = (float)(movieBounds.right - movieBounds.left) / 
											  (float)(movieBounds.bottom - movieBounds.top);
			[movieDict setObject:[NSNumber numberWithFloat:aspectRatio] forKey:@"aspectRatio"];
			
				// Get the length of the movie in seconds.
			[movieDict setObject:[NSNumber numberWithLong:GetMovieDuration(qtMovie) / GetMovieTimeScale(qtMovie)] 
						  forKey:@"seconds"];
			
				// Get the poster frame or the generic QuickTime icon if the poster is not available.
			PicHandle	picHandle = GetMoviePosterPict(qtMovie);
			OSErr       err = GetMoviesError();
			if (err != noErr || !picHandle)
				[movieDict setObject:[QuickTimeImageSource image] forKey:@"posterFrame"];
			else
			{
				NSImage			*posterFrame = [[NSImage alloc] initWithData:[NSData dataWithBytes:*picHandle 
																							length:GetHandleSize((Handle)picHandle)]];
				[movieDict setObject:posterFrame forKey:@"posterFrame"];
				[posterFrame release];
				
				KillPicture(picHandle);
			}
			
			[movie release];
		}
	}
	
	return movieDict;
}


- (void)saveSettings
{
	NSMutableDictionary	*settings = [[[NSUserDefaults standardUserDefaults] objectForKey:@"QuickTime Image Source"] mutableCopy];
	
		// Remember the current movie paths.
	NSMutableArray		*moviePaths = [NSMutableArray array];
	NSEnumerator		*movieDictEnumerator = [[moviesController arrangedObjects] objectEnumerator];
	NSDictionary		*movieDict = nil;
	while (movieDict = [movieDictEnumerator nextObject])
		[moviePaths addObject:[movieDict objectForKey:@"path"]];
	[settings setObject:moviePaths forKey:@"Movie Paths"];
	
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
		
		float	aspectRatio = [[[[moviesController selectedObjects] lastObject] objectForKey:@"aspectRatio"] floatValue];
		
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
	NSDictionary	*settings = [[NSUserDefaults standardUserDefaults] objectForKey:@"QuickTime Image Source"];
	NSArray			*moviePaths = [settings objectForKey:@"Movie Paths"];
	
	if (!moviePaths)
	{
			// Use the contents of ~/Movies by default.
		NSMutableArray	*defaultMoviePaths = [NSMutableArray array];
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
						[defaultMoviePaths addObject:moviePath];
				}
			}
		}
		
		moviePaths = defaultMoviePaths;
	}
	
		// Populate the list of valid movies from the paths.
	NSMutableArray	*movies = [NSMutableArray array];
	NSEnumerator	*moviePathEnumerator = [moviePaths objectEnumerator];
	NSString		*moviePath = nil;
	while (moviePath = [moviePathEnumerator nextObject])
	{
		NSDictionary	*movieDict = [self dictionaryForMovieAtPath:moviePath];
		if (movieDict)
			[movies addObject:movieDict];
	}
	
	NSSortDescriptor	*sortDescriptor  = [[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES] autorelease];
	[moviesController setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	[moviesController setContent:movies];
	
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
	return NSMakeSize(500.0, 200.0);
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
	
	NSDictionary	*movieDict = [self dictionaryForMovieAtPath:[(QuickTimeImageSource *)imageSource path]];
	if (movieDict)
	{
		if (![[moviesController arrangedObjects] containsObject:movieDict])
		{
			[moviesController addObject:movieDict];
			[self saveSettings];
		}
		[moviesController setSelectedObjects:[NSArray arrayWithObject:movieDict]];
	}
	else if ([[moviesController selectedObjects] count] > 0)
		[currentImageSource setPath:[[moviesController selection] valueForKey:@"path"]];
	
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
        NSEnumerator    *moviePathEnumerator = [[sheet filenames] objectEnumerator];
		NSString		*moviePath = nil;
        NSDictionary    *lastValidMovieDict = nil;
        BOOL            settingsChanged = NO;
        
        while (moviePath = [moviePathEnumerator nextObject])
        {
            NSDictionary	*movieDict = [self dictionaryForMovieAtPath:moviePath];
            if (movieDict)
            {
                lastValidMovieDict = movieDict;
                
                if (![[moviesController arrangedObjects] containsObject:movieDict])
                {
                    [moviesController addObject:movieDict];
                    settingsChanged = YES;
                }
            }
        }
		
        if (!lastValidMovieDict)
			NSRunAlertPanel(@"The file you chose does not contain a movie.", nil, @"OK", nil, nil);
        else
        {
            [moviesController setSelectedObjects:[NSArray arrayWithObject:lastValidMovieDict]];
            if (settingsChanged)
                [self saveSettings];
        }
	}
}


- (IBAction)clearMovieList:(id)sender
{
	[moviesController removeObjects:[moviesController arrangedObjects]];
	
	[currentImageSource setPath:nil];
	
	[self saveSettings];
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
	NSArray	*selectedMovieDicts = [moviesController selectedObjects];
	
	if ([selectedMovieDicts count] == 1)
	{
		[self sizeMovieView];
		[currentImageSource setPath:[[selectedMovieDicts lastObject] valueForKey:@"path"]];
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

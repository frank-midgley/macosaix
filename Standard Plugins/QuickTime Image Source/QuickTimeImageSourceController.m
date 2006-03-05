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
				NSString		*moviesPath = (NSString *)CFURLCopyPath(moviesURLRef);
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
				
				[moviesPath release];
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
	
	[moviesController setContent:movies];
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"QuickTime Image Source" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(504.0, 209.0);
}


- (NSResponder *)firstResponder
{
	return chooseAnotherMovieButton;
}


- (void)setOKButton:(NSButton *)button
{
	okButton = button;
	
		// Set up to get notified when the window changes size so that we can adjust the
		// width of the movie view in a way that preserves the movie's aspect ratio.
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(windowDidResize:) 
												 name:NSWindowDidResizeNotification 
											   object:[okButton window]];
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[currentImageSource release];
	currentImageSource = [imageSource retain];
	
	NSDictionary	*movieDict = [self dictionaryForMovieAtPath:[(QuickTimeImageSource *)imageSource path]];
	if (movieDict)
		[moviesController setSelectedObjects:[NSArray arrayWithObject:movieDict]];
	else
		[currentImageSource setPath:[[moviesController selection] valueForKey:@"path"]];
}


- (void)chooseAnotherMovie:(id)sender
{
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    [oPanel beginSheetForDirectory:nil
							  file:nil
							 types:nil	//[NSMovie movieUnfilteredFileTypes]
					modalForWindow:nil
					 modalDelegate:self
					didEndSelector:@selector(chooseAnotherMovieDidEnd:returnCode:contextInfo:)
					   contextInfo:nil];
}


- (void)chooseAnotherMovieDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
	{
		NSString		*moviePath = [sheet filename];
		NSDictionary	*movieDict = [self dictionaryForMovieAtPath:moviePath];
		if (movieDict)
		{
			[moviesController addObject:movieDict];
			[moviesController setSelectedObjects:[NSArray arrayWithObject:movieDict]];
		}
		else
			NSRunAlertPanel(@"The file you chose does not contain a movie.", nil, @"OK", nil, nil);
	}
}


- (IBAction)clearMovieList:(id)sender
{
	[moviesController removeObjects:[moviesController arrangedObjects]];
	
//	[currentImageSource setPath:nil];	TBD: this should be handled by the selection change...
	
	// TODO: update the prefs
}


#pragma mark -
#pragma mark Table view delegate methods


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	NSArray	*selectedMovieDicts = [moviesController selectedObjects];
	
	if ([selectedMovieDicts count] == 1)
	{
		[currentImageSource setPath:[[selectedMovieDicts lastObject] valueForKey:@"path"]];
		[okButton setEnabled:YES];
	}
	else
	{
		[currentImageSource setPath:nil];
		[okButton setEnabled:NO];
	}
}


#pragma mark -
#pragma mark Window delegate methods


- (void)windowDidResize:(NSNotification *)notification
{
//	if ([currentImageSource path])
//	{
//		NSRect	movieFrame = [movieView frame];
//		int		newMovieWidth = (movieFrame.size.height - 16.0) * [currentImageSource aspectRatio];
//		
//		movieFrame.size.width = newMovieWidth;
//		movieFrame.origin.x = ([[movieView superview] frame].size.width - movieFrame.size.width) / 2.0;
//		[movieView setFrame:movieFrame];
//	}
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
	[currentImageSource release];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:nil];
	
	[super dealloc];
}


@end

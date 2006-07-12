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
	NSMutableDictionary	*settings = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"QuickTime Image Source"] mutableCopy] autorelease];
	
	if (!settings)
		settings = [NSMutableDictionary dictionary];
	
		// Remember the current movie paths and poster frames.
	NSMutableArray				*movieDicts = [NSMutableArray array];
	NSEnumerator				*movieEnumerator = [[moviesController arrangedObjects] objectEnumerator];
	QuickTimeImageSourceMovie	*movie = nil;
	while (movie = [movieEnumerator nextObject])
		[movieDicts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[movie path], @"Path", 
									[movie title], @"Title", 
									[NSArchiver archivedDataWithRootObject:[movie posterFrame]], @"Poster Frame Data", 
									nil]];
	[settings setObject:movieDicts forKey:@"Movies"];
	
	if (currentImageSource)
		[settings setObject:[NSNumber numberWithBool:![currentImageSource canRefetchImages]] 
					 forKey:@"Save Frames"];
	
	[[NSUserDefaults standardUserDefaults] setObject:settings forKey:@"QuickTime Image Source"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


- (void)sizeMovieView
{
	if ([[moviesController selectedObjects] count] == 1)
	{
		[[movieView superview] setNeedsDisplayInRect:[movieView frame]];
		
		NSSize	maxSize = [[movieView superview] frame].size;
		
		float	aspectRatio = [(QuickTimeImageSourceMovie *)[[moviesController selectedObjects] lastObject] aspectRatio];
		
		if (maxSize.width > maxSize.height * aspectRatio)
		{
			float	scaledWidth = maxSize.height * aspectRatio, 
					halfWidthDiff = (maxSize.width - scaledWidth) / 2.0;
			[movieView setFrame:NSMakeRect(halfWidthDiff, 0.0, scaledWidth, maxSize.height)];
		}
		else
		{
			float	scaledHeight = maxSize.width / aspectRatio, 
					halfHeightDiff = (maxSize.height - scaledHeight) / 2.0;
			[movieView setFrame:NSMakeRect(0.0, halfHeightDiff, maxSize.width, scaledHeight)];
		}
		[[movieView superview] setNeedsDisplayInRect:[movieView frame]];
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
			[movie setPosterFrame:[NSUnarchiver unarchiveObjectWithData:[movieDict objectForKey:@"Poster Frame Data"]]];
			[movie setTitle:[movieDict objectForKey:@"Title"]];
			[movies addObject:movie];
		}
	}
	else
	{
			// Use the contents of ~/Movies by default.
		FSRef	moviesRef;
		if (FSFindFolder(kUserDomain, kMovieDocumentsFolderType, false, &moviesRef) == noErr)
		{
			CFURLRef		moviesURLRef = CFURLCreateFromFSRef(kCFAllocatorDefault, &moviesRef);
			if (moviesURLRef)
			{
				NSString		*moviesPath = [(NSURL *)moviesURLRef path];
				NSEnumerator	*moviePathEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:moviesPath];
				NSString		*subPath = nil;
				while (subPath = [moviePathEnumerator nextObject])
				{
					NSString					*moviePath = [moviesPath stringByAppendingPathComponent:subPath];
					QuickTimeImageSourceMovie	*movie = [QuickTimeImageSourceMovie movieWithPath:moviePath];
					
					if ([movie movie])
						[movies addObject:movie];
				}
			}
		}
	}
	
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
	return NSMakeSize(485.0, 250.0);
}


- (NSSize)maximumSize
{
	return NSZeroSize;
}


- (NSResponder *)firstResponder
{
	return moviesTable;
}


- (void)updateSamplingRateField
{
	float	rate = [currentImageSource constantSamplingRate];
	
	if (rate < 1.0)
		[samplingRateField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d frames per second", @""), (int)(1.0 / rate)]];
	else if (rate == 1.0)
		[samplingRateField setStringValue:NSLocalizedString(@"one frame per second", @"")];
	else	// rate > 1.0
		[samplingRateField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"one frame every %d seconds", @""), (int)rate]];
}


- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[currentImageSource release];
	currentImageSource = [imageSource retain];
	
	NSString					*imageSourcePath = [(QuickTimeImageSource *)imageSource path];
	QuickTimeImageSourceMovie	*movie = nil;
	
	if (!imageSourcePath)
	{
		movie = [[moviesController selectedObjects] lastObject];
		
		if (movie)
			[currentImageSource setPath:[[moviesController selection] valueForKey:@"path"]];
	}
	else
	{
		NSEnumerator	*movieEnumerator = [[moviesController arrangedObjects] objectEnumerator];
		while (movie = [movieEnumerator nextObject])
			if ([[movie path] isEqualToString:imageSourcePath])
				break;
		
		if (!movie)
		{
			movie = [QuickTimeImageSourceMovie movieWithPath:imageSourcePath];
			
			if (movie)
			{
				[moviesController addObject:movie];
				
				[self saveSettings];
			}
		}
	}
	
	if (movie)
		[moviesController setSelectedObjects:[NSArray arrayWithObject:movie]];
	
	[samplingRateMatrix selectCellWithTag:[currentImageSource samplingRateType]];
	[self updateSamplingRateField];
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
	
    if ([oPanel runModal] == NSFileHandlingPanelOKButton)
	{
        NSEnumerator				*moviePathEnumerator = [[oPanel filenames] objectEnumerator];
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
				[movie movie];	// force it to load the movie and cache the poster frame
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


- (IBAction)removeMovie:(id)sender
{
	QuickTimeImageSourceMovie	*movie = [[moviesController selectedObjects] lastObject];
	
	if (movie)
	{
		[moviesController removeObject:movie];
		
		[self saveSettings];
	}
}


- (IBAction)setSamplingRateType:(id)sender
{
	[currentImageSource setSamplingRateType:[samplingRateMatrix selectedTag]];
}


- (IBAction)setConstantSamplingRate:(id)sender
{
	[samplingRateMatrix selectCellWithTag:1];
	[currentImageSource setSamplingRateType:1];
	
	int		setting = (int)roundf([sender floatValue]);
	NSLog(@"%f = %d", [sender floatValue], setting);
	float	rate = (setting < 1 ? -1.0 / (setting - 2.0) : setting);
	
	[currentImageSource setConstantSamplingRate:rate];
	
	[self updateSamplingRateField];
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


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[currentImageSource release];
	
	[super dealloc];
}


@end

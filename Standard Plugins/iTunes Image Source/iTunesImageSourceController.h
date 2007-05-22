//
//  iTunesImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on May 18 2006.
//  Copyright (c) 2006 Frank M. Midgley. All rights reserved.
//

#import "iTunesImageSource.h"


@interface MacOSaiXiTunesImageSourceController : NSObject <MacOSaiXDataSourceEditor>
{
	id<MacOSaiXEditorDelegate>	delegate;
	
	IBOutlet NSView				*editorView;

	IBOutlet NSTableView		*playlistTable;
	NSMutableArray				*playlistNames;
	
		// The image source instance currently being edited.
	MacOSaiXiTunesImageSource	*currentImageSource;
}

@end

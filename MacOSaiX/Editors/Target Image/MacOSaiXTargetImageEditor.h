//
//  MacOSaiXTargetImageEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"


@interface MacOSaiXTargetImageEditor : MacOSaiXEditor
{
	IBOutlet NSTableView	*targetImagesTableView;
	IBOutlet NSButton		*addTargetImageButton, 
							*removeTargetImageButton;
	IBOutlet NSView			*openTargetImageAccessoryView;
	
	NSMutableArray			*targetImageDicts;
}

- (IBAction)addTargetImage:(id)sender;
- (IBAction)removeTargetImage:(id)sender;

@end

//
//  MacOSaiXTileEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on Jun 10, 2006
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MacOSaiXTile;


@interface MacOSaiXTileEditor : NSObject
{
	MacOSaiXTile			*tile;
	id						delegate;
	SEL						didEndSelector;
	
	IBOutlet NSView			*accessoryView;
	IBOutlet NSBox			*chosenImageBox;
	IBOutlet NSImageView	*originalImageView,
							*currentImageView, 
							*chosenImageView, 
							*currentImageSourceImageView;
	IBOutlet NSTextField	*currentPercentCroppedTextField, 
							*currentMatchQualityTextField, 
							*currentImageSourceNameField, 
							*currentImageDescriptionField, 
							*chosenPercentCroppedTextField, 
							*chosenMatchQualityTextField;
	float					chosenMatchValue;
}

- (void)chooseImageForTile:(MacOSaiXTile *)tile 
			modalForWindow:(NSWindow *)window 
			 modalDelegate:(id)delegate
			didEndSelector:(SEL)didEndSelector;

@end

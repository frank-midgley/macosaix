//
//  MacOSaiXPreferencesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Jan 7 2006.
//  Copyright (c) 2006 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol MacOSaiXPreferencesController <NSObject>

	// The view containing the preference controls.
- (NSView *)mainView;

	// The minimum size of the main view.
- (NSSize)minimumSize;

	// The first control in the key view loop of the main view.
- (NSResponder *)firstResponder;

	// These messages get sent to a preference pane just before and 
	// just after it becomes the currently selected preference pane.
- (void)willSelect;
- (void)didSelect;

	// The willUnselect message gets sent to the currently selected preference pane 
	// just before and just after it gets swapped out for another preference pane.
- (void)willUnselect;
- (void)didUnselect;

@end

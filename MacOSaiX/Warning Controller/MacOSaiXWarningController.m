//
//  MacOSaiXWarningController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 3/12/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXWarningController.h"

@interface MacOSaiXWarningController (PrivateMethods)
- (void)setWarningName:(NSString *)name;
- (void)setTitle:(NSString *)title;
- (void)setMessage:(NSString *)message;
- (void)setButtonTitles:(NSArray *)buttonTitles;
- (void)setButtonAction:(SEL)action;
@end


@implementation MacOSaiXWarningController


+ (void)setWarning:(NSString *)name isEnabled:(BOOL)enabled
{
	NSString	*defaultsKey = [@"Warn When " stringByAppendingString:name];
	
	if (enabled)
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultsKey];
	else
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:defaultsKey];
}


+ (BOOL)warningIsEnabled:(NSString *)name
{
	NSString	*defaultsKey = [@"Warn When " stringByAppendingString:name];
	NSNumber	*enabledObject = [[NSUserDefaults standardUserDefaults] objectForKey:defaultsKey];
	
	return (!enabledObject || [enabledObject boolValue]);
}


+ (void)enableAllWarnings
{
	// TODO: loop through defaults keys and remove all that start with "Warn When "
	NSDictionary	*defaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
	NSEnumerator	*keyEnumerator = [defaults keyEnumerator];
	NSString		*defaultsKey = nil;
	while (defaultsKey = [keyEnumerator nextObject])
		if ([defaultsKey hasPrefix:@"Warn When "])
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultsKey];
}


#pragma mark -
#pragma mark Warning dialog


+ (int)runAlertForWarning:(NSString *)name 
					title:(NSString *)title 
				  message:(NSString *)message 
			 buttonTitles:(NSArray *)buttonTitles
{
	MacOSaiXWarningController	*controller = [[MacOSaiXWarningController alloc] initWithWindow:nil];
	[controller window];	// load the nib
	[controller setWarningName:name];
	[controller setTitle:title];
	[controller setMessage:message];
	[controller setButtonTitles:buttonTitles];
	[controller setButtonAction:@selector(endModal:)];
	
	int	buttonIndex = [NSApp runModalForWindow:[controller window]];
	
	[controller close];
	
	return buttonIndex;
}


- (IBAction)endModal:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}


#pragma mark -
#pragma mark Warning sheet


+ (void)beginSheetForWarning:(NSString *)name 
					   title:(NSString *)title 
					 message:(NSString *)message 
				buttonTitles:(NSArray *)buttonTitles
			  modalForWindow:(NSWindow *)window 
			   modalDelegate:(id)delegate
		  didDismissSelector:(SEL)didDismissSelector 
				 contextInfo:(void *)contextInfo
{
	MacOSaiXWarningController	*controller = [[MacOSaiXWarningController alloc] initWithWindow:nil];
	[controller window];	// load the nib
	[controller setWarningName:name];
	[controller setTitle:title];
	[controller setMessage:message];
	[controller setButtonTitles:buttonTitles];
	[controller setButtonAction:@selector(endSheet:)];
	
	[NSApp beginSheetModalForWindow:window 
					  modalDelegate:self 
					 didEndSelector:@selector(warningSheetDidEnd:returnCode:contextInfo:) 
						contextInfo:[[NSDictionary alloc] initWithObjectsAndKeys:
											delegate, @"Delegate", 
											NSStringFromSelector(didDismissSelector), @"Did Dismiss Selector", 
											[NSValue valueWithPointer:contextInfo], @"Context Info", 
											nil]];
}


- (IBAction)endSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
}


- (void)warningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
{
	[sheet orderOut:self];
	
	NSDictionary		*parameters = contextInfo;
	id					delegate = [parameters objectForKey:@"Delegate"];
	SEL					didDismissSelector = NSSelectorFromString([parameters objectForKey:@"Did Dismiss Selector"]);
	void				*context = [[parameters objectForKey:@"Context Info"] pointerValue];
	NSMethodSignature	*methodSig = [delegate methodSignatureForSelector:didDismissSelector];
	NSInvocation		*invocation = [NSInvocation invocationWithMethodSignature:methodSig];
	
	[invocation setArgument:&returnCode atIndex:0];
	[invocation setArgument:&context atIndex:1];
	[invocation invoke];
}


#pragma mark -


- (NSString *)windowNibName
{
	return @"Warning";
}


- (void)setWarningName:(NSString *)name
{
	[warningName autorelease];
	warningName = [name copy];
	
	[dontShowAgainButton setState:([[self class] warningIsEnabled:name] ? NSOffState : NSOnState)];
}


- (IBAction)setWarningIsEnabled:(id)sender
{
	[[self class] setWarning:warningName isEnabled:([dontShowAgainButton state] == NSOffState)];
}


- (void)setTitle:(NSString *)title
{
	if (title)
		[titleField setStringValue:title];
}

- (void)setMessage:(NSString *)message
{
	if (message)
		[messageField setStringValue:message];
}


- (void)setButtonTitles:(NSArray *)buttonTitles
{
	float	rightEdge = NSMaxX([defaultButton frame]);
	
	[defaultButton setTitle:[buttonTitles objectAtIndex:0]];
	[defaultButton sizeToFit];
	[defaultButton setFrame:NSOffsetRect([defaultButton frame], rightEdge - NSMaxX([defaultButton frame]), 0.0)];
	
	rightEdge = NSMinX([defaultButton frame]) - 20.0;
	
	if ([buttonTitles count] > 1)
	{
		[alternateButton setTitle:[buttonTitles objectAtIndex:1]];
		[alternateButton sizeToFit];
		[alternateButton setFrame:NSOffsetRect([alternateButton frame], rightEdge - NSMaxX([alternateButton frame]), 0.0)];
		
		rightEdge = NSMinX([alternateButton frame]) - 20.0;
	}
	else
	{
		[alternateButton removeFromSuperview];
		alternateButton = nil;
	}
	
	if ([buttonTitles count] > 2)
	{
		[otherButton setTitle:[buttonTitles objectAtIndex:2]];
		[otherButton sizeToFit];
		[otherButton setFrame:NSOffsetRect([otherButton frame], rightEdge - NSMaxX([otherButton frame]), 0.0)];
		
		rightEdge = NSMinX([otherButton frame]) - 20.0;
	}
	else
	{
		[otherButton removeFromSuperview];
		otherButton = nil;
	}
	
	// TBD: check if the right edge overlaps the checkbox?
}


- (void)setButtonAction:(SEL)action
{
	[defaultButton setTarget:self];
	[defaultButton setAction:action];
	
	[alternateButton setTarget:self];
	[alternateButton setAction:action];
	
	[otherButton setTarget:self];
	[otherButton setAction:action];
}


#pragma mark -


- (void)dealloc
{
	[warningName release];
	
	[super dealloc];
}


@end

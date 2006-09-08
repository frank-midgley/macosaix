//
//  MacOSaiXProgressController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/24/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXProgressController.h"


@implementation MacOSaiXProgressController


- (NSString *)windowNibName
{
	return @"Progress";
}


- (void)displayPanelWithParameters:(NSDictionary *)parameters
{
	NSString	*message = [parameters objectForKey:@"Message"];
	NSWindow	*window = [parameters objectForKey:@"Window"];
	
	[self window];
	[messageField setStringValue:(message ? message : NSLocalizedString(@"Please wait...", @""))];
	[progressIndicator setDoubleValue:0.0];
	[progressIndicator setIndeterminate:YES];
	[progressIndicator startAnimation:self];
	
	[NSApp beginSheet:[self window]
	   modalForWindow:window 
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}


- (void)displayPanelWithMessage:(NSString *)message modalForWindow:(NSWindow *)window
{
	NSMutableDictionary	*parameters = [NSMutableDictionary dictionary];
	if (message)
		[parameters setObject:message forKey:@"Message"];
	if (window)
		[parameters setObject:window forKey:@"Window"];
	
	if (pthread_main_np())
		[self displayPanelWithParameters:parameters];
	else
		[self performSelectorOnMainThread:@selector(displayPanelWithParameters:) 
							   withObject:parameters 
							waitUntilDone:YES];
}


- (void)setCancelTarget:(id)target action:(SEL)action
{
	[self window];
	[cancelButton setTarget:target];
	[cancelButton setAction:action];
	[cancelButton setEnabled:[target respondsToSelector:action]];
}


- (void)setPercentComplete:(NSNumber *)percentComplete
{
	if (pthread_main_np())
	{
		double	percent = [percentComplete doubleValue];
		[progressIndicator setIndeterminate:(percent < 0.0 || percent > 100.0)];
		[progressIndicator setDoubleValue:percent];
	}
	else
		[self performSelectorOnMainThread:@selector(setPercentComplete:) 
							   withObject:percentComplete 
							waitUntilDone:YES];
}


- (void)setMessage:(NSString *)message, ...
{
	NSString	*formattedMessage = nil;
	va_list		argList;
	
	va_start(argList, message);
		formattedMessage = [[NSString alloc] initWithFormat:message arguments:argList];
	va_end(argList);

	if (pthread_main_np())
		[messageField setStringValue:formattedMessage];
	else
		[self performSelectorOnMainThread:@selector(setMessage:) 
							   withObject:formattedMessage 
							waitUntilDone:YES];
}


- (void)closePanel
{
	if (pthread_main_np())
	{
		[NSApp endSheet:[self window]];
		[progressIndicator stopAnimation:self];
		[[self window] orderOut:nil];
		[cancelButton setTarget:nil];
		[cancelButton setAction:nil];
		[cancelButton setEnabled:NO];
	}
	else
		[self performSelectorOnMainThread:@selector(closePanel) 
							   withObject:nil 
							waitUntilDone:NO];
}


@end

#import "GoogleImageSourceController.h"

@implementation GoogleImageSourceController

+ (NSString *)name
{
	return @"Google";
}


- (NSView *)imageSourceView
{
	if (!_imageSourceView)
		[NSBundle loadNibNamed:@"Google Image Source" owner:self];
	return _imageSourceView;
}


@end

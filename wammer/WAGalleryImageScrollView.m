//
//  WAGalleryImageScrollView.m
//  wammer
//
//  Created by Evadne Wu on 5/28/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAGalleryImageScrollView.h"

@implementation WAGalleryImageScrollView

- (void) layoutSubviews {

	[super layoutSubviews];
	
	//	http://stackoverflow.com/questions/638299/uiscrollview-with-centered-uiimageview-like-photos-app
	
	UIView *tileContainerView = [self.subviews count] ? [self.subviews objectAtIndex:0] : nil;

	if (tileContainerView) {
	
		CGSize boundsSize = self.bounds.size;
		CGRect frameToCenter = tileContainerView.frame;

		if (frameToCenter.size.width < boundsSize.width)
			frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2;
		else
			frameToCenter.origin.x = 0;

		if (frameToCenter.size.height < boundsSize.height)
			frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2;
		else
			frameToCenter.origin.y = 0;

		tileContainerView.frame = frameToCenter;
	
	}

}

@end

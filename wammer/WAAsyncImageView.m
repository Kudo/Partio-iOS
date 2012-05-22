//
//  WAAsyncImageView.m
//  wammer
//
//  Created by Evadne Wu on 12/13/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAAsyncImageView.h"
#import "UIImage+IRAdditions.h"


@interface WAAsyncImageView ()

@property (nonatomic, readwrite, assign) void * lastImagePtr;

@end

@implementation WAAsyncImageView
@synthesize lastImagePtr;

- (void) setImage:(UIImage *)newImage {

	[self setImage:newImage withOptions:WAImageViewForceAsynchronousOption];

}

- (void) setImage:(UIImage *)newImage withOptions:(WAImageViewOptions)options {

	void * imagePtr = (__bridge void *)newImage;

	if (lastImagePtr == imagePtr)
		return;
  
  lastImagePtr = imagePtr;
	
  if (!newImage) {
  
    [super setImage:nil];
    return;
  
  }  

	if (options & WAImageViewForceSynchronousOption) {
		[super setImage:nil];
		[self.delegate imageViewDidUpdate:self];
		return;
	}
	
	[super setImage:nil];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^ {

    UIImage *decodedImage = [newImage irDecodedImage];
		
		CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopDefaultMode, ^{
			
      if (self.lastImagePtr != imagePtr)
				return;
			
      [super setImage:decodedImage];
      [self.delegate imageViewDidUpdate:self];
		
		});
  
  });

}

@end

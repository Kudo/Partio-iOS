//
//  WAGalleryImageView.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/5/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WAGalleryImageView.h"
#import "WAImageView.h"

#import "CGGeometry+IRAdditions.h"
#import "QuartzCore+IRAdditions.h"


@interface WAGalleryImageView () <UIScrollViewDelegate>
@property (nonatomic, readwrite, retain) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, readwrite, retain) UIScrollView *scrollView;
@property (nonatomic, readwrite, retain) UIImageView *imageView;

@property (nonatomic, readwrite, assign) BOOL needsContentAdjustmentOnLayout;
@property (nonatomic, readwrite, assign) BOOL revertsOnZoomEnd;

@end


@implementation WAGalleryImageView
@synthesize activityIndicator, imageView, scrollView;
@synthesize needsContentAdjustmentOnLayout, revertsOnZoomEnd;
@synthesize delegate;

+ (WAGalleryImageView *) viewForImage:(UIImage *)image {

	WAGalleryImageView *returnedView = [[[self alloc] init] autorelease];
	returnedView.image = image;
	return returnedView;

}

- (void) waInit {
	
	//	Host provides recognizer
	//	UITapGestureRecognizer *doubleTapRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)] autorelease];
	//	doubleTapRecognizer.numberOfTapsRequired = 2;
	//	[self addGestureRecognizer:doubleTapRecognizer];

	self.activityIndicator = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge] autorelease];
	self.activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
	self.activityIndicator.hidesWhenStopped = NO;
	self.activityIndicator.center = (CGPoint){
		CGRectGetMidX(self.bounds),
		CGRectGetMidY(self.bounds)
	};
	[self.activityIndicator startAnimating];
	[self addSubview:self.activityIndicator];
	
	self.scrollView = [[[UIScrollView alloc] initWithFrame:self.bounds] autorelease];
	self.scrollView.minimumZoomScale = 0.01;
	self.scrollView.maximumZoomScale = 4.0f;
	self.scrollView.showsHorizontalScrollIndicator = NO;
	self.scrollView.showsVerticalScrollIndicator = NO;
	self.scrollView.delegate = self;
	self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	[self addSubview:self.scrollView];

	self.imageView = [[[WAImageView alloc] initWithFrame:self.scrollView.bounds] autorelease];
	self.imageView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
	self.imageView.contentMode = UIViewContentModeScaleAspectFit;
	[self.scrollView addSubview:self.imageView];
	
	#if 0
	
		self.clipsToBounds = NO;
		self.scrollView.clipsToBounds = NO;
		self.imageView.clipsToBounds = NO;
		
		self.layer.borderColor = [UIColor redColor].CGColor;
		self.layer.borderWidth = 2.0f;
		
		self.scrollView.layer.borderColor = [UIColor blueColor].CGColor;
		self.scrollView.layer.borderWidth = 2.0f;
		
		self.imageView.layer.borderColor = [UIColor greenColor].CGColor;
		self.imageView.layer.borderWidth = 2.0f;
	
	#endif
	
	self.needsContentAdjustmentOnLayout = YES;
	[self setNeedsLayout];
	
	self.exclusiveTouch = YES;
	
}

- (void) setBounds:(CGRect)newBounds {

	if (!CGRectEqualToRect(self.bounds, newBounds))
		self.needsContentAdjustmentOnLayout = YES;

	[super setBounds:newBounds];

}

- (void) setImage:(UIImage *)newImage {

	[self setImage:newImage animated:NO];

}

- (void) setImage:(UIImage *)newImage animated:(BOOL)animate {

	if (self.imageView.image == newImage)
		return;

	void (^operations)() = ^ {
		[self willChangeValueForKey:@"image"];
		self.imageView.image = newImage;
		self.imageView.bounds = (CGRect) { CGPointZero, newImage.size } ;
		self.scrollView.contentSize = newImage.size;
		self.activityIndicator.hidden = !!(newImage);
		[self didChangeValueForKey:@"image"];
	};

	if (animate) {
	
		[UIView transitionWithView:self duration:0.3f options:UIViewAnimationOptionAllowAnimatedContent|UIViewAnimationOptionAllowUserInteraction animations:operations completion:nil];
	
	} else {
	
		operations();
	
	}

}

- (UIImage *) image {

	return self.imageView.image;

}

- (UIView *) viewForZoomingInScrollView:(UIScrollView *)aScrollView {

	return self.imageView;

}

- (void) scrollViewDidZoom:(UIScrollView *)scrollView {

	[self.delegate galleryImageViewDidBeginInteraction:self];

}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {

	[self.delegate galleryImageViewDidBeginInteraction:self];

}

- (void) scrollViewDidEndZooming:(UIScrollView *)aScrollView withView:(UIView *)view atScale:(float)scale {
	
	[UIView animateWithDuration:0.3f animations: ^ {

		if (scale > 1) {
	
			CGRect scrollViewBounds = self.scrollView.bounds;
			CGRect imageViewFrame = self.imageView.frame;
			
			aScrollView.contentInset = (UIEdgeInsets){
				MAX(0, 0.5f * (CGRectGetHeight(scrollViewBounds) - CGRectGetHeight(imageViewFrame))),
				MAX(0, 0.5f * (CGRectGetWidth(scrollViewBounds) - CGRectGetWidth(imageViewFrame))),
				0,
				0
			};
			
			[self layoutSubviews];
			
		} else {
		
			self.needsContentAdjustmentOnLayout = YES;
			[aScrollView setZoomScale:1 animated:NO];
			[self layoutSubviews];
		
		}

//		if (revertsOnZoomEnd) {
//			[aScrollView setZoomScale:1 animated:NO];
//			revertsOnZoomEnd = NO;
//		}
	
	}];

}

- (void) handleDoubleTap:(UITapGestureRecognizer *)aRecognizer {

	CGFloat scale = self.scrollView.zoomScale;
	self.needsContentAdjustmentOnLayout = YES;
	
	[UIView animateWithDuration:0.3f animations:^{
		
		if (scale < 1)
			[self.scrollView setZoomScale:1 animated:NO];
		else if (scale >= self.scrollView.maximumZoomScale)
			[self.scrollView setZoomScale:1 animated:NO];
		else
			[self.scrollView setZoomScale:self.scrollView.maximumZoomScale animated:NO];
		
		[self layoutSubviews];

	}];

}

- (void) layoutSubviews {

	[super layoutSubviews];
	
	CGRect scrollViewBounds = self.scrollView.bounds;
	CGRect presumedImageRect = IRGravitize(scrollViewBounds, self.image.size, kCAGravityResizeAspect);
	
	if (self.needsContentAdjustmentOnLayout) {
	
		CGRect oldImageViewBounds = self.imageView.bounds;
		CGPoint oldImageViewCenter = self.imageView.center;
		CGSize oldScrollViewContentSize = self.scrollView.contentSize;
		
		CGRect newImageViewBounds = (CGRect){
			CGPointZero,
			presumedImageRect.size
			//	(self.scrollView.zoomScale > 1) ? presumedImageRect.size : scrollViewBounds.size
		};
		
		CGPoint newImageViewCenter = (CGPoint){
			CGRectGetMidX(newImageViewBounds),
			CGRectGetMidY(newImageViewBounds)
		};
		
		CGSize newScrollViewContentSize = self.imageView.bounds.size;
		
		if (!CGRectEqualToRect(oldImageViewBounds, newImageViewBounds))
			self.imageView.bounds = newImageViewBounds;
		
		if (!CGPointEqualToPoint(oldImageViewCenter, newImageViewCenter))
			self.imageView.center = newImageViewCenter;
		
		if (!CGSizeEqualToSize(oldScrollViewContentSize, newScrollViewContentSize))
			self.scrollView.contentSize = newScrollViewContentSize;
				
	}
	
	if (self.needsContentAdjustmentOnLayout) {
	
		UIEdgeInsets oldContentInset = self.scrollView.contentInset;
		UIEdgeInsets newContentInset = oldContentInset;
		
		CGPoint oldContentOffset = self.scrollView.contentOffset;
		CGPoint newContentOffset = oldContentOffset;
	
		if (self.scrollView.zoomScale > 1) {
		
			newContentInset = UIEdgeInsetsZero;
		
		} else {

			newContentInset = (UIEdgeInsets) {
				0.5f * (CGRectGetHeight(scrollViewBounds) - CGRectGetHeight(presumedImageRect)),
				0.5f * (CGRectGetWidth(scrollViewBounds) - CGRectGetWidth(presumedImageRect)),
				-0.5f * (CGRectGetHeight(scrollViewBounds) - CGRectGetHeight(presumedImageRect)),
				-0.5f * (CGRectGetWidth(scrollViewBounds) - CGRectGetWidth(presumedImageRect))
			};
			
			newContentOffset = (CGPoint){
			
				-1 * self.scrollView.contentInset.left,
				-1 * self.scrollView.contentInset.top
			
			};

		}
		
		if (!UIEdgeInsetsEqualToEdgeInsets(oldContentInset, newContentInset)) {
			NSLog(@"content inset %@ -> %@", NSStringFromUIEdgeInsets(oldContentInset), NSStringFromUIEdgeInsets(newContentInset));
			self.scrollView.contentInset = newContentInset;
		}
		
		if (!CGPointEqualToPoint(oldContentOffset, newContentOffset)) {
			NSLog(@"content offset %@ -> %@", NSStringFromCGPoint(oldContentOffset), NSStringFromCGPoint(newContentOffset));
			self.scrollView.contentOffset = newContentOffset;
		}
	
	}

//	NSLog(@"self.scrollView.contentOffset -> %@", NSStringFromCGPoint(self.scrollView.contentOffset));	
//	NSLog(@"self.scrollView.contentInset -> %@", NSStringFromUIEdgeInsets(self.scrollView.contentInset));
	
	self.needsContentAdjustmentOnLayout = NO;
	
}

- (void) reset {

	self.needsContentAdjustmentOnLayout = YES;
	
	if (self.scrollView.decelerating || self.scrollView.tracking || self.scrollView.dragging || self.scrollView.zoomBouncing || self.scrollView.zooming)
		self.revertsOnZoomEnd = YES;
	else
		[self.scrollView setZoomScale:1 animated:NO];
	
	[self setNeedsLayout];

}





- (id) initWithFrame:(CGRect)frame {
	
	self = [super initWithFrame:frame];
	if (!self)
		return nil;
		
	[self waInit];
	
	return self;

}

- (id) initWithCoder:(NSCoder *)aDecoder {
	
	self = [super initWithCoder:aDecoder];
	if (!self)
		return nil;
		
	[self waInit];
	
	return self;

}

- (void) dealloc {

	[activityIndicator release];
	[imageView release];
	[scrollView release];

	[super dealloc];
	
}

@end

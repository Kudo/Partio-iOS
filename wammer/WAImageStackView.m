//
//  WAImageStackView.m
//  wammer-iOS
//
//  Created by Evadne Wu on 7/28/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WAImageStackView.h"
#import "WADataStore.h"

#import "CGGeometry+IRAdditions.h"
#import "QuartzCore+IRAdditions.h"
#import "UIKit+IRAdditions.h"

#import "WAImageView.h"





static const NSString *kWAImageStackViewElementCanonicalTransform = @"kWAImageStackViewElementCanonicalTransform";
static const NSString *kWAImageStackViewElementImage = @"kWAImageStackViewElementImage";


@interface WAImageStackView () <UIGestureRecognizerDelegate>

- (void) waInit;
@property (nonatomic, readwrite, retain) NSArray *shownImages;
@property (nonatomic, readwrite, retain) UIPinchGestureRecognizer *pinchRecognizer;
@property (nonatomic, readwrite, retain) UIRotationGestureRecognizer *rotationRecognizer;
@property (nonatomic, readwrite, retain) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, readwrite, retain) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, readwrite, assign) UIView *firstPhotoView;
@property (nonatomic, readwrite, assign) BOOL gestureProcessingOngoing;

- (void) setShownImages:(NSArray *)newImages withDecodingCompletion:(void(^)(void))aBlock;

@end


@implementation WAImageStackView

@synthesize state;
@synthesize images, delegate, shownImages;
@synthesize pinchRecognizer, rotationRecognizer, tapRecognizer, activityIndicator, firstPhotoView;
@synthesize gestureProcessingOngoing;
@synthesize maxNumberOfImages;

- (id) initWithCoder:(NSCoder *)aDecoder {

	self = [super initWithCoder:aDecoder];
	
	if (!self)
		return nil;
		
	[self waInit];
	
	return self;

}

- (id) initWithFrame:(CGRect)frame {

	self = [super initWithFrame:frame];
	
	if (!self)
		return nil;
	
	[self waInit];
	
	return self;

}

- (void) waInit {

	self.maxNumberOfImages = 2;

	self.gestureProcessingOngoing = NO;
	self.state = WAImageStackViewInteractionNormal;
	
	self.pinchRecognizer = [[[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)] autorelease];
	self.pinchRecognizer.delegate = self;
	[self addGestureRecognizer:self.pinchRecognizer];
	
	self.rotationRecognizer = [[[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotation:)] autorelease];
	self.rotationRecognizer.delegate = self;
	[self addGestureRecognizer:self.rotationRecognizer];
	
	self.tapRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)] autorelease];
	[self addGestureRecognizer:self.tapRecognizer];
	
	self.activityIndicator = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
	self.activityIndicator.center = (CGPoint){
		CGRectGetMidX(self.bounds),
		CGRectGetMidY(self.bounds)
	};
	self.activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
	[self.activityIndicator startAnimating];
	[self insertSubview:self.activityIndicator atIndex:[self.subviews count]];
	
}

- (void) setState:(WAImageStackViewInteractionState)newState {

	if (state == newState)
		return;
	
 	[self willChangeValueForKey:@"state"];
	state = newState;
	[self didChangeValueForKey:@"state"];
	
	if ([self.delegate respondsToSelector:@selector(imageStackView:didChangeInteractionStateToState:)])
		[self.delegate imageStackView:self didChangeInteractionStateToState:newState];

}

- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {

	if (gestureRecognizer == self.pinchRecognizer)
		return (otherGestureRecognizer == self.rotationRecognizer);
	
	if (gestureRecognizer == self.rotationRecognizer)
		return (otherGestureRecognizer == self.pinchRecognizer);

	return NO;

}

- (void) setImages:(NSArray *)newImages {

	[self setImages:newImages asynchronously:YES withDecodingCompletion:nil];

}

- (void) setImages:(NSArray *)newImages asynchronously:(BOOL)async withDecodingCompletion:(void (^)(void))aBlock {

	async = NO;

	if (images == newImages)
		return;

	[self willChangeValueForKey:@"images"];
	[images release];
	images = [newImages retain];
	[self didChangeValueForKey:@"images"];
	
	self.activityIndicator.hidden = NO;
	
	NSArray *decodedImages = [self.images objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:(NSRange){ 0, MIN(3, [self.images count]) }]];

	if (async) {
	
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^(void) {
		
			NSArray *actualDecodedImages = [decodedImages irMap: ^ (UIImage *anImage, NSUInteger index, BOOL *stop) {
				return [anImage irDecodedImage];
			}];
			
			dispatch_async(dispatch_get_main_queue(), ^ {
				[self setShownImages:actualDecodedImages withDecodingCompletion:aBlock];
			});
			
		});
	
	} else {
			
		[self setShownImages:decodedImages withDecodingCompletion:aBlock];
	
	}

}

- (void) setShownImages:(NSArray *)newShownImages {

	[self setShownImages:newShownImages withDecodingCompletion:nil];

}

- (void) setShownImages:(NSArray *)newShownImages withDecodingCompletion:(void(^)(void))aBlock {

	if (self.gestureProcessingOngoing) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0f * NSEC_PER_SEC), dispatch_get_current_queue(), ^(void){
				[self performSelector:_cmd withObject:newShownImages withObject:aBlock];
		});
		return;
	}
	
	if ([newShownImages isEqualToArray:shownImages]) {
		if (aBlock)
			aBlock();
		return;
	}
	
	[self willChangeValueForKey:@"shownImages"];
	[shownImages release];
	shownImages = [newShownImages retain];
	[self didChangeValueForKey:@"shownImages"];
	
	
	static int kPhotoViewTag = 1024;
	
	self.firstPhotoView = nil;

		[[self.subviews objectsAtIndexes:[self.subviews indexesOfObjectsPassingTest: ^ (UIView *aSubview, NSUInteger idx, BOOL *stop) {
			
			return (BOOL)(aSubview.tag == kPhotoViewTag);
				
		}]] enumerateObjectsUsingBlock: ^ (UIView *aSubview, NSUInteger idx, BOOL *stop) {
		
			[aSubview removeFromSuperview];
			
		}];
			
		[shownImages enumerateObjectsUsingBlock: ^ (UIImage *anImage, NSUInteger idx, BOOL *stop) {
		
			UIView *frameView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
			objc_setAssociatedObject(frameView, kWAImageStackViewElementImage, anImage, OBJC_ASSOCIATION_RETAIN);
			frameView.tag = kPhotoViewTag;
			frameView.layer.backgroundColor = [UIColor colorWithWhite:0.75 alpha:1].CGColor;
			frameView.layer.borderColor = [UIColor whiteColor].CGColor;
			frameView.layer.borderWidth = 4.0f;
			frameView.layer.shadowOffset = (CGSize){ 0, 1 };
			frameView.layer.shadowRadius = 1.0f;
			frameView.layer.shadowOpacity = 0.25f;
			frameView.layer.edgeAntialiasingMask = kCALayerLeftEdge|kCALayerRightEdge|kCALayerTopEdge|kCALayerBottomEdge;
			[frameView.layer setActions:[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNull null], @"shadowPath",
			nil]];
			frameView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
			frameView.opaque = NO;
			
			WAImageView *innerImageView = [[[WAImageView alloc] initWithFrame:frameView.bounds] autorelease];
			innerImageView.image = (UIImage *)objc_getAssociatedObject(frameView, kWAImageStackViewElementImage);
			innerImageView.layer.borderColor = [UIColor greenColor].CGColor;
			innerImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
			innerImageView.contentMode = UIViewContentModeScaleAspectFill;
			innerImageView.layer.masksToBounds = YES;
			
			[frameView addSubview:innerImageView];					
			[self addSubview:frameView];		
			
			//NSParameterAssert(innerImageView.layer.contents);
			
			self.activityIndicator.hidden = YES;
			
		}];
		
		[self layoutSubviews];
		[self setNeedsLayout];
		
		if (aBlock)
			aBlock();
	
}
	
- (void) layoutSubviews {

	NSLog(@"image stack view: %d images.", [self.images count]);

	[self sendSubviewToBack:self.activityIndicator];

	if (self.gestureProcessingOngoing)
		return;
	
	static int kPhotoViewTag = 1024;
	__block CGRect photoViewFrame = CGRectNull;
	
	NSArray *allPhotoViews = [self.subviews objectsAtIndexes:[self.subviews indexesOfObjectsPassingTest: ^ (UIView *aSubview, NSUInteger idx, BOOL *stop) {
		
		return (BOOL)(aSubview.tag == kPhotoViewTag);
			
	}]];
	
	switch ([allPhotoViews count]) {
  case 1: {
    UIImageView *innerImageView = [allPhotoViews objectAtIndex:0];
		innerImageView.frame = CGRectMake(0, 0, 296, 196);
		[self addSubview:innerImageView];
    break; }
	case 2: {
		UIImageView *innerImageView = [allPhotoViews objectAtIndex:0];
		innerImageView.frame = CGRectMake(0, 0, 146, 196);
		[self addSubview:innerImageView];

		innerImageView = [allPhotoViews objectAtIndex:1];
		innerImageView.frame = CGRectMake(150, 0, 146, 196);
		[self addSubview:innerImageView];

		break; }
	case 3:{
		UIImageView *innerImageView = [allPhotoViews objectAtIndex:0];
		innerImageView.frame = CGRectMake(0, 0, 196, 196);
		[self addSubview:innerImageView];

		innerImageView = [allPhotoViews objectAtIndex:1];
		innerImageView.frame = CGRectMake(200, 0, 96, 96);
		[self addSubview:innerImageView];

		innerImageView = [allPhotoViews objectAtIndex:2];
		innerImageView.frame = CGRectMake(200, 100, 96, 96);
		[self addSubview:innerImageView];
		break; }
	
  default:
    break;
}
	
//	[allPhotoViews enumerateObjectsWithOptions:NSEnumerationReverse usingBlock: ^ (UIView *imageView, NSUInteger idx, BOOL *stop) {
//	
//		UIImageView *innerImageView = (UIImageView *)[imageView.subviews objectAtIndex:0];
//		CGSize imageSize = ((UIImage *)objc_getAssociatedObject(imageView, kWAImageStackViewElementImage)).size;
//		imageSize.width *= 16;
//		imageSize.height *= 16;
//		
//		photoViewFrame = CGRectIntegral(IRCGSizeGetCenteredInRect(imageSize, self.bounds, 8.0f, YES));
//		
//		if (idx == ([allPhotoViews count] - 1)) {
//		
//			imageView.layer.transform = CATransform3DIdentity;
//			innerImageView.contentMode = UIViewContentModeScaleAspectFit;
//			
//			self.firstPhotoView = imageView;
//
//		} else {
//		
//			CGFloat baseDelta = 2.0f;	//	at least ± 2°
//			CGFloat allowedAdditionalDeltaInDegrees = 0.0f; //	 with this much added variance
//			CGFloat rotatedDegrees = baseDelta + ((rand() % 2) ? 1 : -1) * (((1.0f * rand()) / (1.0f * INT_MAX)) * allowedAdditionalDeltaInDegrees);
//			
//			imageView.layer.transform = CATransform3DMakeRotation((rotatedDegrees / 360.0f) * 2 * M_PI, 0.0f, 0.0f, 1.0f);
//			innerImageView.contentMode = UIViewContentModeScaleAspectFill;
//
//		}
//		
//		imageView.frame = photoViewFrame;
//		imageView.layer.shadowPath = [UIBezierPath bezierPathWithRect:imageView.bounds].CGPath;
//		objc_setAssociatedObject(imageView.layer, kWAImageStackViewElementCanonicalTransform, [NSValue valueWithCATransform3D:imageView.layer.transform], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//		
//	}];
	
}

- (void) handlePinch:(UIPinchGestureRecognizer *)aPinchRecognizer {

	static CGPoint startingTouchPoint;

	NSValue *canonicalTransformValue = objc_getAssociatedObject(self.firstPhotoView.layer, kWAImageStackViewElementCanonicalTransform);
	CATransform3D canonicalTransform = canonicalTransformValue ? [canonicalTransformValue CATransform3DValue] : CATransform3DIdentity;
	
	switch (aPinchRecognizer.state) {
	
		case UIGestureRecognizerStatePossible:
		case UIGestureRecognizerStateBegan: {
		
			startingTouchPoint = [aPinchRecognizer locationInView:self];
		
			self.state = WAImageStackViewInteractionNormal;
			self.gestureProcessingOngoing = YES;
		
			break;
		
		}
		
		case UIGestureRecognizerStateChanged: {
		
			CGPoint currentTouchPoint = [aPinchRecognizer locationInView:self];
			
			self.state = (self.pinchRecognizer.scale > 1.2f) ? WAImageStackViewInteractionZoomInPossible : WAImageStackViewInteractionNormal;
		
			IRCATransact(^ {
			
				CATransform3D translationTransform = CATransform3DMakeTranslation(
					currentTouchPoint.x - startingTouchPoint.x, 
					currentTouchPoint.y - startingTouchPoint.y,
					0.0f
				);
				
				CATransform3D scaleTransform = CATransform3DMakeScale(
					self.pinchRecognizer.scale,
					self.pinchRecognizer.scale,
					1.0f
				);
				
				CATransform3D rotationTransform = CATransform3DMakeRotation(
					self.rotationRecognizer.rotation, 
					0.0f, 
					0.0f, 
					1.0f
				);
			
				self.firstPhotoView.layer.transform = CATransform3DConcat(CATransform3DConcat(CATransform3DConcat(canonicalTransform, scaleTransform), rotationTransform), translationTransform);
			});
		
			break;
		
		}
		
		case UIGestureRecognizerStateEnded:
		case UIGestureRecognizerStateCancelled:
		case UIGestureRecognizerStateFailed: {
		
			UIView *capturedFirstPhotoView = [[self.firstPhotoView retain] autorelease];
		
			self.state = (self.pinchRecognizer.scale > 1.2f) ? WAImageStackViewInteractionZoomInPossible : WAImageStackViewInteractionNormal;
			
			CGRect capturedRect = capturedFirstPhotoView.layer.bounds;
			capturedRect.origin = capturedFirstPhotoView.layer.position;
			capturedRect.origin.x -= 0.5f * CGRectGetWidth(capturedRect);
			capturedRect.origin.y -= 0.5f * CGRectGetHeight(capturedRect);
			
			CATransform3D oldTransform = ((CALayer *)[capturedFirstPhotoView.layer presentationLayer]).transform;
			CATransform3D newTransform = canonicalTransform;

			if (self.state == WAImageStackViewInteractionZoomInPossible) {
			
				dispatch_async(dispatch_get_main_queue(), ^ {
												
					[self.delegate imageStackView:self didRecognizePinchZoomGestureWithRepresentedImage:objc_getAssociatedObject(capturedFirstPhotoView, kWAImageStackViewElementImage) contentRect:capturedRect transform:oldTransform];
					
					capturedFirstPhotoView.layer.transform = newTransform;
				
				});

			} else {
							
				CABasicAnimation *transformAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
				transformAnimation.fromValue = [NSValue valueWithCATransform3D:oldTransform];
				transformAnimation.toValue = [NSValue valueWithCATransform3D:newTransform];
				transformAnimation.removedOnCompletion = YES;
				transformAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
				transformAnimation.duration = 0.3f;
			
				capturedFirstPhotoView.layer.transform = newTransform;
				[capturedFirstPhotoView.layer addAnimation:transformAnimation forKey:@"transition"];
			
			}
		
			self.gestureProcessingOngoing = NO;
			
			break;
		
		}
	
	}

}

- (void) handleRotation:(UIRotationGestureRecognizer *)aRotationRecognizer {

	//	We let this be an empty no-op and have the pinch recognizer do all the work instead.
	//	The rotation gesture recognizer is only wired up to provide adequate information.

}

- (void) handleTap:(UITapGestureRecognizer *)aTapRecognizer {

	if (self.gestureProcessingOngoing)
		return;
	
	UIView *capturedFirstPhotoView = [[self.firstPhotoView retain] autorelease];
	[self.delegate imageStackView:self didRecognizePinchZoomGestureWithRepresentedImage:objc_getAssociatedObject(capturedFirstPhotoView, kWAImageStackViewElementImage) contentRect:capturedFirstPhotoView.frame transform:capturedFirstPhotoView.layer.transform];

}

- (void) reset {

	self.gestureProcessingOngoing = NO;
	[self setNeedsLayout];

}

- (void) dealloc {

	[images release];
	[shownImages release];
	[pinchRecognizer release];
	[rotationRecognizer release];
	[tapRecognizer release];
	[activityIndicator release];
	
	[super dealloc];

}

@end

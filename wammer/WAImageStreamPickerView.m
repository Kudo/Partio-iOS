//
//  WAImageStreamPickerView.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/22/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WAImageStreamPickerView.h"
#import "WAImageView.h"

static int kWAImageStreamPickerComponent = 24;
static NSString * kWAImageStreamPickerComponentItem = @"WAImageStreamPickerComponentItem";
static NSString * kWAImageStreamPickerComponentIndex = @"WAImageStreamPickerComponentIndex";
static NSString * kWAImageStreamPickerComponentThumbnail = @"WAImageStreamPickerComponentThumbnail";

@interface WAImageStreamPickerView ()
@property (nonatomic, readwrite, retain) NSArray *items;
@property (nonatomic, readwrite, retain) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, readwrite, retain) UIPanGestureRecognizer *panRecognizer;

- (id) itemAtPoint:(CGPoint)aPoint;
@end

@implementation WAImageStreamPickerView
@synthesize items, edgeInsets, activeImageOverlay, delegate;
@synthesize viewForThumbnail;
@synthesize tapRecognizer, panRecognizer, selectedItemIndex;
@synthesize style, thumbnailSpacing, thumbnailAspectRatio;

- (id) init {

	self = [super initWithFrame:(CGRect){ CGPointZero, (CGSize){ 512, 44 } }];
	if (!self)
		return nil;
	
	self.edgeInsets = (UIEdgeInsets){ 12, 8, 12, 8 };
	
	self.viewForThumbnail = ^ (UIView *aView, UIImage *anImage) {
	
		UIImageView *returnedView = nil;
		if ([aView isKindOfClass:[UIImageView class]]) {
			returnedView = (UIImageView *)aView;
			returnedView.image = anImage;
		} else {			
			returnedView = [[UIImageView alloc] initWithImage:anImage];
			returnedView.contentMode = UIViewContentModeScaleAspectFill;
			returnedView.clipsToBounds = YES;
		}
		
		returnedView.layer.borderColor = [UIColor whiteColor].CGColor;
		returnedView.layer.borderWidth = 1.0f;
		returnedView.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1];
		
    return returnedView;
	
	};
	
	self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
	[self addGestureRecognizer:self.tapRecognizer];
	
	self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
	[self addGestureRecognizer:self.panRecognizer];
	
	self.selectedItemIndex = NSNotFound;
	
	self.thumbnailSpacing = 4.0f;
	self.thumbnailAspectRatio = 2.0f/3.0f;
	
	return self;

}

- (void) setActiveImageOverlay:(UIView *)newActiveImageOverlay {

	if (activeImageOverlay == newActiveImageOverlay)
		return;
	
	[activeImageOverlay removeFromSuperview];
	activeImageOverlay = newActiveImageOverlay;
	
	[self setNeedsLayout];

}

- (void) reloadData {

	NSUInteger numberOfItems = [self.delegate numberOfItemsInImageStreamPickerView:self];
	NSMutableArray *allItems = [NSMutableArray arrayWithCapacity:numberOfItems];
	
	for (NSUInteger i = 0; i < numberOfItems; i++)
		[allItems insertObject:[self.delegate itemAtIndex:i inImageStreamPickerView:self] atIndex:i];
	
	self.items = allItems;
	
	NSUInteger currentIndex = [self.delegate currentIndexForImageStreamPickerView];
	self.selectedItemIndex = currentIndex ? currentIndex : 0;
	
	[self setNeedsLayout];

}

- (void) setStyle:(WAImageStreamPickerViewStyle)newStyle {

	if (style == newStyle)
		return;
	
	style = newStyle;
	[self setNeedsLayout];

}

- (void) setThumbnailSpacing:(CGFloat)newThumbnailSpacing {

	if (thumbnailSpacing == newThumbnailSpacing)
		return;
	
	thumbnailSpacing = newThumbnailSpacing;
	[self setNeedsLayout];

}

- (void) setThumbnailAspectRatio:(CGFloat)newTumbnailAspectRatio {

	NSParameterAssert(newTumbnailAspectRatio > 0);
	if (thumbnailAspectRatio == newTumbnailAspectRatio)
		return;
	
	thumbnailAspectRatio = newTumbnailAspectRatio;
	[self setNeedsLayout];

}

- (void) layoutSubviews {

	[super layoutSubviews];
	
	CGRect usableRect = UIEdgeInsetsInsetRect(self.bounds, self.edgeInsets);
	CGFloat usableWidth = CGRectGetWidth(usableRect);
	CGFloat usableHeight = CGRectGetHeight(usableRect);
	NSUInteger numberOfItems = [self.delegate numberOfItemsInImageStreamPickerView:self];
	NSMutableIndexSet *thumbnailedItemIndices = [NSMutableIndexSet indexSet];
  
  if (numberOfItems > 0) {
    switch (self.style) {
      case WADynamicThumbnailsStyle: {
        [thumbnailedItemIndices addIndexesInRange:(NSRange){ 0, numberOfItems }];
        break;
      }
			
      case WAClippedThumbnailsStyle: {
        
				NSParameterAssert(self.thumbnailAspectRatio);
				
				NSUInteger numberOfThumbnails = (usableWidth + thumbnailSpacing) / ((usableHeight / self.thumbnailAspectRatio) + thumbnailSpacing);
				
				if (numberOfThumbnails < numberOfItems) {
					
					float_t delta = (float_t)numberOfItems / (float_t)numberOfThumbnails;
					
					for (float_t i = delta - 1; i < (numberOfItems - 1); i = i + delta){
						[thumbnailedItemIndices addIndex:roundf(i)];
					}
				
					if ([thumbnailedItemIndices count] < numberOfItems)
					if ([thumbnailedItemIndices firstIndex] != 0) {
						[thumbnailedItemIndices removeIndex:[thumbnailedItemIndices firstIndex]];
						[thumbnailedItemIndices addIndex:0];
					}

					if ([thumbnailedItemIndices count] < numberOfItems)
					if ([thumbnailedItemIndices lastIndex] != (numberOfItems - 1)) {
						[thumbnailedItemIndices removeIndex:[thumbnailedItemIndices lastIndex]];
						[thumbnailedItemIndices addIndex:(numberOfItems - 1)];
					}
				
				} else {
				
					[thumbnailedItemIndices addIndexesInRange:(NSRange){ 0, numberOfItems - 1 }];
				
				}
				
        break;
      }
    }
  }
	
	NSMutableArray *currentImageThumbnailViews = [[NSArray irArrayByRepeatingObject:[NSNull null] count:[self.items count]] mutableCopy];
	NSMutableSet *removedThumbnailViews = [NSMutableSet set];
	
	NSUInteger (^indexForComponent)(id) = ^ (id aComponent) {
		return [objc_getAssociatedObject(aComponent, &kWAImageStreamPickerComponentIndex) unsignedIntegerValue];
	};
	
	void (^setIndexForComponent)(id, NSUInteger) = ^ (id aComponent, NSUInteger anIndex) {
		objc_setAssociatedObject(aComponent, &kWAImageStreamPickerComponentIndex, [NSNumber numberWithUnsignedInteger:anIndex], OBJC_ASSOCIATION_RETAIN);
	};
	
	UIImage * (^thumbnailForComponent)(id) = ^ (id aComponent) {
		return objc_getAssociatedObject(aComponent, &kWAImageStreamPickerComponentThumbnail);
	};
	
	void (^setThumbnailForCompoment)(id, id) = ^ (id aComponent, UIImage *aThumbnail) {
		objc_setAssociatedObject(aComponent, &kWAImageStreamPickerComponentThumbnail, aThumbnail, OBJC_ASSOCIATION_RETAIN);
	};
	
	[[self.subviews copy] enumerateObjectsUsingBlock: ^ (UIView *aSubview, NSUInteger idx, BOOL *stop) {
		
		if (aSubview.tag != kWAImageStreamPickerComponent)
			return;
		
		[currentImageThumbnailViews replaceObjectAtIndex:indexForComponent(aSubview) withObject:aSubview];
		[removedThumbnailViews addObject:aSubview];
		
	}];
	
	[thumbnailedItemIndices enumerateIndexesUsingBlock: ^ (NSUInteger idx, BOOL *stop) {
	
		id item = [self.items objectAtIndex:idx];
		
		UIView *thumbnailView = (idx < [currentImageThumbnailViews count] - 1) ? [currentImageThumbnailViews objectAtIndex:idx] : nil;
		UIImage *thumbnailImage = [self.delegate thumbnailForItem:item inImageStreamPickerView:self];
		
		if ([thumbnailView isKindOfClass:[UIView class]]) {
			thumbnailView = self.viewForThumbnail(thumbnailView, thumbnailImage);
		} else {
			thumbnailView = self.viewForThumbnail(nil, thumbnailImage);
			[currentImageThumbnailViews replaceObjectAtIndex:idx withObject:thumbnailView];
		}
			
		thumbnailView.tag = kWAImageStreamPickerComponent;
		setIndexForComponent(thumbnailView, idx);
		setThumbnailForCompoment(thumbnailView, thumbnailImage);
		
	}];
	
	__block CGFloat exhaustedWidth = 0;
	
	CGSize (^sizeForComponent)(id) = ^ (id aComponent) {

		CGSize calculatedSize = CGSizeZero;

		switch (self.style) {
			case WADynamicThumbnailsStyle: {
				calculatedSize = thumbnailForComponent(aComponent).size;
				calculatedSize.width *= 16;
				calculatedSize.height *= 16;
				break;
			}
			case WAClippedThumbnailsStyle: {
				calculatedSize = (CGSize){
					usableHeight / self.thumbnailAspectRatio,
					usableHeight
				};
				break;
			}
		}
		
		CGRect thumbnailRect = CGRectIntegral(IRCGSizeGetCenteredInRect(calculatedSize, usableRect, 0.0f, YES));
		return thumbnailRect.size;
	
	};
	
	[thumbnailedItemIndices enumerateIndexesUsingBlock: ^ (NSUInteger idx, BOOL *stop) {
	
		UIView *thumbnailView = [currentImageThumbnailViews objectAtIndex:idx];
		NSParameterAssert(thumbnailView);
		
		CGSize thumbnailSize = sizeForComponent(thumbnailView);
		CGRect thumbnailRect = (CGRect){
			(CGPoint) {
				0,
				usableRect.origin.y + 0.5f * (CGRectGetHeight(usableRect) - thumbnailSize.height)
			},
			thumbnailSize
		};
		
		exhaustedWidth += CGRectGetWidth(thumbnailRect);
		
		thumbnailView.frame = thumbnailRect;
		[removedThumbnailViews removeObject:thumbnailView];
		
	}];
	
	__block CGFloat leftPadding = 0.5f * (usableWidth - exhaustedWidth);
	CGFloat const startLeftPadding = leftPadding;
	
  [thumbnailedItemIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
	
		UIView *thumbnailView = [currentImageThumbnailViews objectAtIndex:idx];
		NSParameterAssert(![removedThumbnailViews containsObject:thumbnailView]);
		
		thumbnailView.frame = CGRectOffset(thumbnailView.frame, leftPadding, 0);
		leftPadding += CGRectGetWidth(thumbnailView.frame);
		
		[self addSubview:thumbnailView];
		
	}];
	
	[removedThumbnailViews enumerateObjectsUsingBlock: ^ (UIView *removedThumbnailView, BOOL *stop) {
		
		[removedThumbnailView removeFromSuperview];
		
	}];
	
	
	if ((selectedItemIndex != NSNotFound) && ([self.items count] > selectedItemIndex)) {
	
		id item = [self.items objectAtIndex:selectedItemIndex];
		UIImage *thumbnailImage = [delegate thumbnailForItem:item inImageStreamPickerView:self];
	
		if (self.activeImageOverlay)
			self.activeImageOverlay = self.viewForThumbnail(self.activeImageOverlay, thumbnailImage);
		else
			self.activeImageOverlay = self.viewForThumbnail(nil, thumbnailImage);
		
		self.activeImageOverlay.frame = (CGRect){
			CGPointZero,
			sizeForComponent(self.activeImageOverlay)
		};
		
		NSUInteger numberOfItems = [thumbnailedItemIndices count];
		
		if (numberOfItems > 1) {
		
			self.activeImageOverlay.center = (CGPoint){

				0.5f * (usableWidth - exhaustedWidth)
					+ (leftPadding - startLeftPadding - sizeForComponent(self.activeImageOverlay).width) * ((float_t)selectedItemIndex / (float_t)([self.items count] - 1))
					+ (0.5f) * sizeForComponent(self.activeImageOverlay).width,

				CGRectGetMidY(usableRect)

			};
		
		} else {
		
			self.activeImageOverlay.center = (CGPoint){
				CGRectGetMidX(usableRect),
				CGRectGetMidY(usableRect)
			};
		
		}
    
    self.activeImageOverlay.frame = CGRectInset(self.activeImageOverlay.frame, -4, -4);
				
		if (self != self.activeImageOverlay.superview)
			[self addSubview:self.activeImageOverlay];
		
		[self.activeImageOverlay.superview bringSubviewToFront:self.activeImageOverlay];
	
	} else {
	
		[self.activeImageOverlay removeFromSuperview];
	
	}
			
}

- (void) handleTap:(UITapGestureRecognizer *)aTapRecognizer {

	id hitItem = [self itemAtPoint:[aTapRecognizer locationInView:self]];
	
	if (!hitItem)
		return;
	
	NSUInteger newItemIndex = [self.items indexOfObject:hitItem];
	
	if (self.selectedItemIndex == newItemIndex)
		return;
	
	self.selectedItemIndex = newItemIndex;
	[self.delegate imageStreamPickerView:self didSelectItem:hitItem];
	[self setNeedsLayout];

}

- (void) handlePan:(UIPanGestureRecognizer *)aPanRecognizer {

	if (aPanRecognizer.state != UIGestureRecognizerStateChanged)
		return;
		
	CGPoint hitPoint = [aPanRecognizer locationInView:self];
	hitPoint.y = CGRectGetMidY(self.bounds);

	id hitItem = [self itemAtPoint:hitPoint];
	
	if (!hitItem)
		return;

	NSUInteger newItemIndex = [self.items indexOfObject:hitItem];
	
	if (self.selectedItemIndex == newItemIndex)
		return;
	
	self.selectedItemIndex = newItemIndex;
	[self.delegate imageStreamPickerView:self didSelectItem:hitItem];
	[self setNeedsLayout];
	
}

- (id) itemAtPoint:(CGPoint)aPoint {

	CGRect shownFrame = CGRectNull;

	for (UIView *aView in self.subviews) {
		if (aView.tag == kWAImageStreamPickerComponent) {
			if (CGRectEqualToRect(CGRectNull, shownFrame)) {
				shownFrame = aView.frame;
			} else {
				shownFrame = CGRectUnion(shownFrame, aView.frame);
			}
		}
	}
	
	NSUInteger numberOfItems = [self.items count];
	if (!numberOfItems)
		return nil;

	float_t hitIndex = roundf(((aPoint.x - CGRectGetMinX(shownFrame)) / CGRectGetWidth(shownFrame)) * (numberOfItems - 1));
	hitIndex = MIN(numberOfItems - 1, MAX(0, hitIndex));
	
	if (numberOfItems > hitIndex)
		return [self.items objectAtIndex:hitIndex];
	
	return nil;

}

@end

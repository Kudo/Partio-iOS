//
//  WAPaginationSlider.h
//  wammer-iOS
//
//  Created by Evadne Wu on 7/21/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>


#ifndef __WAPaginationSlider__
#define __WAPaginationSlider__

enum WAPaginationSliderLayoutStrategy {
  
	WAPaginationSliderDefaultLayoutStrategy = 0,
	WAPaginationSliderFillWithDotsLayoutStrategy = 0,
	WAPaginationSliderLessDotsLayoutStrategy
	
}; typedef NSUInteger WAPaginationSliderLayoutStrategy;

#endif


@class WAPaginationSlider;

@protocol WAPaginationSliderDelegate <NSObject>

- (void) paginationSlider:(WAPaginationSlider *)slider didMoveToPage:(NSUInteger)destinationPage;

@end


@interface WAPaginationSlider : UIView

@property (nonatomic, readwrite, assign) CGFloat dotRadius;
@property (nonatomic, readwrite, assign) CGFloat dotMargin;
@property (nonatomic, readwrite, assign) UIEdgeInsets edgeInsets;

@property (nonatomic, readwrite, assign) NSUInteger numberOfPages;
@property (nonatomic, readwrite, assign) NSUInteger currentPage;
- (void) setCurrentPage:(NSUInteger)newPage animated:(BOOL)animate;

@property (nonatomic, readwrite, assign) BOOL snapsToPages;
@property (nonatomic, readwrite, assign) IBOutlet id<WAPaginationSliderDelegate> delegate;

- (void) sliderTouchDidStart:(UISlider *)aSlider;
- (void) sliderDidMove:(UISlider *)aSlider;
- (void) sliderTouchDidEnd:(UISlider *)aSlider;

@property (nonatomic, readwrite, assign) BOOL instantaneousCallbacks; //	If YES, sends -paginationSlider:didMoveToPage: continuously

@property (nonatomic, readonly, retain) UISlider *slider; //	Don’t do evil

@property (nonatomic, readwrite, assign) WAPaginationSliderLayoutStrategy layoutStrategy;
@end

//
//  WAArticleViewController.h
//  wammer-iOS
//
//  Created by Evadne Wu on 7/28/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <QuartzCore/QuartzCore.h>

#import "WAView.h"
#import "WAArticleTextEmphasisLabel.h"

#import "WAPreviewBadge.h"

#import "IRAlertView.h"
#import "IRActionSheetController.h"
#import "IRBarButtonItem.h"

#import "WAArticleView.h"


@class WAImageStackView;

@protocol WAArticleViewControllerPresenting
- (void) setContextControlsVisible:(BOOL)contextControlsVisible animated:(BOOL)animated;

@optional
- (void) enqueueInterfaceUpdate:(void(^)(void))anAction;

@end


#ifndef __WAArticleViewController__
#define __WAArticleViewController__

enum {

	WAUnknownArticleStyle = -1,

	WAFullFramePlaintextArticleStyle = 0,
	WAFullFrameImageStackArticleStyle,
	WAFullFramePreviewArticleStyle,
	WADiscretePlaintextArticleStyle,
	WADiscreteSingleImageArticleStyle,
	WADiscretePreviewArticleStyle
	
}; typedef NSInteger WAArticleViewControllerPresentationStyle;

extern NSString * NSStringFromWAArticleViewControllerPresentationStyle (WAArticleViewControllerPresentationStyle aStyle);
extern WAArticleViewControllerPresentationStyle WAArticleViewControllerPresentationStyleFromString (NSString *aString);

#endif

@interface WAArticleViewController : UIViewController

+ (WAArticleViewControllerPresentationStyle) suggestedStyleForArticle:(WAArticle *)anArticle;
+ (WAArticleViewController *) controllerForArticle:(NSURL *)articleObjectURL usingPresentationStyle:(WAArticleViewControllerPresentationStyle)aStyle;

@property (nonatomic, readonly, retain) NSURL *representedObjectURI;
@property (nonatomic, readonly, assign) WAArticleViewControllerPresentationStyle presentationStyle;
@property (nonatomic, readwrite, copy) void (^onViewDidLoad)(WAArticleViewController *self, UIView *loadedView);
@property (nonatomic, readwrite, copy) void (^onViewTap)();
@property (nonatomic, readwrite, copy) void (^onViewPinch)(UIGestureRecognizerState state, CGFloat scale, CGFloat velocity);
@property (nonatomic, readwrite, copy) void (^onPresentingViewController)(void(^action)(UIViewController <WAArticleViewControllerPresenting> *parentViewController));

@property (nonatomic, retain) WAArticleView *view;

@end

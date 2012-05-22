//
//  WAStackedArticleViewController.h
//  wammer
//
//  Created by Evadne Wu on 12/22/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAArticleViewController.h"
#import "IRStackView.h"

@class WAArticleTextStackCell, WAArticleTextStackElement, WAArticleTextEmphasisLabel, WAArticleCommentsViewController;

@interface WAStackedArticleViewController : WAArticleViewController <UITableViewDelegate, IRStackViewDelegate>

@property (nonatomic, readwrite, retain) IBOutlet IRStackView *stackView;
@property (nonatomic, readwrite, copy) void (^onViewDidLoad)(WAArticleViewController *self, UIView *ownView); 
@property (nonatomic, readwrite, copy) void (^onPullTop)(UIScrollView *pulledScrollView);

@property (nonatomic, readonly, retain) UIView *footerCell;
@property (nonatomic, readwrite, retain) UIView *headerView;


//	Exposed for subclasses only

@property (nonatomic, readonly, retain) WAArticleTextStackCell *topCell;
@property (nonatomic, readonly, retain) WAArticleTextStackElement *textStackCell;
@property (nonatomic, readonly, retain) WAArticleTextEmphasisLabel *textStackCellLabel;
@property (nonatomic, readonly, retain) WAArticleCommentsViewController *commentsVC;

- (WAArticleCommentsViewController *) newArticleCommentsController NS_RETURNS_RETAINED;
- (void) presentCommentsViewController:(WAArticleCommentsViewController *)controller sender:(id)sender;

- (UIView *) scrollableStackElementWrapper;
- (UIScrollView *) scrollableStackElement;

- (BOOL) enablesTextStackElementFolding;

@property (nonatomic, readonly, retain) NSArray *headerBarButtonItems;

- (void) handlePreferredInterfaceRect:(CGRect)aRect;
- (BOOL) isPointInsideInterfaceRect:(CGPoint)aPoint;

@end

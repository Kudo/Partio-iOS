//
//  WAStackedArticleViewController.h
//  wammer
//
//  Created by Evadne Wu on 12/22/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAArticleViewController.h"
#import "WAStackView.h"

@interface WAStackedArticleViewController : WAArticleViewController <UITableViewDelegate, WAStackViewDelegate>

@property (nonatomic, readwrite, retain) IBOutlet WAStackView *stackView;
@property (nonatomic, readwrite, copy) void (^onViewDidLoad)(WAArticleViewController *self, UIView *ownView); 
@property (nonatomic, readwrite, copy) void (^onPullTop)(UIScrollView *pulledScrollView);

@property (nonatomic, readonly, retain) UIView *footerCell;
@property (nonatomic, readwrite, retain) UIView *headerView;

@end

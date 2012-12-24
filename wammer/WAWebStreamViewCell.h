//
//  WAWebStreamViewCell.h
//  wammer
//
//  Created by Shen Steven on 12/17/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NINetworkImageView.h"
#import "WAFile.h"

extern NSString * kWAWebStreamViewCellKVOContext;

@interface WAWebStreamViewCell : UICollectionViewCell

@property (nonatomic, weak) IBOutlet UILabel *webTitleLabel;
@property (nonatomic, weak) IBOutlet UILabel *webURLLabel;
@property (nonatomic, weak) IBOutlet UILabel *dateTimeLabel;
@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet NINetworkImageView *faviconImageView;
@property (nonatomic, weak) IBOutlet UIImageView *sourceImageView;
@property (nonatomic, weak) IBOutlet UILabel *sourceLabel;

@property (nonatomic, strong) WAFile *file;

@end

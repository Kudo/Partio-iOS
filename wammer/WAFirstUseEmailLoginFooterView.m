//
//  WAFirstUseEmailLoginFooterView.m
//  wammer
//
//  Created by kchiu on 12/11/6.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAFirstUseEmailLoginFooterView.h"

@implementation WAFirstUseEmailLoginFooterView

+ (WAFirstUseEmailLoginFooterView *)viewFromNib {

	WAFirstUseEmailLoginFooterView *view = [[[UINib nibWithNibName:@"WAFirstUseEmailLoginFooterView" bundle:[NSBundle mainBundle]] instantiateWithOwner:nil options:nil] lastObject];

	return view;

}

- (void)awakeFromNib {

	[super awakeFromNib];

	self.emailLoginButton.backgroundColor = [UIColor grayColor];
	[self.emailLoginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.emailLoginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateDisabled];
	self.emailLoginButton.layer.cornerRadius = 18.0;

}

@end

//
//  WALocalizedCell.m
//  wammer
//
//  Created by kchiu on 12/11/7.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WALocalizedCell.h"

@implementation WALocalizedCell

- (void) awakeFromNib {
	
	[super awakeFromNib];
	
	self.textLabel.text = NSLocalizedString(self.textLabel.text, nil);
	self.detailTextLabel.text = NSLocalizedString(self.detailTextLabel.text, nil);
	
}

@end

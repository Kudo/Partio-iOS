//
//  WAArticleCommentsViewCell.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/12/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WAPostViewCellPhone.h"


@interface WAPostViewCellPhone ()
@property (nonatomic, readwrite, assign) WAPostViewCellStyle postViewCellStyle;
@property (nonatomic, readwrite, copy) NSString *reuseIdentifier;
@end


@implementation WAPostViewCellPhone
@synthesize commentLabel;
@synthesize commentBackground;
@synthesize postViewCellStyle;
@dynamic reuseIdentifier;
@synthesize imageStackView, avatarView, userNicknameLabel, contentTextLabel, dateOriginLabel, dateLabel, originLabel;

- (id) initWithStyle:(UITableViewCellStyle)aStyle reuseIdentifier:(NSString *)reuseIdentifier {

	return [self initWithPostViewCellStyle:WAPostViewCellStyleDefault reuseIdentifier:reuseIdentifier];

}

- (id) initWithPostViewCellStyle:(WAPostViewCellStyle)aStyle reuseIdentifier:(NSString *)aReuseIdentifier {

	NSString *loadedNibName = nil;
	
	switch (aStyle) {
		case WAPostViewCellStyleDefault:
		case WAPostViewCellStyleCompact: {
			loadedNibName = @"WAPostViewCellPhone-Default";
			break;
		}
    case WAPostViewCellStyleImageStack:
    case WAPostViewCellStyleCompactWithImageStack: {
			loadedNibName = @"WAPostViewCellPhone-ImageStack";
			break;
		}
	}

	self = [[[self class] cellFromNibNamed:loadedNibName instantiatingOwner:nil withOptions:nil] retain];
	
	if (!self)
		return nil;
	
	self.postViewCellStyle = aStyle;
	self.reuseIdentifier = aReuseIdentifier;
    
	self.backgroundView = [[[UIView alloc] initWithFrame:self.bounds] autorelease];
	self.backgroundView.backgroundColor = [UIColor colorWithWhite:0.95f alpha:1];

	self.selectedBackgroundView = [[[UIView alloc] initWithFrame:self.bounds] autorelease];
	self.selectedBackgroundView.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1];

	self.commentBackground.image = [self.commentBackground.image stretchableImageWithLeftCapWidth:24.0f topCapHeight:0];
	
  self.contentTextLabel.layer.borderColor = [UIColor redColor].CGColor;
  self.contentTextLabel.layer.borderWidth = 2.0;
  
  self.avatarView.layer.cornerRadius = 7.0;
	self.avatarView.layer.masksToBounds = YES;
    
	return self;
	
}

- (void) setCommentCount:(NSUInteger)commentCount {
  if (commentCount==0) {
    self.commentBackground.hidden = YES;
    self.commentLabel.hidden = YES;
  } else {
    self.commentBackground.hidden = NO;
    self.commentLabel.hidden = NO;
    self.commentLabel.text = [NSString stringWithFormat:@"%lu comments", commentCount];
  }
}

- (void) dealloc {

	[imageStackView release];
	[avatarView release];
	[userNicknameLabel release];
	[contentTextLabel release];
	[dateOriginLabel release];
	[dateLabel release];
	[originLabel release];	
	[commentLabel release];
	[commentBackground release];
	[super dealloc];
	
}

@end





@implementation WAPostViewCellPhone (NibLoading)

+ (WAPostViewCellPhone *) cellFromNib {

	return [self cellFromNibNamed:NSStringFromClass([self class]) instantiatingOwner:nil withOptions:nil];

}

+ (WAPostViewCellPhone *) cellFromNibNamed:(NSString *)nibName instantiatingOwner:(id)owner withOptions:(NSDictionary *)options {

	UINib *nib = [UINib nibWithNibName:nibName bundle:[NSBundle mainBundle]];
	NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];
	
	for (id loadedObject in loadedObjects)	
	if ([loadedObject isKindOfClass:[self class]])
		return loadedObject;
	
	return [[NSSet setWithArray:loadedObjects] anyObject];

}

@end

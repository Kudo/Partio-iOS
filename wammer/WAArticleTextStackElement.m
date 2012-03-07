//
//  WAArticleTextStackElement.m
//  wammer
//
//  Created by Evadne Wu on 3/2/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAArticleTextStackElement.h"
#import "WAArticleTextEmphasisLabel.h"
#import "WADefines.h"

#import "Foundation+IRAdditions.h"
#import "QuartzCore+IRAdditions.h"


@interface WAArticleTextStackElement ()

@property (nonatomic, readwrite, retain) WAArticleTextEmphasisLabel *textStackCellLabel;
@property (nonatomic, readwrite, retain) UIButton *contentToggle;

@end


@implementation WAArticleTextStackElement
@synthesize delegate;
@synthesize textStackCellLabel, contentToggle;

+ (id) cellFromNib {

  NSData *superData = [NSKeyedArchiver archivedDataWithRootObject:[super cellFromNib]];
  NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:superData] autorelease];
  [unarchiver setClass:[self class] forClassName:NSStringFromClass([self superclass])];

  return [unarchiver decodeObjectForKey:@"root"];

}

- (void) dealloc {

	[self irRemoveObserverBlocksForKeyPath:@"textStackCellLabel.label.lastDrawnRectRequiredTailTruncation"];

	[textStackCellLabel release];
	
	[super dealloc];

}

- (id) initWithCoder:(NSCoder *)aDecoder {

	self = [super initWithCoder:aDecoder];
	if (!self)
		return nil;

	self.backgroundView = WAStandardArticleStackCellCenterBackgroundView();

	WAArticleTextEmphasisLabel *cellLabel = self.textStackCellLabel;
	UIEdgeInsets cellLabelInsets = (UIEdgeInsets){ 0, 24, 0, 24 };
	cellLabel.frame = UIEdgeInsetsInsetRect(self.contentView.bounds, cellLabelInsets);
	cellLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	[self.contentView addSubview:cellLabel];
	
	self.onSizeThatFits = ^ (CGSize proposedSize, CGSize superAnswer) {
		
		CGSize labelAnswer = [cellLabel sizeThatFits:(CGSize){
			proposedSize.width - cellLabelInsets.left - cellLabelInsets.right,
			proposedSize.height - cellLabelInsets.top - cellLabelInsets.bottom,
		}];
		
		return (CGSize){
			ceilf(labelAnswer.width + cellLabelInsets.left + cellLabelInsets.right),
			MAX(32, ceilf(labelAnswer.height + cellLabelInsets.top + cellLabelInsets.bottom))
		};
		
	};
	
	[self setNeedsLayout];
	
	return self;

}

- (WAArticleTextEmphasisLabel *) textStackCellLabel {

	if (textStackCellLabel)
		return textStackCellLabel;
	
	textStackCellLabel = [[WAArticleTextEmphasisLabel alloc] initWithFrame:self.bounds];
	textStackCellLabel.backgroundColor = nil;
	textStackCellLabel.opaque = NO;
	textStackCellLabel.placeholder = @"This post has no body text";
	
	textStackCellLabel.label.trailingWhitespaceWidth = 64.0f;
		
	return textStackCellLabel;

}

@end

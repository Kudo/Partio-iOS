//
//  WAArticleAttachmentActivityView.m
//  wammer
//
//  Created by Evadne Wu on 2/21/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAArticleAttachmentActivityView.h"
#import "CGGeometry+IRAdditions.h"
#import "UIKit+IRAdditions.h"
#import "WADefines.h"

@interface WAArticleAttachmentActivityView ()

@property (nonatomic, readwrite, retain) UIButton *button;
@property (nonatomic, readwrite, retain) IRActivityIndicatorView *spinner;
- (void) updateAccordingToCurrentStyle;

@property (nonatomic, readwrite, retain) NSMutableDictionary *stylesToTitles;

@end

@implementation WAArticleAttachmentActivityView
@synthesize button, spinner, style, onTap, stylesToTitles;

- (id) initWithFrame:(CGRect)frame {

	NSParameterAssert([NSThread isMainThread]);

	self = [super initWithFrame:frame];
	if (!self)	
		return nil;
	
	button = [UIButton buttonWithType:UIButtonTypeCustom];
	[self addSubview:button];
	
	button.contentHorizontalAlignment = UIControlContentVerticalAlignmentCenter;
	button.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
	
	[button setTitleColor:[UIColor colorWithWhite:0 alpha:0.3] forState:UIControlStateNormal];
	[button setTitleColor:[UIColor colorWithWhite:0 alpha:0.7] forState:UIControlStateHighlighted];
	
	[button setContentEdgeInsets:(UIEdgeInsets){ 0, 16, 0, 16 }];
	[button setImageEdgeInsets:(UIEdgeInsets){ 0, -2, 0, 2 }];
	[button setTitleEdgeInsets:(UIEdgeInsets){ 0, 2, 0, -2 }];
	[button addTarget:self action:@selector(handleButtonTap:) forControlEvents:UIControlEventTouchUpInside];

	[button setBackgroundImage:[[UIImage imageNamed:@"WAFloatingButtonBackdrop"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 16, 0, 16)] forState:UIControlStateNormal];
	
	[button setBackgroundImage:[[UIImage imageNamed:@"WAFloatingButtonBackdropActive"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 16, 0, 16)] forState:UIControlStateHighlighted];
	
	spinner = [[IRActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	[self addSubview:spinner];
	
	style = WAArticleAttachmentActivityViewDefaultStyle;
	
	[self setNeedsLayout];
	[self updateAccordingToCurrentStyle];

	return self;
	
}

- (void) layoutSubviews {

	NSParameterAssert([NSThread isMainThread]);
	
	[super layoutSubviews];

	[button sizeToFit];

	button.frame =  IRGravitize(self.bounds, button.bounds.size, kCAGravityLeft);
	
	if (button.imageView)
		spinner.center = [spinner.superview convertPoint:button.imageView.center fromView:button.imageView.superview];
	else 
		spinner.center = irCGRectAnchor(self.bounds, irCenter, YES);

}

- (void) setStyle:(WAArticleAttachmentActivityViewStyle)newStyle {

	NSParameterAssert([NSThread isMainThread]);

	if (style == newStyle)
		return;
	
	[self willChangeValueForKey:@"style"];
	
	style = newStyle;
	
	[self updateAccordingToCurrentStyle];
	
	[self didChangeValueForKey:@"style"];

}

	
- (void) updateAccordingToCurrentStyle {

	NSParameterAssert([NSThread isMainThread]);

	BOOL const isBusy = (style == WAArticleAttachmentActivityViewSpinnerStyle);

	spinner.animating = isBusy;
	button.hidden = isBusy;
	
	[button setTitle:[self titleForStyle:style] forState:UIControlStateNormal];
	
	switch (style) {
	
		case WAArticleAttachmentActivityViewAttachmentsStyle: {
			[button setImage:[UIImage imageNamed:@"WAAttachmentGlyph"] forState:UIControlStateHighlighted];
			[button setImage:[UIImage imageNamed:@"WAAttachmentDisabledGlyph"] forState:UIControlStateNormal];
			break;
		}
		
		case WAArticleAttachmentActivityViewLinkStyle: {
			[button setImage:[UIImage imageNamed:@"WALinkGlyph"] forState:UIControlStateHighlighted];
			[button setImage:[UIImage imageNamed:@"WALinkDisabledGlyph"] forState:UIControlStateNormal];
			break;
		}
		
		default:
			break;
		
	};
		
}

- (IBAction) handleButtonTap:(id)sender {

	NSParameterAssert([NSThread isMainThread]);

	if (self.onTap)
		self.onTap();

}

- (NSMutableDictionary *) stylesToTitles {

	NSParameterAssert([NSThread isMainThread]);

	if (stylesToTitles)
		return stylesToTitles;
	
	stylesToTitles = [NSMutableDictionary dictionary];
	return stylesToTitles;

}

- (void) setTitle:(NSString *)title forStyle:(WAArticleAttachmentActivityViewStyle)aStyle {

	NSParameterAssert([NSThread isMainThread]);

	[self.stylesToTitles setObject:title forKey:[NSValue valueWithBytes:&aStyle objCType:@encode(__typeof__(aStyle))]];	
	[self updateAccordingToCurrentStyle];

}

- (NSString *) titleForStyle:(WAArticleAttachmentActivityViewStyle)aStyle {

	NSParameterAssert([NSThread isMainThread]);

	return [self.stylesToTitles objectForKey:[NSValue valueWithBytes:&aStyle objCType:@encode(__typeof__(aStyle))]];

}

- (CGSize) sizeThatFits:(CGSize)size {

	return [self.button sizeThatFits:size];

}

@end

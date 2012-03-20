//
//  WAArticleTextEmphasisLabel.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/16/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WAArticleTextEmphasisLabel.h"
#import "IRLabel.h"


@interface WAArticleTextEmphasisLabel () <UIWebViewDelegate>

@property (nonatomic, readwrite, retain) IBOutlet UITextView *textView;
@property (nonatomic, readwrite, retain) IBOutlet IRLabel *label;

- (void) waInitialize;

- (void) updateText;

@end


@implementation WAArticleTextEmphasisLabel
@synthesize textView, label, backgroundView, text, placeholder;

- (id) initWithFrame:(CGRect)aFrame {

	self = [super initWithFrame:aFrame];
	if (!self)
		return nil;
		
	[self waInitialize];
	
	return self;

}

- (void) awakeFromNib {

	[super awakeFromNib];
	
	[self waInitialize];

}

- (void) waInitialize {

#if 0
	
	self.layer.borderColor = [UIColor redColor].CGColor;
	self.layer.borderWidth = 1;
	
	self.label.layer.borderColor = [UIColor blueColor].CGColor;
	self.label.layer.borderWidth = 2;

#endif
	
	[self addSubview:self.label];
	
	[self updateText];
	
}

- (IRLabel *) label {

	if (label)
		return label;

	label = [[IRLabel alloc] initWithFrame:self.bounds];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	label.font = self.font;
	label.textColor = [UIColor colorWithWhite:0.1 alpha:1.0];
	label.numberOfLines = 0;
	label.lineBreakMode = UILineBreakModeTailTruncation;
	label.opaque = NO;
	label.backgroundColor = nil;
	label.userInteractionEnabled = YES;
	
	return label;

}

- (void) setBackgroundView:(UIView *)newBackgroundView {

	[backgroundView removeFromSuperview];
	backgroundView = newBackgroundView;
	
	[self insertSubview:newBackgroundView atIndex:0];
	backgroundView.frame = self.bounds;
	backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

}

- (void) setText:(NSString *)newText {

	if (text == newText)
		return;
	
	text = [newText copy];
	
	[self updateText];

}

- (void) setFont:(UIFont *)font {

	self.label.font = font;

}

- (UIFont *) font {

	return self.label.font;

}

+ (NSSet *) keyPathsForValuesAffectingFont {

	return [NSSet setWithObjects:
	
		@"label.font",
	
	nil];

}

- (void) setPlaceholder:(NSString *)newPlaceholder {

	if (placeholder == newPlaceholder)
		return;
	
	placeholder = [newPlaceholder copy];
	
	[self updateText];
	
}

- (void) updateText {

	BOOL usesPlaceholder = YES;

	IRLabel *capturedLabel = self.label;
	NSString *capturedText = self.text;
	
	NSAttributedString *attributedText = [capturedLabel attributedStringForString:capturedText];
	capturedLabel.attributedText = attributedText;
	
	if ([capturedText length])
		usesPlaceholder = NO;
	
	if (!usesPlaceholder) {
	
		dispatch_async(dispatch_get_global_queue(0, 0), ^ {
		
			static NSDataDetector *sharedDataDetector = nil;
			static dispatch_once_t onceToken;
			dispatch_once(&onceToken, ^{
				sharedDataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
			});
		
			__block BOOL hasLinks = NO;
			
			NSMutableAttributedString *linkedAttributedText = [attributedText mutableCopy];
			
			[linkedAttributedText beginEditing];
			
			NSString *matchedText = [capturedText copy];
			matchedText = [matchedText stringByReplacingOccurrencesOfString:@"\n" withString:@" "];  //  iOS 4.3 Crasher
			
			[sharedDataDetector enumerateMatchesInString:matchedText options:0 range:(NSRange){ 0, [matchedText length] } usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			
				hasLinks = YES;
			
				[linkedAttributedText addAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
					(id)[UIColor colorWithRed:0 green:0 blue:0.5 alpha:1].CGColor, kCTForegroundColorAttributeName,
					result.URL, kIRTextLinkAttribute,
				nil] range:result.range];
				
			}];
			
			[linkedAttributedText endEditing];
			
			if (!hasLinks)
				return;
			
			dispatch_async(dispatch_get_main_queue(), ^ {
			
				if ([capturedLabel.attributedText isEqualToAttributedString:attributedText])
					capturedLabel.attributedText = linkedAttributedText;
			
			});

		});
	
	}
	
	if (usesPlaceholder && self.placeholder) {
		
		self.label.attributedText = [self.label attributedStringForString:self.placeholder font:self.font color:[UIColor colorWithWhite:0.5 alpha:1]];
	
	}
	
}

- (CGSize) sizeThatFits:(CGSize)size {

	return [self.label sizeThatFits:size];

}

@end

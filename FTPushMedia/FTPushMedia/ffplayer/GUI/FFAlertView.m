//
//  FFAlertView.m
//  FFPlayer
//
//  Created by Coremail on 14-1-13.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import "FFAlertView.h"

@implementation FFAlertView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void) dealloc
{
    _block = nil;
    _block2 = nil;
}

+ (id)showWithTitle:(NSString *)title
            message:(NSString *)message
        defaultText:(NSString *)defaultText
              style:(UIAlertViewStyle)style
         usingBlock:(void (^)(NSUInteger btn, NSString * s1))block
  cancelButtonTitle:(NSString *)cancelButtonTitle
  otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION
{
    FFAlertView * alert = [[FFAlertView alloc] initWithTitle:title
                                                    message:message
                                                    delegate:nil
                                                    cancelButtonTitle:cancelButtonTitle
                                                    otherButtonTitles:nil];
    
    alert.alertViewStyle = style;
    alert.delegate = alert;
    alert->_block = [block copy];
    
    va_list args;
    va_start(args, otherButtonTitles);
    for (NSString *buttonTitle = otherButtonTitles; buttonTitle != nil; buttonTitle = va_arg(args, NSString*))
    {
        [alert addButtonWithTitle:buttonTitle];
    }
    va_end(args);
    
    if ( defaultText != nil )
    {
        UITextField* textField = [alert textFieldAtIndex:0];
        textField.text = defaultText;
    }
    [alert show];
    
    return alert;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (_block)
    {
        NSString * strText = nil;
        if ( alertView.alertViewStyle != UIAlertViewStyleDefault) {
            UITextField *tf=[alertView textFieldAtIndex:0];
            strText = tf.text;
        }
        _block( buttonIndex, strText );
    }
    if ( _block2 )
    {
        NSString * strText = nil;
        NSString * strText2 = nil;
        if ( alertView.alertViewStyle == UIAlertViewStyleLoginAndPasswordInput) {
            strText =[alertView textFieldAtIndex:0].text;
            strText2 =[alertView textFieldAtIndex:1].text;
        }
        _block2( buttonIndex, strText, strText2 );
    }
}

+(void) inputPassword2_imp:(NSString *)title
               message:(NSString *)message
              message2:(NSString *)message2
            usingBlock:(void (^)(BOOL notTheSame,NSString * pass)) finalBlock
     cancelButtonTitle:(NSString *)cancelButtonTitle
        okButtonTitles:(NSString *)okButtonTitles
          lastPassword:(NSString *)lastPassword
{
    [FFAlertView showWithTitle: title
                       message: lastPassword == nil ? message : message2
                   defaultText:@""
                         style:UIAlertViewStyleSecureTextInput
                    usingBlock:^(NSUInteger btn, NSString * pass) {
                        if ( btn == 0 )
                            return;
                        else if (lastPassword == nil ) {
                            if ( !pass )
                                return;
                            return [FFAlertView inputPassword2_imp:title message:message message2:message2 usingBlock:finalBlock cancelButtonTitle:cancelButtonTitle okButtonTitles:okButtonTitles lastPassword:pass];
                        } else if ( ![lastPassword isEqualToString:pass] ) {
                            finalBlock(YES, nil);
                        } else {
                            finalBlock(NO,pass);
                        }
                    }
             cancelButtonTitle:cancelButtonTitle
             otherButtonTitles:okButtonTitles, nil
     ];
}

+(void) inputPassword2:(NSString *)title
               message:(NSString *)message
              message2:(NSString *)message2
          usingBlock:(void (^)(BOOL notTheSame,NSString * pass)) finalBlock
     cancelButtonTitle:(NSString *)cancelButtonTitle
        okButtonTitles:(NSString *)okButtonTitles
{
    [FFAlertView inputPassword2_imp:title
                            message:message
                           message2:message2
                         usingBlock:finalBlock
                  cancelButtonTitle:cancelButtonTitle
                     okButtonTitles:okButtonTitles
                       lastPassword:nil];
}


+(void) inputUserAndPassword:(NSString *)title
                     message:(NSString *)message
                  usingBlock:(void (^)(NSUInteger btn, NSString * s1, NSString * s2)) block
           cancelButtonTitle:(NSString *)cancelButtonTitle
              okButtonTitles:(NSString *)okButtonTitles
{
    FFAlertView * alert = [[FFAlertView alloc] initWithTitle:title
                                                     message:message
                                                    delegate:nil
                                           cancelButtonTitle:cancelButtonTitle
                                           otherButtonTitles:nil];
    
    alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    alert.delegate = alert;
    alert->_block2 = [block copy];
    [alert addButtonWithTitle:okButtonTitles];
    [alert show];
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end

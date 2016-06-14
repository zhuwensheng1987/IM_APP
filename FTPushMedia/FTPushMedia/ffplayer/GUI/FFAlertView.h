//
//  FFAlertView.h
//  FFPlayer
//
//  Created by Coremail on 14-1-13.
//  Copyright (c) 2014年 Coremail. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^InputBlock)(NSUInteger btn, NSString *);
typedef void (^InputBlock2)(NSUInteger btn, NSString *, NSString *);

@interface FFAlertView : UIAlertView <UIAlertViewDelegate>
{
    InputBlock _block;
    InputBlock2 _block2;
}

+(id) showWithTitle:(NSString *) title
            message:(NSString *)message
        defaultText:(NSString *)defaultText
              style:(UIAlertViewStyle)style
         usingBlock:(void (^)(NSUInteger btn, NSString *))block
  cancelButtonTitle:(NSString *)cancelButtonTitle
  otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

+(void) inputPassword2:(NSString *)title
             message:(NSString *)message
            message2:(NSString *)message2
          usingBlock:(void (^)(BOOL notTheSame,NSString * pass)) finalBlock
   cancelButtonTitle:(NSString *)cancelButtonTitle
      okButtonTitles:(NSString *)okButtonTitles;

+(void) inputUserAndPassword:(NSString *)title
                     message:(NSString *)message
                  usingBlock:(void (^)(NSUInteger btn, NSString * s1, NSString * s2)) block
           cancelButtonTitle:(NSString *)cancelButtonTitle
              okButtonTitles:(NSString *)okButtonTitles;

@end

#pragma once

#if !(@{Fuse.Controls.Native.iOS.GraphicsView:isStripped} && @{Fuse.Controls.Native.iOS.FocusHelpers:isStripped} && @{Fuse.Controls.Native.iOS.InputDispatch:isStripped} && @{Fuse.Controls.Native.iOS.KeyboardView:isStripped} && @{Fuse.Controls.Native.iOS.ScrollView:isStripped} && @{Fuse.Controls.Native.iOS.SingleLineTextEdit:isStripped} && @{Fuse.Controls.Native.iOS.MultiLineTextEdit:isStripped} && @{Fuse.Controls.Native.iOS.UIControlEvent:isStripped})

#include <uno.h>
#include <UIKit/UIKit.h>
#if @(METAL:defined)
#include <MetalANGLE/MGLKit.h>
#else
#include <GLKit/GLKit.h>
#include <OpenGLES/EAGL.h>
#endif


@interface ShapeView : UIControl
-(UIControl*)childrenView;
-(UIControl*)shapeView;
@end

@interface KeyboardView : UIControl<UIKeyInput>

@property(nonatomic) bool isFocusable;
@property(nonatomic) UIReturnKeyType returnKeyType;
@property(nonatomic) UIKeyboardType keyboardType;

@end

@interface SizeControl : UIControl

@property (copy) void (^onSetFrameCallback)(id);

@end

@interface UIResponder (FirstResponder)

+(id)currentFirstResponder;
-(void)findFirstResponder:(id)sender;

@end

@interface TextFieldDelegate : NSObject<UITextFieldDelegate>

@property (copy) bool (^onActionCallback)(id);
- (BOOL)textFieldShouldReturn:(UITextField *)textField;

@property int maxLength;
- (BOOL)textField:(UITextField *)textField
	shouldChangeCharactersInRange:(NSRange)range
	replacementString:(NSString *)string;

@property (copy) bool (^shouldEditingCallback)(id);
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField;

@end

@interface TextViewDelegate : NSObject<UITextViewDelegate>

@property (copy) void (^textChangedCallback)(id);
@property (copy) void (^didBeginEditingCallback)();
- (void)textViewDidBeginEditing:(UITextView *)textView;
- (void)textViewDidChange:(UITextView *)textView;
- (void)textViewDidEndEditing:(UITextView *)textView;

@property int maxLength;
- (BOOL)textView:(UITextView *)textView
	shouldChangeTextInRange:(NSRange)range
	replacementText:(NSString *)text;

@end

@interface ScrollViewDelegate : NSObject<UIScrollViewDelegate>

@property (copy) void (^didScrollCallback)(id);
@property (copy) void (^didInteractinglCallback)(BOOL);
@property (copy) void (^willEndDraggingCallback)(id, CGPoint, void*);

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint) velocity targetContentOffset:(CGPoint *) targetContentOffset;

@end

@interface UIControlEventHandler : NSObject { }
- (void)action:(id)sender forEvent:(UIEvent *)event;
@property (copy) void (^callback)(id, id);
@end

#endif // IsStripped

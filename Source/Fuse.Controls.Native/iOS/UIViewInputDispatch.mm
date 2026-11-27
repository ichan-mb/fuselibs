#include "UIViewInputDispatch.h"

#include <objc/runtime.h>

void touchesBegan(id self, SEL _cmd, id touches, id uiEvent);
void touchesMoved(id self, SEL _cmd, id touches, id uiEvent);
void touchesEnded(id self, SEL _cmd, id touches, id uiEvent);
void touchesCancelled(id self, SEL _cmd, id touches, id uiEvent);
UIView* hitTest(id self, SEL _cmd, CGPoint point, UIEvent* uiEvent);

void installMethods(UIView* view);

const void* InputHandlerKey = &InputHandlerKey;
const void* VisualKey = &VisualKey;
const void* PassThroughKey = &PassThroughKey;

void addInputHandler(UIView* view, InputHandler inputHandler, id visual)
{
	installMethods(view);
	objc_setAssociatedObject(view, InputHandlerKey, inputHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
	objc_setAssociatedObject(view, VisualKey, visual, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

void removeInputHandler(UIView* view)
{
	objc_setAssociatedObject(view, InputHandlerKey, NULL, OBJC_ASSOCIATION_COPY_NONATOMIC);
	objc_setAssociatedObject(view, VisualKey, NULL, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

void setHitTestPassThrough(UIView* view, bool passThrough)
{
	objc_setAssociatedObject(view, PassThroughKey, passThrough ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

const char* SubclassPrefix = "__FUSE_INPUTHANDLER__";

void installMethods(UIView* view)
{
	Class baseClass = [view class];

	NSString* baseClassName = NSStringFromClass(baseClass);
	NSString* subclassPrefix = [NSString stringWithUTF8String: SubclassPrefix];

	if ([baseClassName hasPrefix:subclassPrefix])
		return;

	NSString* subClassName = [NSString stringWithFormat:@"%@%@", subclassPrefix, baseClassName];

	Class subClass = NSClassFromString(subClassName);
	if (subClass == NULL)
	{
		subClass = objc_allocateClassPair(baseClass, [subClassName UTF8String], 0);
		if (subClass == NULL)
		{
			NSLog(@"Failed to allocate subclass - %@", subClassName);
			return;
		}

		class_addMethod(subClass, @selector(touchesBegan:withEvent:), (IMP)touchesBegan, "v@:@@");
		class_addMethod(subClass, @selector(touchesMoved:withEvent:), (IMP)touchesMoved, "v@:@@");
		class_addMethod(subClass, @selector(touchesEnded:withEvent:), (IMP)touchesEnded, "v@:@@");
		class_addMethod(subClass, @selector(touchesCancelled:withEvent:), (IMP)touchesCancelled, "v@:@@");
		Method baseHitTest = class_getInstanceMethod(baseClass, @selector(hitTest:withEvent:));
		class_addMethod(subClass, @selector(hitTest:withEvent:), (IMP)hitTest, method_getTypeEncoding(baseHitTest));
		objc_registerClassPair(subClass);
	}
	object_setClass(view, subClass);
}

void invokeOnSuperClass(id self, SEL _cmd, id touches, id uiEvent)
{
	typedef void(*BaseMethod)(id,SEL,id,id);

	Class superClass = class_getSuperclass([self class]);
	BaseMethod base = (BaseMethod)[superClass instanceMethodForSelector: _cmd];
	if (base == NULL)
	{
		NSLog(@"Not instance method present on superclass - %@", NSStringFromClass(superClass));
		return;
	}
	base(self, _cmd, touches, uiEvent);
}

void dispatchEvent(int eventType, id self, id touches)
{
	InputHandler inputHandler = objc_getAssociatedObject(self, InputHandlerKey);
	if (inputHandler != NULL)
		inputHandler(eventType, objc_getAssociatedObject(self, VisualKey), [touches allObjects]);
}

void touchesBegan(id self, SEL _cmd, id touches, id uiEvent)
{
	dispatchEvent(EVENTTYPE_PRESSED, self, touches);
	invokeOnSuperClass(self, _cmd, touches, uiEvent);
}

void touchesMoved(id self, SEL _cmd, id touches, id uiEvent)
{
	dispatchEvent(EVENTTYPE_MOVED, self, touches);
	invokeOnSuperClass(self, _cmd, touches, uiEvent);
}

void touchesEnded(id self, SEL _cmd, id touches, id uiEvent)
{
	dispatchEvent(EVENTTYPE_RELEASED, self, touches);
	invokeOnSuperClass(self, _cmd, touches, uiEvent);
}

void touchesCancelled(id self, SEL _cmd, id touches, id uiEvent)
{
	dispatchEvent(EVENTTYPE_CANCELLED, self, touches);
	invokeOnSuperClass(self, _cmd, touches, uiEvent);
}

// UIKit gives a touch to the deepest view under it. A view that passes touches through is
// left out when the touch is not on one of its subviews, so the touch can reach the views
// behind it, e.g. a ScrollView below an empty Panel.
UIView* hitTest(id self, SEL _cmd, CGPoint point, UIEvent* uiEvent)
{
	typedef UIView*(*BaseMethod)(id,SEL,CGPoint,UIEvent*);

	Class superClass = class_getSuperclass([self class]);
	BaseMethod base = (BaseMethod)[superClass instanceMethodForSelector: _cmd];
	UIView* hit = base(self, _cmd, point, uiEvent);

	if (hit == self && objc_getAssociatedObject(self, PassThroughKey) != nil)
		return nil;
	return hit;
}

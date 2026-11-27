#import <UIKit/UIKit.h>

const int EVENTTYPE_PRESSED = 0;
const int EVENTTYPE_MOVED = 1;
const int EVENTTYPE_RELEASED = 2;
const int EVENTTYPE_CANCELLED = 3;

typedef void(^InputHandler)(int,id,id);

void addInputHandler(UIView* view, InputHandler inputHandler, id visual);
void removeInputHandler(UIView* view);

// Whether the view lets touches that do not land on one of its subviews go to the views
// behind it, as an element that draws nothing does in Fuse's own hit testing.
void setHitTestPassThrough(UIView* view, bool passThrough);
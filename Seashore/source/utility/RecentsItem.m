#import "SeaController.h"
#import "RecentsUtility.h"
#import "SeaTexture.h"
#import "RecentsItem.h"

#define kImageSize 48

#define FG_RECT NSRect fg = NSMakeRect(0,0,10,8);

@protocol Memory
-(NSString*)memoryAsString;
-(void)drawAt:(NSRect)rect;
-(NSColor*)foreground;
-(NSColor*)background;
-(SeaTexture*)texture;
-(void)restore;
@end

@interface RecentsView : NSView
{
    @public id<Memory> memory;
    @public bool selected;
}
@end
@implementation RecentsView

-(void)drawRect:(NSRect)dirtyRect
{
    [NSBezierPath setDefaultLineWidth:1];

    NSRect rect =NSMakeRect(0,0,kImageSize,kImageSize);

    if(selected) {
        [[NSColor selectedControlColor] set];
        [NSBezierPath strokeRect:[self bounds]];
    } else {
        [[[NSColor gridColor] colorWithAlphaComponent:.4] set];
        [NSBezierPath strokeRect:[self bounds]];
    }

    [NSBezierPath setDefaultLineWidth:1];
    [memory drawAt:rect];

    NSAffineTransform *at = [NSAffineTransform transform];
    [at translateXBy:kImageSize-4 yBy:kPreviewHeight/2+4];
    [at concat];
    
    [self drawColorRect];
}
-(BOOL)isFlipped
{
    return YES;
}

- (void)drawColorRect
{
    FG_RECT
    
    NSRect bg = NSMakeRect(fg.origin.x+(int)(fg.size.width*.75),fg.origin.x+(int)(fg.size.height*.75),fg.size.width,fg.size.height);
    
    BOOL foregroundIsTexture = [memory texture]!=NULL;
    
    [self drawColorWell:bg];
    
    // Actual Color
    [[memory background] set];
    [[NSBezierPath bezierPathWithRect:bg] fill];
    
    [self drawColorWell:fg];
    
    if (foregroundIsTexture) {
        [[NSColor colorWithPatternImage:[[memory texture] image]] set];
        [[NSBezierPath bezierPathWithRect:fg] fill];
    }
    else {
        [[memory foreground] set];
        [[NSBezierPath bezierPathWithRect:fg] fill];
    }
}

- (void)drawColorWell:(NSRect)rect
{
    [[NSColor darkGrayColor] set];
    [[NSBezierPath bezierPathWithRect:NSInsetRect(rect,-2,-2)] fill];
    [[NSColor lightGrayColor] set];
    [[NSBezierPath bezierPathWithRect:NSInsetRect(rect,-1,-1)] fill];
    
    // draw the triangles
    [[NSColor blackColor] set];
    NSBezierPath *tempPath = [NSBezierPath bezierPath];
    [tempPath moveToPoint:rect.origin];
    [tempPath lineToPoint:NSMakePoint(NSMaxX(rect),rect.origin.y)];
    [tempPath lineToPoint:NSMakePoint(rect.origin.x,NSMaxY(rect))];
    [tempPath lineToPoint:rect.origin];
    [tempPath fill];
    // Black
    [[NSColor whiteColor] set];
    tempPath = [NSBezierPath bezierPath];
    [tempPath moveToPoint:NSMakePoint(rect.origin.x,NSMaxY(rect))];
    [tempPath lineToPoint:NSMakePoint(NSMaxX(rect),NSMaxY(rect))];
    [tempPath lineToPoint:NSMakePoint(NSMaxX(rect),rect.origin.y)];
    [tempPath lineToPoint:NSMakePoint(rect.origin.x,NSMaxY(rect))];
    [tempPath fill];
}

@end

@implementation RecentsItem
- (void)loadView {
    [self setView:[RecentsView new]];
}
- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    if (representedObject==NULL)
        return;
    
    RecentsView *view = (RecentsView*)[self view];
    view->memory = representedObject;
}
- (void)setSelected:(BOOL)selected
{
    RecentsView *view = (RecentsView*)[self view];
    view->selected = selected;
    [view setNeedsDisplay:YES];
    
    if(selected) {
        id<Memory> memory = [self representedObject];
        [memory restore];
    }
    
    [super setSelected:selected];
}
@end

#import "LayersUtility.h"
#import "SeaLayer.h"
#import "SeaContent.h"
#import "SeaDocument.h"
#import "SeaWhiteboard.h"
#import "LayerSettings.h"
#import "SeaHelpers.h"
#import "SeaController.h"
#import "SeaPrefs.h"
#import "SeaProxy.h"
#import "SeaWindowContent.h"

@implementation LayersUtility

- (id)init
{
	return self;
}

- (void)awakeFromNib
{
	// Enable the utility
	enabled = YES;
}

- (void)update:(LayersUtilityUpdateEnum)updateCode
{
	id layer = [[document contents] activeLayer];
	
	switch (updateCode) {
		case kLayersUpdateAll:
			if (document && layer && enabled) {
				// Enable the layer buttons
				[newButton setEnabled:YES];
				[duplicateButton setEnabled:YES];
				[upButton setEnabled:YES];
				[downButton setEnabled:YES];
				[deleteButton setEnabled:YES];
			}
			else {
				// Disable the layer buttons
				[newButton setEnabled:NO];
				[duplicateButton setEnabled:NO];
				[upButton setEnabled:NO];
				[downButton setEnabled:NO];
				[deleteButton setEnabled:NO];
			}
		break;
	}
	[dataSource update];
}

- (id)layerSettings
{
	return layerSettings;
}

- (IBAction)show:(id)sender
{
	[[[document window] contentView] setVisibility: YES forRegion: kLayersPanel];
}

- (IBAction)hide:(id)sender
{
	[[[document window] contentView] setVisibility: NO forRegion: kLayersPanel];
}

- (void)setEnabled:(BOOL)value
{
	enabled = value;
	[self update:kLayersUpdateAll];
}

- (IBAction)toggleLayers:(id)sender
{
	if ([self visible])
		[self hide:sender];
	else
		[self show:sender];
}

- (BOOL)validateMenuItem:(id)menuItem
{
	id layer = [[document contents] activeLayer];
	
	// Switch to the appropriate code block given menu item
	switch ([menuItem tag]) {
		case 1002:
			if (![layer hasAlpha])
				return NO;
		break;
	}
	
	return YES;
}

- (BOOL)visible
{
	return [[[document window] contentView] visibilityForRegion: kLayersPanel];
}

- (IBAction)addLayer:(id)sender
{
	[[document contents] addLayer:kActiveLayer];
}

- (IBAction)duplicateLayer:(id)sender
{
    [[document contents] duplicateLayer:kActiveLayer];
}

- (IBAction)toggleAllVisibility:(id)sender {
    int layerCount = [[document contents] layerCount];
    if(layerCount==1) {
        return;
    }
    // if any layers are visible other than the clicked, make them invisible
    // else make them all visible
    int clicked = [sender clickedRow];
    bool anyVisible=FALSE;
    for(int i=0;i<layerCount;i++) {
        if(i==clicked) {
            continue;
        }
        SeaLayer *layer = [[document contents] layer:i];
        if([layer visible]) {
            anyVisible=TRUE;
            break;
        }
    }
    for(int i=0;i<layerCount;i++) {
        SeaLayer *layer = [[document contents] layer:i];
        if(i==clicked) {
            [layer setVisible:TRUE];
            continue;
        }
        [layer setVisible:!anyVisible];
    }
    [[document docView] setNeedsDisplay:TRUE];
    [sender setNeedsDisplay:TRUE];
}

- (IBAction)deleteLayer:(id)sender
{
	if ([[document contents] layerCount] > 1){
		[[document contents] deleteLayer:kActiveLayer];
	}else{
		NSBeep();
	}
}

@end

#include "Bucket.h"
#include "StandardMerge.h"
#include "DebugView.h"

#define kStackSizeIncrement 8192

#define TILE_SIZE 32

extern dispatch_queue_t queue;
extern dispatch_group_t group;

inline BOOL shouldFill(unsigned char *overlay, unsigned char *data, IntPoint seeds[], int numSeeds, IntPoint point, int width, int spp, int tolerance, int channel)
{
	int seedIndex;
	
	for(seedIndex = 0; seedIndex < numSeeds; seedIndex++){
		
		IntPoint seed = seeds[seedIndex];
		BOOL outsideTolerance = NO;
		int k, temp;
		
		int offset = (width * point.y + point.x)*spp;
        int offset0 = (width *seed.y + seed.x)*spp;
		
		if (overlay[offset + spp - 1] > 0){
			outsideTolerance = YES;
			continue;
		}
		
		if (channel == kAllChannels) {
			
			for (k = spp - 1; k >= 0; k--) {
				temp = abs((int)data[offset + k] - (int)data[offset0 + k]);
				if (temp > tolerance){
					outsideTolerance = YES;
					break;
				}
				if (k == spp - 1 && data[offset + k] == 0)
					return YES;
			}
		
		} else if (channel == kPrimaryChannels) {
		
			for (k = 0; k < spp - 1; k++) {
				temp = abs((int)data[offset + k] - (int)data[offset0 + k]);
				if (temp > tolerance){
					outsideTolerance = YES;
					break;
				}
			}
		
		} else if (channel == kAlphaChannel) {
		
			temp = abs((int)data[offset +spp - 1] - (int)data[offset0+spp-1]);
			if (temp > tolerance){
				outsideTolerance = YES;
			}
		
		}
		
		if(!outsideTolerance){
			return YES;
		}
	}
	
	return NO;
}

IntRect bucketFill(int spp, IntRect rect, unsigned char *overlay, unsigned char *data, int width, int height, IntPoint seeds[], int numSeeds, unsigned char *fillColor, int tolerance, int channel)
{
	int seedIndex;
	// We know at the very least that this point is in the rect
	IntRect result = IntMakeRect(seeds[0].x, seeds[0].y, 1, 1);

	for(seedIndex = 0; seedIndex < numSeeds; seedIndex++){
		IntPoint point, newPoint, seed = seeds[seedIndex];
		IntPoint *stack;
		int stackSize, stackPos, k;
		int minLeft = seed.x, maxRight = seed.x, minTop = seed.y, maxBottom = seed.y;
		int i, j;
		unsigned char firstPixel[4];
		int origTolerance = tolerance;

		// If the overlay alread contains this point, then our work is already done
		BOOL visited = YES;
		for (k = 0; k < spp; k++){
			// Compare to see if the fill exists at this point in the overlay
			if(overlay[(seed.y * width + seed.x) * spp + k] != fillColor[k]){
				visited = NO;
			}
		}
		if(visited){
			// We have in fact already filled this point so there's no reason 
			// to do another bucket fill from this point
			continue;
		}

		if (!IntContainsRect(IntMakeRect(0, 0, width, height), rect)) NSLog(@"Bad rectangle passed to textureFill()");
		if (fillColor[spp - 1] == 0) return IntMakeRect(0, 0, 0, 0);
		
		if (tolerance > 0 && tolerance < 255) {
			tolerance = 255;
			memcpy(firstPixel, data, spp);
			for (j = rect.origin.y; j < rect.origin.y + rect.size.height && tolerance != origTolerance; j++) {
				for	(i = rect.origin.x; i < rect.origin.x + rect.size.width; i++) {
					if (memcmp(firstPixel, &data[(j * width + i) * spp], spp) != 0) {
						tolerance = origTolerance;
						break;
					}
				}
			}
		}
		
		if (tolerance < 0) {
			result = IntMakeRect(0, 0, 0, 0);
		}
		else if (tolerance >= 255) {
			for (j = rect.origin.y; j < rect.origin.y + rect.size.height; j++) {
				for	(i = rect.origin.x; i < rect.origin.x + rect.size.width; i++) {
					memcpy(&(overlay[(j * width + i) * spp]), fillColor, spp);
				}
			}
			
			result = rect;
		}
		else {
			stack = malloc(sizeof(IntPoint) * kStackSizeIncrement);
			stackSize = kStackSizeIncrement;
			stackPos = 0;
			point = seed;
			do {
				
				if (stackPos == stackSize) {
					stackSize += kStackSizeIncrement;
					stack = realloc(stack, sizeof(IntPoint) * stackSize);
				}
				
				if (overlay[(point.y * width + point.x) * spp + spp - 1] == 0)  {
					for (k = 0; k < spp; k++)
						overlay[(point.y * width + point.x) * spp + k] = fillColor[k];
				}
				
				newPoint = point;
				newPoint.y++;
				if (IntPointInRect(newPoint, rect) && shouldFill(overlay, data, seeds, numSeeds, newPoint, width, spp, tolerance, channel)) {
					stack[stackPos] = point;
					stackPos++;
					point = newPoint;
					if (point.y > maxBottom) maxBottom = point.y;
				}
				else {
				
					newPoint = point;
					newPoint.y--;
					if (IntPointInRect(newPoint, rect) && shouldFill(overlay, data, seeds, numSeeds, newPoint, width, spp, tolerance, channel)) {
						stack[stackPos] = point;
						stackPos++;
						point = newPoint;
						if (point.y < minTop) minTop = point.y;
					}
					else {
					
						newPoint = point;
						newPoint.x++;
						if (IntPointInRect(newPoint, rect) && shouldFill(overlay, data, seeds, numSeeds, newPoint, width, spp, tolerance, channel)) {
							stack[stackPos] = point;
							stackPos++;
							point = newPoint;
							if (point.x > maxRight) maxRight = point.x;
						}
						else {
							
							newPoint = point;
							newPoint.x--;
							if (IntPointInRect(newPoint, rect) && shouldFill(overlay, data, seeds, numSeeds, newPoint, width, spp, tolerance, channel)) {
								stack[stackPos] = point;
								stackPos++;
								point = newPoint;
								if (point.x < minLeft) minLeft = point.x;
							}
							else {
								stackPos--;
								if (stackPos > -1)
									point = stack[stackPos];
							}
				
						}
						
					}
					
				}
				
			} while (stackPos > -1);
			
			free(stack);
			result = IntSumRects(result, IntMakeRect(minLeft, minTop, maxRight - minLeft + 1, maxBottom - minTop + 1));
		}
	}
	
	return result;
}

void textureFill(CGContextRef context,NSImage *image,CGRect rect)
{
    CGContextSaveGState(context);
    CGContextClipToRect(context, rect);
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    CGContextDrawTiledImage(context,NSMakeRect(0,0,[image size].width,[image size].height),[image CGImageForProposedRect:NULL context:NULL hints:NULL]);
    CGContextRestoreGState(context);
}

void smudgeFill0(int spp, int channel, IntRect rect, unsigned char *layerData, unsigned char *overlay, int width, int height, unsigned char *accum, unsigned char *mask, int brushWidth, int brushHeight, int rate, int startX,int startY)
{
    int lastX = MIN(brushWidth,startX+TILE_SIZE);
    int lastY = MIN(brushHeight,startY+TILE_SIZE);

    int t1;

    for (int j=startY;j<lastY;j++) {

        int y = rect.origin.y+j;
        if(y<0 || y >= height)
            continue;

        for(int i=startX;i<lastX;i++){

            int x = rect.origin.x + i;
            if(x <0 || x >= width)
                continue;

            int offset = j*brushWidth+i;
            int alpha = int_mult(mask[offset],rate,t1);
            unsigned char *apos = accum+offset*spp;

            offset = (y*width+x)*spp;
            unsigned char *opos = overlay+offset;
            unsigned char *lpos = layerData+offset;

            unsigned char pixel[spp];
            memcpy(pixel,lpos,spp);
            if(channel==kPrimaryChannels){
                pixel[spp-1]=0xFF;
            } else if(channel==kAlphaChannel) {
                memset(pixel,pixel[spp-1],spp-1);
            }
            if(apos[spp-1]==0) {
                memcpy(apos,pixel,spp);
            }
            merge_pm2(spp,apos,opos,opos,alpha);
        }
    }
}

void smudgeFill(int spp, int channel, IntRect r, unsigned char *layerData, unsigned char *data, int width, int height, unsigned char *accum, unsigned char *mask, int brushWidth, int brushHeight, int rate)
{
    if(brushWidth<TILE_SIZE && brushHeight<TILE_SIZE){
        return smudgeFill0(spp,channel,r,layerData,data,width,height,accum,mask,brushWidth,brushHeight,rate, 0,0);
    }

    int cols = brushWidth / TILE_SIZE + 1;
    int rows = brushHeight / TILE_SIZE + 1;

    for(int i=0;i<rows;i++) {
        int startY = i * TILE_SIZE;
        for(int j=0;j<cols;j++) {
            int startX = j * TILE_SIZE;
            dispatch_group_async(group,queue,^{smudgeFill0(spp,channel, r,layerData,data,width,height,accum,mask,brushWidth,brushHeight,rate,startX,startY);});
        }
    }
    dispatch_group_wait(group,DISPATCH_TIME_FOREVER);
}


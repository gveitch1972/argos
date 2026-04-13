/// ObjC wrapper around the private CGVirtualDisplay API.
/// Exposed to Swift as plain C functions via ArgosDriverBridge.h.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "include/CGVirtualDisplayBridge.h"
#import "include/ArgosDriverBridge.h"

// Module-level singleton — CGVirtualDisplay must stay alive while in use.
static CGVirtualDisplay *sVirtualDisplay = nil;

uint32_t argos_vdisplay_create(const char *name, uint32_t width, uint32_t height,
                               double refresh_hz, uint32_t hi_dpi) {
    if (sVirtualDisplay) {
        return (uint32_t)sVirtualDisplay.displayID;  // already up
    }

    CGVirtualDisplayDescriptor *desc = [[CGVirtualDisplayDescriptor alloc] init];
    desc.name          = name ? [NSString stringWithUTF8String:name] : @"Argos Virtual Display";
    desc.vendorID      = 0x3318;   // Xreal (cosmetic)
    desc.productID     = 0x0001;
    desc.serialNumber  = 1;
    // ~24" at 1920×1080 → ~92 ppi
    desc.sizeInMillimeters = CGSizeMake(527.0, 296.0);
    desc.maxPixelsWide = width;
    desc.maxPixelsHigh = height;
    desc.queue         = dispatch_get_main_queue();

    CGVirtualDisplay *display = [[CGVirtualDisplay alloc] initWithDescriptor:desc];
    if (!display) {
        NSLog(@"[argos] CGVirtualDisplay init returned nil — entitlement missing?");
        return 0;
    }

    CGVirtualDisplayMode *mode = [[CGVirtualDisplayMode alloc]
        initWithWidth:width height:height refreshRate:refresh_hz];
    CGVirtualDisplaySettings *settings = [[CGVirtualDisplaySettings alloc] init];
    settings.modes = @[mode];
    settings.hiDPI = hi_dpi;

    if (![display applySettings:settings]) {
        NSLog(@"[argos] CGVirtualDisplay applySettings failed");
        return 0;
    }

    sVirtualDisplay = display;
    NSLog(@"[argos] virtual display created — id=%u (%ux%u@%.0fHz hiDPI=%u)",
          display.displayID, width, height, refresh_hz, hi_dpi);
    return (uint32_t)display.displayID;
}

void argos_vdisplay_destroy(void) {
    if (sVirtualDisplay) {
        NSLog(@"[argos] virtual display destroyed (id=%u)", sVirtualDisplay.displayID);
        sVirtualDisplay = nil;
    }
}

uint32_t argos_vdisplay_id(void) {
    return sVirtualDisplay ? (uint32_t)sVirtualDisplay.displayID : 0;
}

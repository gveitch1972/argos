/// Private CoreGraphics virtual display API.
/// Discovered via ObjC runtime introspection — no public header exists.
/// Requires entitlement: com.apple.developer.virtual-display

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// ── CGVirtualDisplayMode ─────────────────────────────────────────────────────

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(uint32_t)width
                       height:(uint32_t)height
                  refreshRate:(double)refreshRate;
@property (nonatomic, readonly) uint32_t width;
@property (nonatomic, readonly) uint32_t height;
@property (nonatomic, readonly) double   refreshRate;
@end

// ── CGVirtualDisplaySettings ─────────────────────────────────────────────────

@interface CGVirtualDisplaySettings : NSObject
- (instancetype)init;
@property (nonatomic, strong) NSArray<CGVirtualDisplayMode *> *modes;
/// 0 = standard (1:1), 2 = HiDPI (2× internal resolution)
@property (nonatomic) uint32_t hiDPI;
@end

// ── CGVirtualDisplayDescriptor ───────────────────────────────────────────────

@interface CGVirtualDisplayDescriptor : NSObject
- (instancetype)init;
@property (nonatomic, nullable, strong)  NSString       *name;
/// Dispatch queue on which terminationHandler is called.
@property (nonatomic, nullable, strong)  dispatch_queue_t queue;
/// Called if the display server terminates the virtual display.
@property (nonatomic, nullable, copy)    void(^terminationHandler)(void);
@property (nonatomic) uint32_t  vendorID;
@property (nonatomic) uint32_t  productID;
@property (nonatomic) uint32_t  serialNumber;
/// Reported physical size (affects DPI calculation in System Settings).
@property (nonatomic) CGSize    sizeInMillimeters;
@property (nonatomic) uint32_t  maxPixelsWide;
@property (nonatomic) uint32_t  maxPixelsHigh;
@end

// ── CGVirtualDisplay ─────────────────────────────────────────────────────────

@interface CGVirtualDisplay : NSObject
/// Returns nil if entitlement is missing or the descriptor is invalid.
- (nullable instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
/// The CGDirectDisplayID macOS assigned — use with ScreenCaptureKit, CGDisplay*.
@property (nonatomic, readonly) CGDirectDisplayID displayID;
/// Apply mode changes. Returns YES on success.
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@property (nonatomic, readonly) NSArray<CGVirtualDisplayMode *> *modes;
@property (nonatomic, readonly) uint32_t hiDPI;
/// Called if the display server unexpectedly terminates this display.
@property (nonatomic, nullable, copy) void(^terminationHandler)(void);
@end

NS_ASSUME_NONNULL_END

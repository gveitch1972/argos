/// C header — bridges the Rust argos-driver library to Swift.
/// Swift sees these types and functions directly.

#pragma once
#include <stdint.h>

/// Orientation output from the IMU (in radians).
typedef struct {
    double pitch;        // up / down
    double yaw;          // left / right
    double roll;         // tilt
    uint64_t timestamp_ns;
} ArgosOrientation;

/// Status codes returned by driver functions.
typedef enum {
    ARGOS_OK              = 0,
    ARGOS_NOT_FOUND       = 1,
    ARGOS_PERMISSION      = 2,
    ARGOS_READ_ERROR      = 3,
} ArgosStatus;

/// Opaque session handle.
typedef struct ArgosSession ArgosSession;

/// Connect to the first Xreal Air 2 Pro found. Returns NULL on failure.
ArgosSession* argos_connect(void);

/// Read one orientation sample into `out`. Returns ARGOS_OK on success.
ArgosStatus argos_read_orientation(ArgosSession* session, ArgosOrientation* out);

/// Disconnect and free the session.
void argos_disconnect(ArgosSession* session);

/// Returns 1 if a device is connected, 0 otherwise.
int argos_device_present(void);

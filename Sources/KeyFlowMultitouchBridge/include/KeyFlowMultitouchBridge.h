#ifndef KEYFLOW_MULTITOUCH_BRIDGE_H
#define KEYFLOW_MULTITOUCH_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>

typedef struct {
    int32_t identifier;
    int32_t state;
    float x;
    float y;
    float size;
} KFMTouchPoint;

typedef void (*KFMTFrameCallback)(
    const KFMTouchPoint *points,
    int32_t count,
    double timestamp,
    void *context
);

typedef int32_t KFMTStatus;
enum {
    KFMTStatusAvailable = 0,
    KFMTStatusInvalidCallback = 1,
    KFMTStatusFrameworkUnavailable = 2,
    KFMTStatusRequiredSymbolsUnavailable = 3,
    KFMTStatusDefaultDeviceUnavailable = 4,
    KFMTStatusStartFailed = 5
};

KFMTStatus KFMTGetAvailabilityStatus(void);
KFMTStatus KFMTGetLastStartStatus(void);
bool KFMTIsAvailable(void);
bool KFMTStart(KFMTFrameCallback callback, void *context);
void KFMTStop(void);

#endif

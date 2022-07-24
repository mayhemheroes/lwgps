#include "lwgps/lwgps.h"

int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    lwgps_t gps;
    lwgps_init(&gps);
    lwgps_process(&gps, Data, Size);
    return 0;
}
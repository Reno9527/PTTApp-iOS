/**
 * Opus Swift-compatible wrapper functions
 * Wraps variadic opus_encoder_ctl/decoder_ctl for Swift interop
 */

#ifndef OPUS_SWIFT_H
#define OPUS_SWIFT_H

#include "opus.h"

#ifdef __cplusplus
extern "C" {
#endif

// Encoder CTL wrappers
OPUS_EXPORT int opus_encoder_set_bitrate(OpusEncoder *st, opus_int32 bitrate);
OPUS_EXPORT int opus_encoder_set_complexity(OpusEncoder *st, opus_int32 complexity);
OPUS_EXPORT int opus_encoder_set_signal(OpusEncoder *st, opus_int32 signal);
OPUS_EXPORT int opus_encoder_set_dtx(OpusEncoder *st, opus_int32 dtx);
OPUS_EXPORT int opus_encoder_set_inband_fec(OpusEncoder *st, opus_int32 fec);
OPUS_EXPORT int opus_encoder_reset_state(OpusEncoder *st);

// Decoder CTL wrappers
OPUS_EXPORT int opus_decoder_reset_state(OpusDecoder *st);

#ifdef __cplusplus
}
#endif

#endif /* OPUS_SWIFT_H */

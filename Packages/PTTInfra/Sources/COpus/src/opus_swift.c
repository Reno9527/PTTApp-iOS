/**
 * Opus Swift-compatible wrapper functions implementation
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "opus.h"
#include "opus_swift.h"

// Encoder CTL wrappers

int opus_encoder_set_bitrate(OpusEncoder *st, opus_int32 bitrate) {
    return opus_encoder_ctl(st, OPUS_SET_BITRATE(bitrate));
}

int opus_encoder_set_complexity(OpusEncoder *st, opus_int32 complexity) {
    return opus_encoder_ctl(st, OPUS_SET_COMPLEXITY(complexity));
}

int opus_encoder_set_signal(OpusEncoder *st, opus_int32 signal) {
    return opus_encoder_ctl(st, OPUS_SET_SIGNAL(signal));
}

int opus_encoder_set_dtx(OpusEncoder *st, opus_int32 dtx) {
    return opus_encoder_ctl(st, OPUS_SET_DTX(dtx));
}

int opus_encoder_set_inband_fec(OpusEncoder *st, opus_int32 fec) {
    return opus_encoder_ctl(st, OPUS_SET_INBAND_FEC(fec));
}

int opus_encoder_reset_state(OpusEncoder *st) {
    return opus_encoder_ctl(st, OPUS_RESET_STATE);
}

// Decoder CTL wrappers

int opus_decoder_reset_state(OpusDecoder *st) {
    return opus_decoder_ctl(st, OPUS_RESET_STATE);
}

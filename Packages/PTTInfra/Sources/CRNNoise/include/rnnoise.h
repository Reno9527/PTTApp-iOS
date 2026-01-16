/* Copyright (c) 2017 Mozilla */
/*
   RNNoise public API - simplified for Swift Package integration
   Based on original RNNoise by Jean-Marc Valin
*/

#ifndef RNNOISE_H
#define RNNOISE_H 1

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DenoiseState DenoiseState;

/**
 * Return the size of DenoiseState
 */
int rnnoise_get_size(void);

/**
 * Return the number of samples processed by rnnoise_process_frame at a time
 * Returns 480 (10ms @ 48kHz)
 */
int rnnoise_get_frame_size(void);

/**
 * Initializes a pre-allocated DenoiseState
 */
int rnnoise_init(DenoiseState *st);

/**
 * Allocate and initialize a DenoiseState
 * The returned pointer MUST be freed with rnnoise_destroy().
 */
DenoiseState *rnnoise_create(void *model);

/**
 * Free a DenoiseState produced by rnnoise_create.
 */
void rnnoise_destroy(DenoiseState *st);

/**
 * Denoise a frame of samples (480 samples @ 48kHz = 10ms)
 *
 * in and out must be at least rnnoise_get_frame_size() large.
 * Input should be float samples in range [-32768, 32768] (16-bit scale).
 *
 * Returns VAD probability (0.0 ~ 1.0)
 */
float rnnoise_process_frame(DenoiseState *st, float *out, const float *in);

#ifdef __cplusplus
}
#endif

#endif /* RNNOISE_H */

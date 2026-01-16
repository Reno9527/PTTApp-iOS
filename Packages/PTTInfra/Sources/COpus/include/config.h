/* Opus configuration for iOS */
#ifndef CONFIG_H
#define CONFIG_H

/* Use float for internal processing */
#define FLOAT_APPROX 1

/* Fixed-point SILK for better mobile performance */
#define FIXED_POINT 1

/* Enable assertions in debug builds */
#ifdef DEBUG
#define ENABLE_ASSERTIONS 1
#endif

/* Disable CPU-specific assembly - use portable C code */
/* This avoids needing arm/armcpu.h and x86 intrinsics */
/* Note: Do NOT define OPUS_HAVE_RTCD, OPUS_ARM_ASM, etc. */
/* The absence of these macros will make cpu_support.h use the fallback path */

/* Use restrict keyword */
#define HAVE_RESTRICT 1
#define restrict __restrict

/* Use inline */
#define HAVE_INLINE 1

/* Use built-in lrint */
#define HAVE_LRINTF 1
#define HAVE_LRINT 1

/* Memory alignment */
#define VAR_ARRAYS 1

/* Package info */
#define PACKAGE_VERSION "1.4"
#define OPUS_BUILD 1

#endif /* CONFIG_H */

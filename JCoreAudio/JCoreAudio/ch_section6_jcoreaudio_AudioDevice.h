/* DO NOT EDIT THIS FILE - it is machine generated */
#include <JavaVM/jni.h>
/* Header for class ch_section6_jcoreaudio_AudioDevice */

#ifndef _Included_ch_section6_jcoreaudio_AudioDevice
#define _Included_ch_section6_jcoreaudio_AudioDevice
#ifdef __cplusplus
extern "C" {
#endif
/*
 * Class:     ch_section6_jcoreaudio_AudioDevice
 * Method:    queryLetSet
 * Signature: (Lch/section6/jcoreaudio/AudioDevice;IZLjava/util/Set;)V
 */
JNIEXPORT void JNICALL Java_ch_section6_jcoreaudio_AudioDevice_queryLetSet
  (JNIEnv *, jclass, jobject, jint, jboolean, jobject);

/*
 * Class:     ch_section6_jcoreaudio_AudioDevice
 * Method:    getCurrentBufferSize
 * Signature: (I)I
 */
JNIEXPORT jint JNICALL Java_ch_section6_jcoreaudio_AudioDevice_getCurrentBufferSize
  (JNIEnv *, jclass, jint);

/*
 * Class:     ch_section6_jcoreaudio_AudioDevice
 * Method:    getMinimumBufferSize
 * Signature: (I)I
 */
JNIEXPORT jint JNICALL Java_ch_section6_jcoreaudio_AudioDevice_getMinimumBufferSize
  (JNIEnv *, jclass, jint);

/*
 * Class:     ch_section6_jcoreaudio_AudioDevice
 * Method:    getMaximumBufferSize
 * Signature: (I)I
 */
JNIEXPORT jint JNICALL Java_ch_section6_jcoreaudio_AudioDevice_getMaximumBufferSize
  (JNIEnv *, jclass, jint);

/*
 * Class:     ch_section6_jcoreaudio_AudioDevice
 * Method:    getSampleRate
 * Signature: (I)F
 */
JNIEXPORT jfloat JNICALL Java_ch_section6_jcoreaudio_AudioDevice_getCurrentSampleRate
  (JNIEnv *, jclass, jint);

#ifdef __cplusplus
}
#endif
#endif

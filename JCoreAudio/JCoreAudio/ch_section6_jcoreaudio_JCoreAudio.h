/* DO NOT EDIT THIS FILE - it is machine generated */
#include <JavaVM/jni.h>
/* Header for class ch_section6_jcoreaudio_JCoreAudio */

#ifndef _Included_ch_section6_jcoreaudio_JCoreAudio
#define _Included_ch_section6_jcoreaudio_JCoreAudio
#ifdef __cplusplus
extern "C" {
#endif
/*
 * Class:     ch_section6_jcoreaudio_JCoreAudio
 * Method:    fillAudioDeviceList
 * Signature: (Ljava/util/List;)V
 */
JNIEXPORT void JNICALL Java_ch_section6_jcoreaudio_JCoreAudio_fillAudioDeviceList
  (JNIEnv *, jclass, jobject);

/*
 * Class:     ch_section6_jcoreaudio_JCoreAudio
 * Method:    initialize
 * Signature: ([Ljava/lang/Object;II[Ljava/lang/Object;IIIF)J
 */
JNIEXPORT jlong JNICALL Java_ch_section6_jcoreaudio_JCoreAudio_initialize
  (JNIEnv *, jclass, jobjectArray, jint, jint, jobjectArray, jint, jint, jint, jfloat);

/*
 * Class:     ch_section6_jcoreaudio_JCoreAudio
 * Method:    uninitialize
 * Signature: (J)V
 */
JNIEXPORT void JNICALL Java_ch_section6_jcoreaudio_JCoreAudio_uninitialize
  (JNIEnv *, jclass, jlong);

/*
 * Class:     ch_section6_jcoreaudio_JCoreAudio
 * Method:    play
 * Signature: (ZJ)V
 */
JNIEXPORT void JNICALL Java_ch_section6_jcoreaudio_JCoreAudio_play
  (JNIEnv *, jclass, jboolean, jlong);

#ifdef __cplusplus
}
#endif
#endif

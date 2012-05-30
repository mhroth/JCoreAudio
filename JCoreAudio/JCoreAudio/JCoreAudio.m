/*
 *  Copyright 2012 Martin Roth
 *                 mhroth@gmail.com
 * 
 *  This file is part of JCoreAudio.
 *
 *  JCoreAudio is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  JCoreAudio is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *  
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with JCoreAudio.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import <AudioUnit/AudioUnit.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreServices/CoreServices.h>
#import "com_synthbot_JCoreAudio_AudioDevice.h"
#import "com_synthbot_JCoreAudio_AudioLet.h"
#import "com_synthbot_JCoreAudio_JCoreAudio.h"
#import "JCoreAudio.h"

jclass JCA_jclazzJCoreAudio;
jmethodID JCA_fireOnCoreAudioCallbackMid;

typedef struct JCoreAudioStruct {
  AudioUnit auhalInput;
  AudioUnit auhalOutput;
  int numChannelsInput;
  int numChannelsOutput;
  float **channelsInput;
  float **channelsOutput;
  int blockSize;
} JCoreAudioStruct;

JavaVM *JCoreAudio_globalJvm;
JCoreAudioStruct *jcaStruct;

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *jvm, void *reserved) {
  // require JNI_VERSION_1_4 for access to NIO functions
  // http://docs.oracle.com/javase/1.4.2/docs/guide/jni/jni-14.html
  JCoreAudio_globalJvm = jvm; // store the JVM so that it can be used to attach CoreAudio threads to the JVM during callbacks
  
  jcaStruct = (JCoreAudioStruct *) malloc(sizeof(JCoreAudioStruct));
  
  JNIEnv *env = NULL;
  (*jvm)->GetEnv(jvm, (void **) &env, JNI_VERSION_1_4);
//  jcaStruct->jclazzJCoreAudio = (*env)->FindClass(env, "com/synthbot/JCoreAudio/JCoreAudio");
//  jcaStruct->fireOnCoreAudioCallbackMid = (*env)->GetStaticMethodID(env, jcaStruct->jclazzJCoreAudio,
//      "fireOnCoreAudioCallback", "()V");
  
  JCA_jclazzJCoreAudio = (*env)->FindClass(env, "com/synthbot/JCoreAudio/JCoreAudio");
  JCA_fireOnCoreAudioCallbackMid = (*env)->GetStaticMethodID(env, JCA_jclazzJCoreAudio,
      "fireOnCoreAudioCallback", "()V");
  
  return JNI_VERSION_1_4;
}

void JNI_OnUnload(JavaVM *vm, void *reserved) {
  free(jcaStruct);
}

// render callback for output AUHAL
// gets output audio from Java and sends it to the output hardware device
OSStatus outputRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
  const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
  static jclass jclassJCA = 0;
  
  JNIEnv *env = nil;
  jint res = (*JCoreAudio_globalJvm)->AttachCurrentThreadAsDaemon(JCoreAudio_globalJvm, (void **) &env, NULL);
  if (res == JNI_OK) {
    // make audio callback to Java and fill the byte buffers
    JCoreAudioStruct *jca = (JCoreAudioStruct *) inRefCon; 
    if (jclassJCA == 0) jclassJCA = (*env)->FindClass(env, "com/synthbot/JCoreAudio/JCoreAudio");
    (*env)->CallStaticVoidMethod(env, jclassJCA, JCA_fireOnCoreAudioCallbackMid);
    
    // interleave the channels to the backing buffers
    // TODO(mhroth): vectorise this like a real man, ok?
    float *caBuffer = (float *) ioData->mBuffers[0].mData;
    for (int i = 0; i < jca->numChannelsOutput; i++) {
      for (int j = 0, k = i; j < jca->blockSize; j++, k+=jca->numChannelsOutput) {
        caBuffer[k] = jca->channelsOutput[i][j];
      }
    }
  }
  
  return noErr; // everything is gonna be ok
}

JNIEXPORT void JNICALL Java_com_synthbot_JCoreAudio_JCoreAudio_fillAudioDeviceList
    (JNIEnv *env, jclass jclazz, jobject jlist) {
  
  jclass jclazzAudioDevice = (*env)->FindClass(env, "com/synthbot/JCoreAudio/AudioDevice");
  jclass jclazzArrayList = (*env)->FindClass(env, "java/util/ArrayList");
      
  // get number of AudioDevices
  UInt32 arraySize;
  AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices, &arraySize, NULL);
  int numAudioDevices = arraySize/sizeof(AudioDeviceID);
  AudioDeviceID audioDeviceIds[numAudioDevices];
  AudioHardwareGetProperty(kAudioHardwarePropertyDevices, &arraySize, audioDeviceIds);
      
  for (int i = 0; i < numAudioDevices; i++) {
    // get name string
    UInt32 propSize = 0;
    AudioDeviceGetPropertyInfo(audioDeviceIds[i], 0, false, kAudioDevicePropertyDeviceName, &propSize, NULL);
    char strName[++propSize]; memset(strName, 0, sizeof(strName)); // ensure that string is zero terminated
    AudioDeviceGetProperty(audioDeviceIds[i], 0, false, kAudioDevicePropertyDeviceName, &propSize, strName);
    
    // get manufacturer string
    AudioDeviceGetPropertyInfo(audioDeviceIds[i], 0, false, kAudioDevicePropertyDeviceManufacturer, &propSize, NULL);
    char strManufacturer[++propSize]; memset(strManufacturer, 0, sizeof(strManufacturer));
    AudioDeviceGetProperty(audioDeviceIds[i], 0, false, kAudioDevicePropertyDeviceManufacturer, &propSize, strManufacturer);
    
    // create the AudioDevice object
    jobject jAudioDevice = (*env)->NewObject(env, jclazzAudioDevice,
        (*env)->GetMethodID(env, jclazzAudioDevice, "<init>", "(ILjava/lang/String;Ljava/lang/String;)V"),
        audioDeviceIds[i],
        (*env)->NewStringUTF(env, strName),
        (*env)->NewStringUTF(env, strManufacturer));
    
    // add the AudioDevice object to the given List
    (*env)->CallVoidMethod(env, jlist,
        (*env)->GetMethodID(env, jclazzArrayList, "add", "(Ljava/lang/Object;)Z"),
        jAudioDevice);
  }
}

JNIEXPORT void JNICALL Java_com_synthbot_JCoreAudio_AudioDevice_queryLetSet
    (JNIEnv *env, jclass jclazz, jobject jobj, jint deviceId, jboolean isInput, jobject jset) {
  
  jclass jclazzAudioLet = (*env)->FindClass(env, "com/synthbot/JCoreAudio/AudioLet");
  jclass jclazzHashSet = (*env)->FindClass(env, "java/util/HashSet");
      
  // get the number of channels that this AudioDevice has
  UInt32 propSize = 0;
  AudioDeviceGetPropertyInfo(deviceId, 0, isInput, kAudioDevicePropertyStreamConfiguration, &propSize, NULL);
  int numLets  = propSize/sizeof(AudioBufferList);
  AudioBufferList buffLetList[numLets];
  AudioDeviceGetProperty(deviceId, 0, isInput, kAudioDevicePropertyStreamConfiguration, &propSize, buffLetList);
  
  int channelIndex = 0;
  for (int j = 0; j < numLets; j++) {
    AudioDeviceGetPropertyInfo(deviceId, j, isInput, kAudioDevicePropertyChannelName, &propSize, NULL);
    char strADName[++propSize]; memset(strADName, 0, sizeof(strADName));
    AudioDeviceGetProperty(deviceId, j, isInput, kAudioDevicePropertyChannelName, &propSize, strADName);
    
    // create a new AudioChannel object
    jobject jAudioLet = (*env)->NewObject(env, jclazzAudioLet,
        (*env)->GetMethodID(env, jclazzAudioLet, "<init>", "(Lcom/synthbot/JCoreAudio/AudioDevice;IILjava/lang/String;ZI)V"),
        jobj, j, channelIndex, (*env)->NewStringUTF(env, strADName),
        isInput, buffLetList[j].mBuffers[0].mNumberChannels);
    
    // add the AudioChannel to the inputSet
    (*env)->CallVoidMethod(env, jset,
        (*env)->GetMethodID(env, jclazzHashSet, "add", "(Ljava/lang/Object;)Z"),
        jAudioLet);
    
    channelIndex += buffLetList[j].mBuffers[0].mNumberChannels;
  }
}

JNIEXPORT void JNICALL Java_com_synthbot_JCoreAudio_AudioLet_queryAvailableFormats
    (JNIEnv *env, jclass jclazz, jint deviceId, jint letIndex, jboolean isInput, jobject jset) {
  
  jclass jclazzAudioFormat = (*env)->FindClass(env, "com/synthbot/JCoreAudio/AudioFormat");
  jclass jclazzHashSet = (*env)->FindClass(env, "java/util/HashSet");
      
  UInt32 propSize = 0;
  AudioDeviceGetPropertyInfo(deviceId, letIndex, isInput, kAudioDevicePropertyStreamFormats, &propSize, NULL);
  int numFormats = propSize/sizeof(AudioStreamBasicDescription);
  AudioStreamBasicDescription formats[numFormats]; memset(formats, 0, propSize);
  AudioDeviceGetProperty(deviceId, letIndex, isInput, kAudioDevicePropertyStreamFormats, &propSize, formats);
      
  for (int i = 0; i < numFormats; i++) {
    AudioStreamBasicDescription asbd = formats[i];
    
    // create a new AudioFormat object
    jobject jAudioFormat = (*env)->NewObject(env, jclazzAudioFormat,
        (*env)->GetMethodID(env, jclazzAudioFormat, "<init>", "(II)V"),
        (jint) asbd.mSampleRate, (jint) asbd.mBitsPerChannel);
    
    // add the AudioFormat object to the given Set
    (*env)->CallVoidMethod(env, jset,
        (*env)->GetMethodID(env, jclazzHashSet, "add", "(Ljava/lang/Object;)Z"),
        jAudioFormat);
  }
}

// file:///Users/mhroth/Library/Developer/Shared/Documentation/DocSets/com.apple.adc.documentation.AppleLion.CoreReference.docset/Contents/Resources/Documents/index.html#technotes/tn2091/_index.html
JNIEXPORT void JNICALL Java_com_synthbot_JCoreAudio_JCoreAudio_initialize
  (JNIEnv *env, jclass jclazz, jarray jinputArray, jint jnumChannelsInput, jint jinputDeviceId,
      jarray joutputArray, jint jnumChannelsOutput, jint joutputDeviceId,
      jint jblockSize, jfloat jsampleRate) {
   
  // initialise to known values
  jcaStruct->auhalInput = NULL;
  jcaStruct->auhalOutput = NULL;
  OSStatus err = noErr;
  
  // create an AUHAL (for 10.6 and later)
  AudioComponent comp; // find AUHAL component
  AudioComponentDescription desc;
  desc.componentType = kAudioUnitType_Output;
  desc.componentSubType = kAudioUnitSubType_HALOutput;
  desc.componentManufacturer = kAudioUnitManufacturer_Apple;
  desc.componentFlags = 0;
  desc.componentFlagsMask = 0;
  comp = AudioComponentFindNext(NULL, &desc);
  if (comp == NULL) {
    // TODO(mhroth): Throw an Exception. Something has gone terribly wrong.
  }
  AudioComponentInstanceNew(comp, &(jcaStruct->auhalOutput)); // open the component and initialise it (10.6 and later)

  if (joutputArray != NULL) {
    // the output set is non-empty. Configure the AUHAL to be in the graph and provide output
    
    // disable input on the AUHAL
    UInt32 enableIO = 0;
    err =  AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioOutputUnitProperty_EnableIO,
        kAudioUnitScope_Input,
        1, // input element
        &enableIO, sizeof(enableIO));
    
    // enable output on the AUHAL
    enableIO = 1;
    err =  AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioOutputUnitProperty_EnableIO,
        kAudioUnitScope_Output,
        0, // output element
        &enableIO, sizeof(enableIO));
    
    // set the hardware device to which the AUHAL is connected
    err = AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioOutputUnitProperty_CurrentDevice, 
        kAudioUnitScope_Global, 
        0, 
        &joutputDeviceId, sizeof(AudioDeviceID));

    // configure channel map and channel backing buffers
    SInt32 channelMap[jnumChannelsOutput];
    jclass jclazzAudioLet =  (*env)->FindClass(env, "com/synthbot/JCoreAudio/AudioLet");
    jcaStruct->blockSize = jblockSize;
    jcaStruct->numChannelsOutput = jnumChannelsOutput;
    jcaStruct->channelsOutput = (float **) malloc(jnumChannelsOutput * sizeof(float *));
    for (int i = 0, k = 0; i < (*env)->GetArrayLength(env, joutputArray); i++) {
      // get the number of channels in this let
      jobject objAudioLet = (*env)->GetObjectArrayElement(env, joutputArray, i);
      int numChannels = (*env)->CallIntMethod(env, objAudioLet, (*env)->GetMethodID(env, jclazzAudioLet, "getNumChannels", "()I"));
      int channelIndex = (*env)->CallIntMethod(env, objAudioLet, (*env)->GetMethodID(env, jclazzAudioLet, "getChannelIndex", "()I"));
      for (int j = 0; j < numChannels; j++, k++, channelIndex++) {
        // create the native backing buffer
        jcaStruct->channelsOutput[k] = (float *) calloc(jblockSize, sizeof(float));
        
        // create a new ByteBuffer
        jobject jByteBuffer = (*env)->NewDirectByteBuffer(env, jcaStruct->channelsOutput[k], jblockSize*sizeof(float));
        
        // assign ByteBuffer to channel
        (*env)->CallVoidMethod(env, objAudioLet,
            (*env)->GetMethodID(env, jclazzAudioLet, "setChannelBuffer", "(ILjava/nio/ByteBuffer;)V"),
            j, jByteBuffer);
        
        channelMap[k] = channelIndex;
      }
    }
    
    // set the channel map
    AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioOutputUnitProperty_ChannelMap,
        kAudioUnitScope_Input, 0,
        channelMap, jnumChannelsOutput);
    
    // register audio callback
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = &outputRenderCallback;
    renderCallbackStruct.inputProcRefCon = jcaStruct;
    err = AudioUnitSetProperty(jcaStruct->auhalOutput, 
        kAudioUnitProperty_SetRenderCallback, // kAudioOutputUnitProperty_SetInputCallback kAudioUnitProperty_SetRenderCallback
        kAudioUnitScope_Global,
        0,
        &renderCallbackStruct, sizeof(AURenderCallbackStruct));
    
    // configure output device to given sample
    AudioStreamBasicDescription asbd;
    UInt32 propSize = sizeof(AudioStreamBasicDescription);
    AudioUnitGetProperty (jcaStruct->auhalOutput,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Output,
        0,
        &asbd, &propSize);
    
    asbd.mSampleRate = (Float64) jsampleRate; // update the sample rate
    printf("AudioStreamBasicDescription set to:\n  "
        "mSampleRate: %g\n  mChannelsPerFrame: %i\n  mBytesPerFrame: %i\n  "
        "mFormatID: %i\n  mFormatFlags: %i\n",
        asbd.mSampleRate, asbd.mChannelsPerFrame, asbd.mBytesPerFrame, asbd.mFormatID, asbd.mFormatFlags);
    
    AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input,
        0,
        &asbd, sizeof(AudioStreamBasicDescription));
    
    // now that the AUHAL is set up, initialise it
    AudioUnitInitialize(jcaStruct->auhalOutput);
  }
}

JNIEXPORT void JNICALL Java_com_synthbot_JCoreAudio_JCoreAudio_uninitialize
    (JNIEnv *env, jclass jclazz, jlong nativePtr) {
  
}

JNIEXPORT void JNICALL Java_com_synthbot_JCoreAudio_JCoreAudio_play
    (JNIEnv *env, jclass jclazz, jboolean shouldPlay) {
  if (shouldPlay) {
    if (jcaStruct->auhalInput != NULL) AudioOutputUnitStart(jcaStruct->auhalInput);
    if (jcaStruct->auhalOutput != NULL) AudioOutputUnitStart(jcaStruct->auhalOutput);
  } else {
    if (jcaStruct->auhalInput != NULL) AudioOutputUnitStop(jcaStruct->auhalInput);
    if (jcaStruct->auhalOutput != NULL) AudioOutputUnitStop(jcaStruct->auhalOutput);
  }
}

@implementation JCoreAudio

@end

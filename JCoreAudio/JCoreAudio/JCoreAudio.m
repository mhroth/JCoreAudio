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
#import "ch_section6_jcoreaudio_AudioDevice.h"
#import "ch_section6_jcoreaudio_AudioLet.h"
#import "ch_section6_jcoreaudio_JCoreAudio.h"

typedef struct JCoreAudioStruct {
  jclass jclazzJCoreAudio;
  jmethodID fireOnCoreAudioInputMid;
  jmethodID fireOnCoreAudioOutputMid;

  AudioUnit auhalInput;
  AudioUnit auhalOutput;
  int numChannelsInput;
  int numChannelsOutput;
  float **channelsInput;
  float **channelsOutput;
  int blockSize;
} JCoreAudioStruct;

JavaVM *JCoreAudio_globalJvm = nil;

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *jvm, void *reserved) {
  // require JNI_VERSION_1_4 for access to NIO functions
  // http://docs.oracle.com/javase/1.4.2/docs/guide/jni/jni-14.html
  JCoreAudio_globalJvm = jvm; // store the JVM so that it can be used to attach CoreAudio threads to the JVM during callbacks

  return JNI_VERSION_1_4;
}

// render callback for input AUHAL
OSStatus inputRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
  
  JNIEnv *env = nil;
  jint res = (*JCoreAudio_globalJvm)->AttachCurrentThreadAsDaemon(JCoreAudio_globalJvm, (void **) &env, NULL);
  if (res == JNI_OK) {
    JCoreAudioStruct *jca = (JCoreAudioStruct *) inRefCon;
    
    AudioBufferList *bufferList =
        (AudioBufferList *) alloca(sizeof(AudioBufferList) + (sizeof(AudioBuffer)*(jca->numChannelsInput-1)));
    bufferList->mNumberBuffers = jca->numChannelsInput;
    for (int i = 0; i < jca->numChannelsInput; ++i) {
      bufferList->mBuffers[i].mNumberChannels = 1;
      bufferList->mBuffers[i].mDataByteSize = jca->blockSize * sizeof(float);
      bufferList->mBuffers[i].mData = alloca(bufferList->mBuffers[i].mDataByteSize);
      memset(bufferList->mBuffers[i].mData, 0, bufferList->mBuffers[i].mDataByteSize);
    }
    
    AudioUnitRender(jca->auhalInput, ioActionFlags, inTimeStamp, inBusNumber,
        inNumberFrames, bufferList);
    
    for (int i = 0; i < jca->numChannelsInput; ++i) {
      memcpy(jca->channelsInput[i], bufferList->mBuffers[i].mData, bufferList->mBuffers[i].mDataByteSize);
    }

    // make audio callback to Java and fill the byte buffers
    (*env)->CallStaticVoidMethod(env, jca->jclazzJCoreAudio, jca->fireOnCoreAudioInputMid, inTimeStamp->mSampleTime);
  }
  
  return noErr; // everything is gonna be ok
}

// render callback for output AUHAL
// gets output audio from Java and sends it to the output hardware device
OSStatus outputRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
  const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {

  JNIEnv *env = nil;
  jint res = (*JCoreAudio_globalJvm)->AttachCurrentThreadAsDaemon(JCoreAudio_globalJvm, (void **) &env, NULL);
  if (res == JNI_OK) {
    // make audio callback to Java and fill the byte buffers
    JCoreAudioStruct *jca = (JCoreAudioStruct *) inRefCon; 
    (*env)->CallStaticVoidMethod(env, jca->jclazzJCoreAudio, jca->fireOnCoreAudioOutputMid, inTimeStamp->mSampleTime);
    
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

// https://developer.apple.com/library/mac/#technotes/tn2010/tn2223.html
JNIEXPORT void JNICALL Java_ch_section6_jcoreaudio_JCoreAudio_fillAudioDeviceList
    (JNIEnv *env, jclass jclazz, jobject jlist) {
  
  jclass jclazzAudioDevice = (*env)->FindClass(env, "ch/section6/jcoreaudio/AudioDevice");
  jclass jclazzArrayList = (*env)->FindClass(env, "java/util/ArrayList");
      
  // get number of AudioDevices
  UInt32 arraySize;
  AudioObjectPropertyAddress aopa = {
    kAudioHardwarePropertyDevices,
    kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMaster
  };
  AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &aopa, 0, NULL, &arraySize);
  int numAudioDevices = arraySize/sizeof(AudioDeviceID);
  AudioDeviceID audioDeviceIds[numAudioDevices];
      
  // get AudioDevice information
  AudioObjectGetPropertyData(kAudioObjectSystemObject, &aopa, 0, NULL, &arraySize, audioDeviceIds);
      
  for (int i = 0; i < numAudioDevices; i++) {
    UInt32 propSize = 0;
    
    // get name string
    aopa.mSelector = kAudioDevicePropertyDeviceName;
    AudioObjectGetPropertyDataSize(audioDeviceIds[i], &aopa, 0, NULL, &propSize);
    char strName[propSize];
    AudioObjectGetPropertyData(audioDeviceIds[i], &aopa, 0, NULL, &propSize, strName);
    
    // get manufacturer string
    aopa.mSelector = kAudioDevicePropertyDeviceManufacturer;
    AudioObjectGetPropertyDataSize(audioDeviceIds[i], &aopa, 0, NULL, &propSize);
    char strManufacturer[propSize];
    AudioObjectGetPropertyData(audioDeviceIds[i], &aopa, 0, NULL, &propSize, strManufacturer);
    
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

JNIEXPORT void JNICALL Java_ch_section6_jcoreaudio_AudioDevice_queryLetSet
    (JNIEnv *env, jclass jclazz, jobject jobj, jint deviceId, jboolean isInput, jobject jset) {
  
  jclass jclazzAudioLet = (*env)->FindClass(env, "ch/section6/jcoreaudio/AudioLet");
  jclass jclazzHashSet = (*env)->FindClass(env, "java/util/HashSet");
      
  // get the number of channels that this AudioDevice has
  UInt32 propSize = 0;

  AudioObjectPropertyAddress aopa = {
      kAudioDevicePropertyStreamConfiguration,
      (isInput == JNI_TRUE) ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
      kAudioObjectPropertyElementMaster
  };
  AudioObjectGetPropertyDataSize(deviceId, &aopa, 0, NULL, &propSize);
  int numLets = propSize/sizeof(AudioBufferList);
  AudioBufferList buffLetList[numLets];
  AudioObjectGetPropertyData(deviceId, &aopa, 0, NULL, &propSize, buffLetList);
  
  // NOTE(mhroth): without setting this, the program crashes... weird!
  numLets = buffLetList[0].mNumberBuffers;
      
  int channelIndex = 0;
  for (int j = 0; j < numLets; j++) {
    aopa.mSelector = kAudioDevicePropertyChannelName;
    aopa.mElement = j;
    AudioObjectGetPropertyDataSize(deviceId, &aopa, 0, NULL, &propSize);
    char strADName[propSize]; memset(strADName, 0, sizeof(strADName));
    
    // NOTE(mhroth): why does the newer function not work?
    // AudioObjectGetPropertyData(deviceId, &aopa, 0, NULL, &propSize, strADName);
    AudioDeviceGetProperty(deviceId, j, isInput, kAudioDevicePropertyChannelName, &propSize, strADName);
    
    // create a new AudioChannel object
    jobject jAudioLet = (*env)->NewObject(env, jclazzAudioLet,
        (*env)->GetMethodID(env, jclazzAudioLet, "<init>",
            "(Lch/section6/jcoreaudio/AudioDevice;IILjava/lang/String;ZI)V"),
        jobj, j, channelIndex, (*env)->NewStringUTF(env, strADName),
        isInput, buffLetList[0].mBuffers[j].mNumberChannels);
    
    // add the AudioChannel to the inputSet
    (*env)->CallVoidMethod(env, jset,
        (*env)->GetMethodID(env, jclazzHashSet, "add", "(Ljava/lang/Object;)Z"),
        jAudioLet);
    
    channelIndex += buffLetList[0].mBuffers[j].mNumberChannels;
  }
}

JNIEXPORT void JNICALL Java_ch_section6_jcoreaudio_AudioLet_queryAvailableSamplerates
    (JNIEnv *env, jclass jclazz, jint deviceId, jint letIndex, jboolean isInput, jobject jset) {
  
  jclass jclazzFloat = (*env)->FindClass(env, "java/lang/Float");
  jclass jclazzHashSet = (*env)->FindClass(env, "java/util/HashSet");

  UInt32 propSize = 0;
      
  AudioObjectPropertyAddress aopa = {
    kAudioDevicePropertyStreamFormats,
    (isInput == JNI_TRUE) ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
    letIndex
  };
  AudioObjectGetPropertyDataSize(deviceId, &aopa, 0, NULL, &propSize);      
  int numFormats = propSize/sizeof(AudioStreamBasicDescription);
  AudioStreamBasicDescription formats[numFormats]; memset(formats, 0, propSize);
  AudioObjectGetPropertyData(deviceId, &aopa, 0, NULL, &propSize, formats);
      
  for (int i = 0; i < numFormats; i++) {
    AudioStreamBasicDescription asbd = formats[i];
    
    // create a new Float object
    jobject jFloat = (*env)->NewObject(env, jclazzFloat,
        (*env)->GetMethodID(env, jclazzFloat, "<init>", "(F)V"),
        (jfloat) asbd.mSampleRate);
    
    // add the AudioFormat object to the given Set
    (*env)->CallVoidMethod(env, jset,
        (*env)->GetMethodID(env, jclazzHashSet, "add", "(Ljava/lang/Object;)Z"),
        jFloat);
  }
}

JNIEXPORT jint JNICALL Java_ch_section6_jcoreaudio_AudioDevice_getCurrentBufferSize
    (JNIEnv *env, jclass jclazz, jint jaudioDeviceId) {

  AudioObjectPropertyAddress propAddr;
  propAddr.mSelector = kAudioDevicePropertyBufferFrameSize;
  propAddr.mScope = kAudioUnitScope_Global;
  propAddr.mElement = 0;
  UInt32 bufferSize = 0;
  UInt32 propSize = sizeof(UInt32);
  AudioObjectGetPropertyData(jaudioDeviceId, &propAddr, 0, NULL, &propSize, &bufferSize);

  return bufferSize;
}

JNIEXPORT jint JNICALL Java_ch_section6_jcoreaudio_AudioDevice_getMinimumBufferSize
    (JNIEnv *env, jclass jclazz, jint jaudioDeviceId) {

  AudioObjectPropertyAddress propAddr;
  propAddr.mSelector = kAudioDevicePropertyBufferFrameSizeRange;
  propAddr.mScope = kAudioUnitScope_Global;
  propAddr.mElement = 0;
  AudioValueRange range;
  UInt32 propSize = sizeof(AudioValueRange);
  AudioObjectGetPropertyData(jaudioDeviceId, &propAddr, 0, NULL, &propSize, &range);

  return (jint) range.mMinimum;
}

JNIEXPORT jint JNICALL Java_ch_section6_jcoreaudio_AudioDevice_getMaximumBufferSize
    (JNIEnv *env, jclass jclazz, jint jaudioDeviceId) {

  AudioObjectPropertyAddress propAddr;
  propAddr.mSelector = kAudioDevicePropertyBufferFrameSizeRange;
  propAddr.mScope = kAudioUnitScope_Global;
  propAddr.mElement = 0;
  AudioValueRange range;
  UInt32 propSize = sizeof(AudioValueRange);
  AudioObjectGetPropertyData(jaudioDeviceId, &propAddr, 0, NULL, &propSize, &range);

  return (jint) range.mMaximum;
}

JNIEXPORT jfloat JNICALL Java_ch_section6_jcoreaudio_AudioDevice_getCurrentSampleRate
    (JNIEnv *env, jclass jclazz, jint jaudioDeviceId) {
      
  AudioObjectPropertyAddress propAddr;
  propAddr.mSelector = kAudioDevicePropertyNominalSampleRate;
  propAddr.mScope = kAudioUnitScope_Global;
  propAddr.mElement = 0;
  Float64 sampleRate = 0.0;
  UInt32 propSize = sizeof(Float64);
  AudioObjectGetPropertyData(jaudioDeviceId, &propAddr, 0, NULL, &propSize, &sampleRate);

  return (jfloat) sampleRate;
}

JNIEXPORT jlong JNICALL Java_ch_section6_jcoreaudio_JCoreAudio_initialize
  (JNIEnv *env, jclass jclazz, jarray jinputArray, jint jnumChannelsInput, jint jinputDeviceId,
      jarray joutputArray, jint jnumChannelsOutput, jint joutputDeviceId,
      jint jblockSize, jfloat jsampleRate) {
    
  JCoreAudioStruct * jcaStruct = (JCoreAudioStruct *) malloc(sizeof(JCoreAudioStruct));
   
  // cache these values for use during audio callbacks
  // creating these references here ensures that the same class loader is used as for the java
  // object themselves. http://forums.netbeans.org/topic8087.html
  jcaStruct->jclazzJCoreAudio = (*env)->NewGlobalRef(env, jclazz);
  jcaStruct->fireOnCoreAudioInputMid = (*env)->GetStaticMethodID(env, jcaStruct->jclazzJCoreAudio,
      "fireOnCoreAudioInput", "(D)V");
  jcaStruct->fireOnCoreAudioOutputMid = (*env)->GetStaticMethodID(env, jcaStruct->jclazzJCoreAudio,
      "fireOnCoreAudioOutput", "(D)V");
    
  // initialise to known values
  jcaStruct->auhalInput = NULL;
  jcaStruct->auhalOutput = NULL;
  jcaStruct->numChannelsInput = 0;
  jcaStruct->numChannelsOutput = 0;
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
  
  // http://osdir.com/ml/coreaudio-api/2009-10/msg01790.html
  // Tell the AudioDevice to use its own runloop. This allows it to react autonomously to
  // sample rate changes.
  AudioObjectPropertyAddress aopa = {
    kAudioHardwarePropertyRunLoop,
    kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMaster
  };
  AudioObjectSetPropertyData(kAudioObjectSystemObject, &aopa, 0, NULL, sizeof(CFRunLoopRef), NULL);
    
  if (jinputDeviceId != 0) {
    // the intput set is non-empty. Configure the input AUHAL.
    
    // open the component and initialise it (10.6 and later)
    AudioComponentInstanceNew(comp, &(jcaStruct->auhalInput));
    
    // enable input on the AUHAL
    UInt32 enableIO = 1;
    err =  AudioUnitSetProperty(jcaStruct->auhalInput,
        kAudioOutputUnitProperty_EnableIO,
        kAudioUnitScope_Input, 1, // input element
        &enableIO, sizeof(UInt32));
    
    // disable output on the AUHAL
    enableIO = 0;
    err =  AudioUnitSetProperty(jcaStruct->auhalInput,
        kAudioOutputUnitProperty_EnableIO,
        kAudioUnitScope_Output, 0, // output element
        &enableIO, sizeof(UInt32));
    
    // set the hardware device to which the AUHAL is connected
    err = AudioUnitSetProperty(jcaStruct->auhalInput,
        kAudioOutputUnitProperty_CurrentDevice, 
        kAudioUnitScope_Global, 0, 
        &jinputDeviceId, sizeof(AudioDeviceID));
    
    // configure channel map and channel backing buffers
    SInt32 channelMap[jnumChannelsInput];
    jclass jclazzAudioLet =  (*env)->FindClass(env, "ch/section6/jcoreaudio/AudioLet");
    jcaStruct->blockSize = jblockSize;
    jcaStruct->numChannelsInput = jnumChannelsInput;
    jcaStruct->channelsInput = (float **) malloc(jnumChannelsInput * sizeof(float *));
    for (int i = 0, k = 0; i < (*env)->GetArrayLength(env, jinputArray); i++) {
      // get the number of channels in this let
      jobject objAudioLet = (*env)->GetObjectArrayElement(env, jinputArray, i);
      int numChannels = (*env)->CallIntMethod(env, objAudioLet,
          (*env)->GetMethodID(env, jclazzAudioLet, "getNumChannels", "()I"));
      
      // get the starting channel index of this let
      int channelIndex = (*env)->CallIntMethod(env, objAudioLet,
          (*env)->GetMethodID(env, jclazzAudioLet, "getChannelIndex", "()I"));
      
      for (int j = 0; j < numChannels; j++, k++, channelIndex++) {
        // create the native backing buffer
        jcaStruct->channelsInput[k] = (float *) calloc(jblockSize, sizeof(float));
        
        // create a new ByteBuffer
        jobject jByteBuffer = (*env)->NewDirectByteBuffer(
            env, jcaStruct->channelsInput[k], jblockSize*sizeof(float));
        
        // assign ByteBuffer to channel
        (*env)->CallVoidMethod(env, objAudioLet,
            (*env)->GetMethodID(env, jclazzAudioLet, "setChannelBuffer", "(ILjava/nio/ByteBuffer;)V"),
            j, jByteBuffer);
        
        channelMap[k] = channelIndex;
      }
    }
    
    // set the channel map
    AudioUnitSetProperty(jcaStruct->auhalInput,
        kAudioOutputUnitProperty_ChannelMap,
        kAudioUnitScope_Output, 1,
        channelMap, sizeof(channelMap));
    
    // register audio callback
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = &inputRenderCallback;
    renderCallbackStruct.inputProcRefCon = jcaStruct;
    err = AudioUnitSetProperty(jcaStruct->auhalInput, 
        kAudioOutputUnitProperty_SetInputCallback,
        kAudioUnitScope_Global, 0,
        &renderCallbackStruct, sizeof(AURenderCallbackStruct));
    
    // configure output device to given sample rate
    AudioStreamBasicDescription asbd;
    UInt32 propSize = sizeof(AudioStreamBasicDescription);
    asbd.mBitsPerChannel = sizeof(float) * 8;
    asbd.mBytesPerFrame = jcaStruct->numChannelsOutput * sizeof(float);
    asbd.mBytesPerPacket = asbd.mBytesPerFrame;
    asbd.mChannelsPerFrame = jcaStruct->numChannelsOutput;
    asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFramesPerPacket = 1;
    asbd.mReserved = 0;
    asbd.mSampleRate = (Float64) jsampleRate;
    AudioUnitSetProperty(jcaStruct->auhalInput,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input, 1,
        &asbd, propSize);
    
    // make sure that the expected audio format is reported
    AudioUnitGetProperty(jcaStruct->auhalInput,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input, 1,
        &asbd, &propSize);
    if (asbd.mFormatFlags != kAudioFormatFlagsNativeFloatPacked ||
        asbd.mBitsPerChannel != 32) {
      
      // clean up
      Java_ch_section6_jcoreaudio_JCoreAudio_uninitialize(env, jclazz, (jlong) jcaStruct);
      
      // throw an IllegalStateException
      (*env)->ThrowNew(env, (*env)->FindClass(env, "java/lang/IllegalStateException"),
          "Core Audio is not reporting the expected interleaved 32-bit float audio format for the input. "
          "There is nothing that you can do. Report this error along with the audio hardware that you "
          "are using to the library maintainer.");
      return 0;
    }

    // set the device sample rate
    AudioObjectPropertyAddress propAddr;
    propAddr.mSelector = kAudioDevicePropertyNominalSampleRate;
    propAddr.mScope = kAudioUnitScope_Global;
    propAddr.mElement = 0;
    Float64 sampleRate = (Float64) jsampleRate;
    AudioObjectSetPropertyData(jinputDeviceId, &propAddr, 0, NULL, sizeof(Float64), &sampleRate);

    // set requested block size
    AudioUnitSetProperty(jcaStruct->auhalInput,
        kAudioDevicePropertyBufferFrameSize,
        kAudioUnitScope_Output, 1,
        &jblockSize, sizeof(UInt32));
    
    // now that the AUHAL is set up, initialise it
    AudioUnitInitialize(jcaStruct->auhalInput);
  }

  if (joutputDeviceId != 0) {
    // the output set is non-empty. Configure the output AUHAL.

    // open the component and initialise it (10.6 and later)
    AudioComponentInstanceNew(comp, &(jcaStruct->auhalOutput));
    
    // disable input on the AUHAL
    UInt32 enableIO = 0;
    err =  AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioOutputUnitProperty_EnableIO,
        kAudioUnitScope_Input, 1, // input element
        &enableIO, sizeof(enableIO));
    
    // enable output on the AUHAL
    enableIO = 1;
    err =  AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioOutputUnitProperty_EnableIO,
        kAudioUnitScope_Output, 0, // output element
        &enableIO, sizeof(enableIO));
    
    // set the hardware device to which the AUHAL is connected
    err = AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioOutputUnitProperty_CurrentDevice, 
        kAudioUnitScope_Global, 0, 
        &joutputDeviceId, sizeof(AudioDeviceID));

    // configure channel map and channel backing buffers
    SInt32 channelMap[jnumChannelsOutput];
    jclass jclazzAudioLet =  (*env)->FindClass(env, "ch/section6/jcoreaudio/AudioLet");
    jcaStruct->blockSize = jblockSize;
    jcaStruct->numChannelsOutput = jnumChannelsOutput;
    jcaStruct->channelsOutput = (float **) malloc(jnumChannelsOutput * sizeof(float *));
    for (int i = 0, k = 0; i < (*env)->GetArrayLength(env, joutputArray); i++) {
      // get the number of channels in this let
      jobject objAudioLet = (*env)->GetObjectArrayElement(env, joutputArray, i);
      int numChannels = (*env)->CallIntMethod(env, objAudioLet,
          (*env)->GetMethodID(env, jclazzAudioLet, "getNumChannels", "()I"));
      int channelIndex = (*env)->CallIntMethod(env, objAudioLet,
          (*env)->GetMethodID(env, jclazzAudioLet, "getChannelIndex", "()I"));
      for (int j = 0; j < numChannels; j++, k++, channelIndex++) {
        // create the native backing buffer
        jcaStruct->channelsOutput[k] = (float *) calloc(jblockSize, sizeof(float));
        
        // create a new ByteBuffer
        jobject jByteBuffer = (*env)->NewDirectByteBuffer(
            env, jcaStruct->channelsOutput[k], jblockSize*sizeof(float));
        
        // assign ByteBuffer to channel
        (*env)->CallVoidMethod(env, objAudioLet,
            (*env)->GetMethodID(env, jclazzAudioLet, "setChannelBuffer", "(ILjava/nio/ByteBuffer;)V"),
            j, jByteBuffer);
        
        // configure the channel map
        channelMap[k] = channelIndex;
      }
    }
    
    // set the channel map
    AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioOutputUnitProperty_ChannelMap,
        kAudioUnitScope_Input, 0,
        channelMap, sizeof(channelMap));
    
    // register audio callback
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = &outputRenderCallback;
    renderCallbackStruct.inputProcRefCon = jcaStruct;
    err = AudioUnitSetProperty(jcaStruct->auhalOutput, 
        kAudioUnitProperty_SetRenderCallback,
        kAudioUnitScope_Global, 0,
        &renderCallbackStruct, sizeof(AURenderCallbackStruct));
    
    // configure output device work with floating-point samples and the given sample rate
    AudioStreamBasicDescription asbd;
    UInt32 propSize = sizeof(AudioStreamBasicDescription);
    asbd.mBitsPerChannel = sizeof(float) * 8;
    asbd.mBytesPerFrame = jcaStruct->numChannelsOutput * sizeof(float);
    asbd.mBytesPerPacket = asbd.mBytesPerFrame;
    asbd.mChannelsPerFrame = jcaStruct->numChannelsOutput;
    asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFramesPerPacket = 1;
    asbd.mReserved = 0;
    asbd.mSampleRate = (Float64) jsampleRate;
    AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input, 0,
        &asbd, propSize);
    
    // make sure that the expected audio format is reported
    AudioUnitGetProperty(jcaStruct->auhalOutput,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input, 0,
        &asbd, &propSize);
    if (asbd.mFormatFlags != kAudioFormatFlagsNativeFloatPacked ||
        asbd.mBitsPerChannel != 32) {
      
      // clean up
      Java_ch_section6_jcoreaudio_JCoreAudio_uninitialize(env, jclazz, (jlong) jcaStruct);
      
      // throw an IllegalStateException
      (*env)->ThrowNew(env, (*env)->FindClass(env, "java/lang/IllegalStateException"),
          "Core Audio is not reporting the expected interleaved 32-bit float audio format for the output. "
          "There is nothing that you can do. Report this error along with the audio hardware that you "
          "are using to the library maintainer.");
      return 0;
    }
    
    // set the device sample rate
    AudioObjectPropertyAddress propAddr;
    propAddr.mSelector = kAudioDevicePropertyNominalSampleRate;
    propAddr.mScope = kAudioUnitScope_Global;
    propAddr.mElement = 0;
    Float64 sampleRate = (Float64) jsampleRate;
    AudioObjectSetPropertyData(joutputDeviceId, &propAddr, 0, NULL, sizeof(Float64), &sampleRate);

    // set requested block size
    AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioDevicePropertyBufferFrameSize,
        kAudioUnitScope_Input, 0,
        &jblockSize, sizeof(UInt32));

    // now that the AUHAL is set up, initialise it
    AudioUnitInitialize(jcaStruct->auhalOutput);
  }
    
  return (jlong) jcaStruct;
}

JNIEXPORT void JNICALL Java_ch_section6_jcoreaudio_JCoreAudio_uninitialize
    (JNIEnv *env, jclass jclazz, jlong nativePtr) {

  // free all native resources
  JCoreAudioStruct *jca = (JCoreAudioStruct *) nativePtr;

  if (jca->numChannelsInput > 0) {
    for (int i = 0; i < jca->numChannelsInput; i++) {
      free(jca->channelsInput[i]);
    }
    free(jca->channelsInput);    
  }
  if (jca->numChannelsOutput > 0) {
    for (int i = 0; i < jca->numChannelsOutput; i++) {
      free(jca->channelsOutput[i]);
    }
    free(jca->channelsOutput);    
  }
      
  if (jca->auhalInput != NULL) {
    AudioUnitUninitialize(jca->auhalInput);
    AudioComponentInstanceDispose(jca->auhalInput);
  }
  if (jca->auhalOutput != NULL) {
    AudioUnitUninitialize(jca->auhalOutput);
    AudioComponentInstanceDispose(jca->auhalOutput);    
  }

  (*env)->DeleteGlobalRef(env, jca->jclazzJCoreAudio);

  free(jca);
}

JNIEXPORT void JNICALL Java_ch_section6_jcoreaudio_JCoreAudio_play
    (JNIEnv *env, jclass jclazz, jboolean shouldPlay, jlong nativePtr) {
  
  JCoreAudioStruct *jcaStruct = (JCoreAudioStruct *) nativePtr;
      
  if (shouldPlay == JNI_TRUE) {
    if (jcaStruct->auhalInput != NULL) AudioOutputUnitStart(jcaStruct->auhalInput);
    if (jcaStruct->auhalOutput != NULL) AudioOutputUnitStart(jcaStruct->auhalOutput);
  } else {
    if (jcaStruct->auhalInput != NULL) AudioOutputUnitStop(jcaStruct->auhalInput);
    if (jcaStruct->auhalOutput != NULL) AudioOutputUnitStop(jcaStruct->auhalOutput);
  }
}

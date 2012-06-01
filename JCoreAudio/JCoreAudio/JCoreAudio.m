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

JavaVM *JCoreAudio_globalJvm;
JCoreAudioStruct *jcaStruct;

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *jvm, void *reserved) {
  // require JNI_VERSION_1_4 for access to NIO functions
  // http://docs.oracle.com/javase/1.4.2/docs/guide/jni/jni-14.html
  JCoreAudio_globalJvm = jvm; // store the JVM so that it can be used to attach CoreAudio threads to the JVM during callbacks
  
  jcaStruct = (JCoreAudioStruct *) malloc(sizeof(JCoreAudioStruct));
  
  JNIEnv *env = NULL;
  (*jvm)->GetEnv(jvm, (void **) &env, JNI_VERSION_1_4);
  
  return JNI_VERSION_1_4;
}

void JNI_OnUnload(JavaVM *vm, void *reserved) {
  free(jcaStruct);
}

OSStatus inputRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
  
  JNIEnv *env = nil;
  jint res = (*JCoreAudio_globalJvm)->AttachCurrentThreadAsDaemon(JCoreAudio_globalJvm, (void **) &env, NULL);
  if (res == JNI_OK) {
    JCoreAudioStruct *jca = (JCoreAudioStruct *) inRefCon;
    
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    AudioBuffer audioBuffer;
    audioBuffer.mNumberChannels = jca->numChannelsInput;
    audioBuffer.mDataByteSize = jca->blockSize * jca->numChannelsInput * sizeof(float);
    float caBuffer[jca->blockSize * jca->numChannelsInput];
    audioBuffer.mData = caBuffer;
    bufferList.mBuffers[0] = audioBuffer;
 
    // render the input into the buffers
    AudioUnitRender(jca->auhalInput, ioActionFlags, inTimeStamp, inBusNumber,
        inNumberFrames, &bufferList);
    
    // interleave the channels to the backing buffers
    // TODO(mhroth): vectorise this like a real man, ok?
    for (int i = 0; i < jca->numChannelsInput; i++) {
      for (int j = 0, k = i; j < jca->blockSize; j++, k+=jca->numChannelsInput) {
        jca->channelsInput[i][j] = caBuffer[k];
      }
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
    AudioDeviceGetPropertyInfo(audioDeviceIds[i], 0, false,
        kAudioDevicePropertyDeviceName, &propSize, NULL);
    char strName[++propSize]; memset(strName, 0, sizeof(strName)); // ensure that string is zero terminated
    AudioDeviceGetProperty(audioDeviceIds[i], 0, false,
        kAudioDevicePropertyDeviceName, &propSize, strName);
    
    // get manufacturer string
    AudioDeviceGetPropertyInfo(audioDeviceIds[i], 0, false,
        kAudioDevicePropertyDeviceManufacturer, &propSize, NULL);
    char strManufacturer[++propSize]; memset(strManufacturer, 0, sizeof(strManufacturer));
    AudioDeviceGetProperty(audioDeviceIds[i], 0, false,
        kAudioDevicePropertyDeviceManufacturer, &propSize, strManufacturer);
    
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
  AudioDeviceGetPropertyInfo(deviceId, 0, isInput,
      kAudioDevicePropertyStreamConfiguration, &propSize, NULL);
  int numLets  = propSize/sizeof(AudioBufferList);
  AudioBufferList buffLetList[numLets];
  AudioDeviceGetProperty(deviceId, 0, isInput,
      kAudioDevicePropertyStreamConfiguration, &propSize, buffLetList);
  
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

JNIEXPORT void JNICALL Java_com_synthbot_JCoreAudio_AudioLet_queryAvailableSamplerates
    (JNIEnv *env, jclass jclazz, jint deviceId, jint letIndex, jboolean isInput, jobject jset) {
  
  jclass jclazzFloat = (*env)->FindClass(env, "java/lang/Float");
  jclass jclazzHashSet = (*env)->FindClass(env, "java/util/HashSet");
      
  UInt32 propSize = 0;
  AudioDeviceGetPropertyInfo(deviceId, letIndex, isInput,
      kAudioDevicePropertyStreamFormats, &propSize, NULL);
  int numFormats = propSize/sizeof(AudioStreamBasicDescription);
  AudioStreamBasicDescription formats[numFormats]; memset(formats, 0, propSize);
  AudioDeviceGetProperty(deviceId, letIndex, isInput,
      kAudioDevicePropertyStreamFormats, &propSize, formats);
      
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

JNIEXPORT jint JNICALL Java_com_synthbot_JCoreAudio_AudioDevice_getMinimumBufferSize
    (JNIEnv *env, jobject jobj, jint jaudioDeviceId) {

  AudioValueRange range;
  UInt32 propSize = sizeof(AudioValueRange);
  AudioDeviceGetProperty(jaudioDeviceId, 0, false,
      kAudioDevicePropertyBufferFrameSizeRange, &propSize, &range);
      
  return (jint) range.mMinimum;
}

JNIEXPORT jint JNICALL Java_com_synthbot_JCoreAudio_AudioDevice_getMaximumBufferSize
    (JNIEnv *env, jobject jobj, jint jaudioDeviceId) {
      
  AudioValueRange range;
  UInt32 propSize = sizeof(AudioValueRange);
  AudioDeviceGetProperty(jaudioDeviceId, 0, false,
      kAudioDevicePropertyBufferFrameSizeRange, &propSize, &range);

  return (jint) range.mMaximum;
}

JNIEXPORT jfloat JNICALL Java_com_synthbot_JCoreAudio_AudioDevice_getSampleRate
    (JNIEnv *env, jobject jobj, jint jaudioDeviceId) {
  
  Float64 sampleRate = 0.0;
  UInt32 propSize = sizeof(Float64);
  AudioDeviceGetProperty(jaudioDeviceId, 0, false,
      kAudioDevicePropertyNominalSampleRate, &propSize, &sampleRate);

  return (jfloat) sampleRate;
}

// file:///Users/mhroth/Library/Developer/Shared/Documentation/DocSets/com.apple.adc.documentation.AppleLion.CoreReference.docset/Contents/Resources/Documents/index.html#technotes/tn2091/_index.html
JNIEXPORT void JNICALL Java_com_synthbot_JCoreAudio_JCoreAudio_initialize
  (JNIEnv *env, jclass jclazz, jarray jinputArray, jint jnumChannelsInput, jint jinputDeviceId,
      jarray joutputArray, jint jnumChannelsOutput, jint joutputDeviceId,
      jint jblockSize, jfloat jsampleRate) {
   
  // cache these values for use during audio callbacks
  // creating these references here ensures that the same class loader is used as for the java
  // object themselves. http://forums.netbeans.org/topic8087.html
  jcaStruct->jclazzJCoreAudio = (*env)->FindClass(env, "com/synthbot/JCoreAudio/JCoreAudio");
  jcaStruct->fireOnCoreAudioInputMid = (*env)->GetStaticMethodID(env, jcaStruct->jclazzJCoreAudio,
      "fireOnCoreAudioInput", "(D)V");
  jcaStruct->fireOnCoreAudioOutputMid = (*env)->GetStaticMethodID(env, jcaStruct->jclazzJCoreAudio,
      "fireOnCoreAudioOutput", "(D)V");
    
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
  
  // http://osdir.com/ml/coreaudio-api/2009-10/msg01790.html
  // Ttell the AudioDevice to use its own runloop. This allows it to react autonomously to
  // sample rate changes.
  AudioHardwareSetProperty(kAudioHardwarePropertyRunLoop, sizeof(CFRunLoopRef), NULL);
    
  if (jinputArray != NULL) {
    // the intput set is non-empty. Configure the AUHAL to be in the graph and provide input
    
    AudioComponentInstanceNew(comp, &(jcaStruct->auhalInput)); // open the component and initialise it (10.6 and later)
    
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
    jclass jclazzAudioLet =  (*env)->FindClass(env, "com/synthbot/JCoreAudio/AudioLet");
    jcaStruct->blockSize = jblockSize;
    jcaStruct->numChannelsInput = jnumChannelsInput;
    jcaStruct->channelsInput = (float **) malloc(jnumChannelsInput * sizeof(float *));
    for (int i = 0, k = 0; i < (*env)->GetArrayLength(env, jinputArray); i++) {
      // get the number of channels in this let
      jobject objAudioLet = (*env)->GetObjectArrayElement(env, jinputArray, i);
      int numChannels = (*env)->CallIntMethod(env, objAudioLet, (*env)->GetMethodID(env, jclazzAudioLet, "getNumChannels", "()I"));
      int channelIndex = (*env)->CallIntMethod(env, objAudioLet, (*env)->GetMethodID(env, jclazzAudioLet, "getChannelIndex", "()I"));
      for (int j = 0; j < numChannels; j++, k++, channelIndex++) {
        // create the native backing buffer
        jcaStruct->channelsInput[k] = (float *) calloc(jblockSize, sizeof(float));
        
        // create a new ByteBuffer
        jobject jByteBuffer = (*env)->NewDirectByteBuffer(env, jcaStruct->channelsInput[k], jblockSize*sizeof(float));
        
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
        channelMap, jnumChannelsInput);
    
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
    AudioUnitGetProperty (jcaStruct->auhalInput,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input, 1,
        &asbd, &propSize);
    asbd.mSampleRate = (Float64) jsampleRate; // update the sample rate    
    AudioUnitSetProperty(jcaStruct->auhalInput,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Output, 1,
        &asbd, sizeof(AudioStreamBasicDescription));
    
    // set the device sample rate
    Float64 sampleRate = (Float64) jsampleRate;
    AudioDeviceSetProperty(jinputDeviceId, NULL, 0, true,
        kAudioDevicePropertyNominalSampleRate, sizeof(Float64), &sampleRate);
    
    // set requested block size
    AudioUnitSetProperty(jcaStruct->auhalInput,
        kAudioDevicePropertyBufferFrameSize,
        kAudioUnitScope_Output, 1,
        &jblockSize, sizeof(UInt32));
    
    // now that the AUHAL is set up, initialise it
    AudioUnitInitialize(jcaStruct->auhalInput);
  }

  if (joutputArray != NULL) {
    // the output set is non-empty. Configure the AUHAL to be in the graph and provide output

    AudioComponentInstanceNew(comp, &(jcaStruct->auhalOutput)); // open the component and initialise it (10.6 and later)
    
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
        kAudioUnitProperty_SetRenderCallback,
        kAudioUnitScope_Global, 0,
        &renderCallbackStruct, sizeof(AURenderCallbackStruct));
    
    // configure output device to given sample rate
    AudioStreamBasicDescription asbd;
    UInt32 propSize = sizeof(AudioStreamBasicDescription);
    AudioUnitGetProperty (jcaStruct->auhalOutput,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Output, 0,
        &asbd, &propSize);
    asbd.mSampleRate = (Float64) jsampleRate; // update the sample rate    
    AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input, 0,
        &asbd, sizeof(AudioStreamBasicDescription));
    
    // set the device sample rate
    Float64 sampleRate = (Float64) jsampleRate;
    AudioDeviceSetProperty(joutputDeviceId, NULL, 0, false,
        kAudioDevicePropertyNominalSampleRate, sizeof(Float64), &sampleRate);

    // set requested block size
    AudioUnitSetProperty(jcaStruct->auhalOutput,
        kAudioDevicePropertyBufferFrameSize,
        kAudioUnitScope_Input, 0,
        &jblockSize, sizeof(UInt32));
    
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

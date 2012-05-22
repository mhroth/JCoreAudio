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
#import "com_synthbot_JCoreAudio_JCoreAudio.h"
#import "JCoreAudio.h"

// https://developer.apple.com/library/mac/#documentation/MusicAudio/Conceptual/CoreAudioOverview/SystemAudioUnits/SystemAudioUnits.html#//apple_ref/doc/uid/TP40003577-CH8-SW2
void Java_com_synthbot_JCoreAudio_JCoreAudio_fillComponentList
    (JNIEnv *env, jclass jclazz, jobject jlist) {
  
  ComponentDescription compDesc;
  compDesc.componentType = kAudioUnitType_Output;
  compDesc.componentSubType = kAudioUnitSubType_HALOutput;
  compDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
  compDesc.componentFlags = 0;
  compDesc.componentFlagsMask = 0;
      
  jclass jclazzComponent = (*env)->FindClass(env, "com/synthbot/JCoreAudio/Component");
  jclass jclazzArrayList = (*env)->FindClass(env, "java/util/ArrayList");
      
  long numComponents = CountComponents(&compDesc);
  Component componentId = 0;
  for (long i = 0; i < numComponents; i++) {
    componentId = FindNextComponent(componentId, &compDesc);
    
    char *componentName = NULL;
    char *componentInfo = NULL;
    OSErr err = GetComponentInfo(componentId, &compDesc, &componentName, &componentInfo, NULL);
    if (err != 0) {
      // https://developer.apple.com/library/mac/#documentation/Carbon/Reference/Component_Manager/Reference/reference.html#//apple_ref/doc/uid/TP30000201
      // TODO(mhroth): this is bad
    }
    
    // create the com.synthbot.JCoreAudio.Component object
    jobject jComponent = (*env)->NewObject(env, jclazzComponent,
        (*env)->GetMethodID(env, jclazzComponent, "<init>", "(ILjava/lang/String;Ljava/lang/String;)V"),
        componentId,
        (*env)->NewStringUTF(env, componentName),
        (*env)->NewStringUTF(env, componentInfo));
    
    // add the Component object to the given List
    (*env)->CallVoidMethod(env, jlist,
        (*env)->GetMethodID(env, jclazzArrayList, "add", "(Ljava/lang/Object;)Z"),
        jComponent);
  }
}

JNIEXPORT void JNICALL Java_com_synthbot_JCoreAudio_JCoreAudio_fillAudioDeviceList
    (JNIEnv *env, jclass jclazz, jobject jlist) {
  
  jclass jclazzAudioDevice = (*env)->FindClass(env, "com/synthbot/JCoreAudio/AudioDevice");
  jclass jclazzAudioLet = (*env)->FindClass(env, "com/synthbot/JCoreAudio/AudioLet");
  jclass jclazzArrayList = (*env)->FindClass(env, "java/util/ArrayList");
  jclass jclazzHashSet = (*env)->FindClass(env, "java/util/HashSet");
      
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
    
    // get the number of input channels that this AudioDevice has 
    bool isInput = true;
    AudioDeviceGetPropertyInfo(audioDeviceIds[i], 0, isInput, kAudioDevicePropertyStreamConfiguration, &propSize, NULL);
    int numLets  = propSize/sizeof(AudioBufferList);
    AudioBufferList buffInputList[numLets];
    AudioDeviceGetProperty(audioDeviceIds[i], 0, isInput, kAudioDevicePropertyStreamConfiguration, &propSize, buffInputList);
                 
    // create a new Set of input AudioLets belonging to this AudioDevice
    jobject jInputSet = (*env)->NewObject(env, jclazzHashSet,
        (*env)->GetMethodID(env, jclazzHashSet, "<init>", "(I)V"),
        numLets);
                                          
    for (int j = 0; j < numLets; j++) {
      AudioDeviceGetPropertyInfo(audioDeviceIds[i], j, isInput, kAudioDevicePropertyChannelName, &propSize, NULL);
      char strADName[++propSize]; memset(strADName, 0, sizeof(strADName));
      AudioDeviceGetProperty(audioDeviceIds[i], j, isInput, kAudioDevicePropertyChannelName, &propSize, strADName);
      
      // create a new AudioChannel object
      jobject jAudioChannel = (*env)->NewObject(env, jclazzAudioLet,
          (*env)->GetMethodID(env, jclazzAudioLet, "<init>", "(ILjava/lang/String;ZI)V"),
          (*env)->NewStringUTF(env, strADName),
          j, isInput, buffInputList[j].mBuffers[0].mNumberChannels);
      
      // add the AudioChannel to the inputSet
      (*env)->CallVoidMethod(env, jInputSet,
          (*env)->GetMethodID(env, jclazzHashSet, "add", "(Ljava/lang/Object;)Z"),
          jAudioChannel);
    }
    
    // get the number of output channels that this AudioLet has 
    isInput = false;
    AudioDeviceGetPropertyInfo(audioDeviceIds[i], 0, isInput, kAudioDevicePropertyStreamConfiguration, &propSize, NULL);
    numLets  = propSize/sizeof(AudioBufferList);
    AudioBufferList buffOutputList[numLets];
    AudioDeviceGetProperty(audioDeviceIds[i], 0, isInput, kAudioDevicePropertyStreamConfiguration, &propSize, buffOutputList);
    
    // create a new Set of output AudioLets belonging to this AudioDevice
    jobject jOutputSet = (*env)->NewObject(env, jclazzHashSet,
        (*env)->GetMethodID(env, jclazzHashSet, "<init>", "(I)V"),
        numLets);
    
    for (int j = 0; j < numLets; j++) {
      AudioDeviceGetPropertyInfo(audioDeviceIds[i], j, isInput, kAudioDevicePropertyChannelName, &propSize, NULL);
      char strADName[++propSize]; memset(strADName, 0, sizeof(strADName));
      AudioDeviceGetProperty(audioDeviceIds[i], j, isInput, kAudioDevicePropertyChannelName, &propSize, strADName);
      
      // create a new AudioChannel object
      jobject jAudioChannel = (*env)->NewObject(env, jclazzAudioLet,
          (*env)->GetMethodID(env, jclazzAudioLet, "<init>", "(ILjava/lang/String;ZI)V"),
          (*env)->NewStringUTF(env, strADName),
          j, isInput, buffOutputList[j].mBuffers[0].mNumberChannels);
      
      // add the AudioChannel to the inputSet
      (*env)->CallVoidMethod(env, jOutputSet,
          (*env)->GetMethodID(env, jclazzHashSet, "add", "(Ljava/lang/Object;)Z"),
          jAudioChannel);
    }
    
    // create the AudioDevice object
    jobject jAudioDevice = (*env)->NewObject(env, jclazzAudioDevice,
        (*env)->GetMethodID(env, jclazzAudioDevice, "<init>", "(ILjava/lang/String;Ljava/lang/String;Ljava/util/Set;Ljava/util/Set;)V"),
        audioDeviceIds[i],
        (*env)->NewStringUTF(env, strName),
        (*env)->NewStringUTF(env, strManufacturer),
        jInputSet, jOutputSet);
    
    // add the AudioDevice object to the given List
    (*env)->CallVoidMethod(env, jlist,
        (*env)->GetMethodID(env, jclazzArrayList, "add", "(Ljava/lang/Object;)Z"),
        jAudioDevice);
  }
}

@implementation JCoreAudio

@end

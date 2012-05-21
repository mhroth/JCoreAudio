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

@implementation JCoreAudio

@end

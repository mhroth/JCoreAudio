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

package com.synthbot.JCoreAudio;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class JCoreAudio {
  
  private static CoreAudioState state;
  
  private static AudioDevice currentInputDevice;
  
  private static AudioDevice currentOutputDevice;
  
  private static Set<AudioLet> currentInputLets;
  
  private static Set<AudioLet> currentOutputLets;
 
  
  static {
    System.loadLibrary("JCoreAudio");
  }

  /**
   * Returns a <code>List</code> of all audio <code>Component</code>s available on the system.
   * These may be used to configure which channels should be activated and used as input and outputs.
   * @return A <code>List</code> of audio <code>Component</code>s.
   */
  public static List<Component> getComponentList() {
    ArrayList<Component> list = new ArrayList<Component>();
    fillComponentList(list);
    return list;
  }
  private static native void fillComponentList(List<Component> list);
  
  /**
   * Returns a <code>List</code> of available <code>AudioDevice</code>s. The audio system may
   * then be configured to use selected ones for input and output.
   * @return A <code>List</code> of available <code>AudioDevice</code>s.
   */
  public static List<AudioDevice> getAudioDeviceList() {
    ArrayList<AudioDevice> list = new ArrayList<AudioDevice>();
    fillAudioDeviceList(list);
    return list;
  }
  private static native void fillAudioDeviceList(List<AudioDevice> list);
  
  /**
   * 
   * @param inputDevice
   * @param outputDevice
   */
  public static synchronized void initialize(Set<AudioLet> inputLets, Set<AudioLet> outputLets) {
    if (state != CoreAudioState.UNINITIALIZED) {
      throw new IllegalStateException();
    }
    // TODO(mhroth): ensure that the inputLets Set contains only input lets from the same AudioDevice
    if (!verifyLetSet(inputLets)) {
      throw new IllegalArgumentException();
    }
    if (!verifyLetSet(outputLets)) {
      throw new IllegalArgumentException();
    }
    
    currentInputLets = new HashSet<AudioLet>(inputLets); // defensive copy of letset
    currentOutputLets = new HashSet<AudioLet>(outputLets);
    currentInputDevice = inputLets.iterator().next().device;
    currentOutputDevice = outputLets.iterator().next().device;
    state = CoreAudioState.INITIALIZED;
  }
  
  /**
   * Ensure that all <code>AudioLet</code>s in the set are from the same device and are all either
   * input or output.
   * @return <code>true</code> if the conditions are satisfied, <code>false</code> otherwise.
   */
  private static boolean verifyLetSet(Set<AudioLet> letset) {
    if (letset == null || letset.isEmpty()) return true;
    AudioDevice device = letset.iterator().next().device;
    boolean isInput = letset.iterator().next().isInput;
    for (AudioLet let : letset) {
      if (let.device != device || let.isInput != isInput) return false;
    }
    return true;
  }
  
  public static synchronized AudioDevice getCurrentInputDevice() {
    return currentInputDevice;
  }
  
  public static synchronized AudioDevice getCurrentOutputDevice() {
    return currentOutputDevice;
  }
  
  public static synchronized Set<AudioLet> getCurrentInputLets() {
    return new HashSet<AudioLet>(currentInputLets);
  }
  
  public static synchronized Set<AudioLet> getCurrentOutputLets() {
    return new HashSet<AudioLet>(currentOutputLets);
  }
  
  /**
   * Returns the current <code>CoreAudioState</code>.
   */
  public static CoreAudioState getState() {
    return state;
  }
  
  /**
   * Start playback.
   */
  public static synchronized void play() {
    if (state != CoreAudioState.INITIALIZED) {
      throw new IllegalStateException("JCoreAudio must be in the INITIALIZED state to start playback. " +
      		"It is currently in state " + state.name() + ".");
    }
    state = CoreAudioState.RUNNING;
    
    play(true);
  }
  private static native void play(boolean shouldPlay);
  
  /**
   * Pause playback.
   */
  public static synchronized void pause() {
    if (state != CoreAudioState.RUNNING) {
      throw new IllegalStateException("JCoreAudio must be in the RUNNING state to pause playback. " +
          "It is currently in state " + state.name() + ".");
    }
    state = CoreAudioState.INITIALIZED;
    
    play(false);
  }
  
  /**
   * Indicates if CoreAudio is currently playing.
   */
  public static synchronized boolean isPlaying() {
    return state == CoreAudioState.RUNNING;
  }
  
  /**
   * Return <code>JCoreAudio</code> to the specified state.
   */
  public static synchronized void returnToState(CoreAudioState newState) {
    if (state.ordinal() >= newState.ordinal()) return;
    switch (state) {
      case RUNNING: {
        
      }
      case INITIALIZED: {
        
      }
      default:
      case UNINITIALIZED: {
        
      }
    }
    state = newState;
  }
  
  public static void main(String[] args) {
    System.out.println("=== Component List ===");
    List<Component> componentList = JCoreAudio.getComponentList();
    for (Component c : componentList) {
      System.out.println(c.toString());
    }
    
    System.out.println();
    System.out.println("=== Audio Device List ===");
    List<AudioDevice> audioDeviceList = JCoreAudio.getAudioDeviceList();
    for (AudioDevice d : audioDeviceList) {
      System.out.println(d.toString());
    }
  }

}

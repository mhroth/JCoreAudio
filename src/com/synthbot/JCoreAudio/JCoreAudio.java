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
  
  /**
   * 
   */
  private static CoreAudioState state = CoreAudioState.UNINITIALIZED;
  
  /**
   * 
   */
  private static AudioDevice currentInputDevice;
  
  /**
   * 
   */
  private static AudioDevice currentOutputDevice;
  
  /**
   * 
   */
  private static Set<AudioLet> currentInputLets;
  
  /**
   * 
   */
  private static Set<AudioLet> currentOutputLets;
  
  /**
   * 
   */
  private static CoreAudioListener listener;
 
  
  static {
    System.loadLibrary("JCoreAudio");
  }
  
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
   * A convenience method for initializing Core Audio with default block size and sample rate.
   * Sample rate can be manually changed using the OS X Audio MIDI Setup application.
   */
  public static synchronized void initialize(Set<AudioLet> inputLets, Set<AudioLet> outputLets) {
    int defaultBlockSize = 512; // NOTE(mhroth): default for now
    float defaultSampleRate = 0.0f;
    if (inputLets != null && !inputLets.isEmpty()) {
      defaultSampleRate = inputLets.iterator().next().getAudioDevice().getCurrentSampleRate();
    } else if (outputLets != null && !outputLets.isEmpty()) {
      defaultSampleRate = outputLets.iterator().next().getAudioDevice().getCurrentSampleRate();
    }
    
    initialize(inputLets, outputLets, defaultBlockSize, defaultSampleRate);
  }
  
  /**
   * 
   * @param inputLets  A Set of AudioLets to use as input. May be <code>null</code> or an empty set.
   * @param outputLets  A Set of AudioLets to use as output. May be <code>null</code> or an empty set.
   * @param blockSize  The requested block size. It must be between the limits allowed by
   *     <code>AudioDevice.getMinimumBlockSize()</code> and <code>AudioDevice.getMaximumBlockSize()</code>.
   *     When in doubt, use <code>AudioDevice.getCurrentBufferSize()</code>.
   * @param sampleRate  The requested sample rate. It must be one of the sample rates allowed by
   *     <code>AudioDevice.getAllowedSampleRates()</code>. When in doubt, use
   *     <code>AudioDevice.getCurrentSampleRate()</code>.
   */
  public static synchronized void initialize(Set<AudioLet> inputLets, Set<AudioLet> outputLets,
      int blockSize, float sampleRate) {
    if (state != CoreAudioState.UNINITIALIZED) {
      throw new IllegalStateException();
    }
    if (!verifyLetSet(inputLets)) {
      throw new IllegalArgumentException("The input AudioLet set does not contain lets from only one AudioDevice.");
    }
    if (!verifyLetSet(outputLets)) {
      throw new IllegalArgumentException("The output AudioLet set does not contain lets from only one AudioDevice.");
    }
    if ((inputLets == null || inputLets.isEmpty()) && (outputLets == null || outputLets.isEmpty())) {
      throw new IllegalArgumentException("At least one of the input or output sets must be non-empty.");
    }
    
    int numInputChannels = 0;
    if (inputLets == null || inputLets.isEmpty()) {
      currentInputLets = null;
      currentInputDevice = null;
    } else {
      AudioDevice device = inputLets.iterator().next().device;
      if (blockSize < device.getMinimumBufferSize()) {
        throw new IllegalArgumentException("The given blocksize is less than the minimum supported amount: " +
            blockSize +  " < " + device.getMinimumBufferSize());
      }
      if (blockSize > device.getMaximumBufferSize()) {
        throw new IllegalArgumentException("The given blocksize is greater than the maximum supported amount: " +
            blockSize +  " < " + device.getMaximumBufferSize());
      }
      for (AudioLet let : inputLets) {
        if (!let.canSamplerate(sampleRate)) {
          throw new IllegalArgumentException("The requested sample rate " + sampleRate + "Hz is not supported. " +
          		"It must be one of " + let.getAvailableSamplerates().toString() + "Hz.");
        }
      }
      currentInputDevice = device;
      
      // defensive copy of letset
      currentInputLets = new HashSet<AudioLet>(inputLets);
      for (AudioLet let : currentInputLets) {
        numInputChannels += let.numChannels;
      }
    }
    
    int numOutputChannels = 0;
    if (outputLets == null || outputLets.isEmpty()) {
      currentOutputLets = null;
      currentOutputDevice = null;
    } else {
      AudioDevice device = outputLets.iterator().next().device;
      if (blockSize < device.getMinimumBufferSize()) {
        throw new IllegalArgumentException("The given blocksize is less than the minimum supported amount: " +
            blockSize +  " < " + device.getMinimumBufferSize());
      }
      if (blockSize > device.getMaximumBufferSize()) {
        throw new IllegalArgumentException("The given blocksize is greater than the maximum supported amount: " +
            blockSize +  " < " + device.getMaximumBufferSize());
      }
      for (AudioLet let : outputLets) {
        if (!let.canSamplerate(sampleRate)) {
          throw new IllegalArgumentException("The requested sample rate " + sampleRate + "Hz is not supported. " +
              "It must be one of: " + let.getAvailableSamplerates().toString());
        }
      }
      currentOutputDevice = device;
      
      currentOutputLets = new HashSet<AudioLet>(outputLets);
      for (AudioLet let : currentOutputLets) {
        numOutputChannels += let.numChannels;
      }
    }
    initialize((currentInputLets == null) ? null : currentInputLets.toArray(), numInputChannels,
        (currentInputDevice == null) ? 0 : currentInputDevice.getId(),
        (currentOutputLets == null) ? null : currentOutputLets.toArray(), numOutputChannels,
        (currentOutputDevice == null) ? 0 : currentOutputDevice.getId(),
        blockSize, sampleRate);
    
    state = CoreAudioState.INITIALIZED;
  }
  
  // it is guaranteed that at least one of the input or output sets is non-empty
  private static native void initialize(Object[] inputLetArray, int numChannelsInput, int inputAudioDeviceId,
      Object[] outputLetArray, int numChannelsOutput, int outputAudioDeviceId, int blockSize, float sampleRate);
  
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
  
  public static synchronized void uninitialize() {
    switch (state) {
      case RUNNING: {
        pause(); // allow fallthrough
      }
      case INITIALIZED: {
        _uninitialize();
        state = CoreAudioState.UNINITIALIZED;
        break;
      }
      default:
      case UNINITIALIZED: {
        // nothing to do
      }
    }
  }
  private static native void _uninitialize();
  
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
   * Indicates if CoreAudio is currently playing.
   */
  public static synchronized boolean isPlaying() {
    return state == CoreAudioState.RUNNING;
  }
  
  /**
   * Indicates if JCoreAudio is initialised. The current state may thus be INITIALIZED or RUNNING.
   */
  public static boolean isInitialized() {
    return (state == CoreAudioState.INITIALIZED || state == CoreAudioState.RUNNING);
  }
  
  /**
   * Indicates of JCoreAudio is uninitialized.
   */
  public static boolean isUninitialized() {
    return (state == CoreAudioState.UNINITIALIZED);
  }
  
  /**
   * Start or resume playback.
   */
  public static synchronized void play() {
    if (state == CoreAudioState.RUNNING) return; // already running, nothing to do
    if (state == CoreAudioState.UNINITIALIZED) {
      throw new IllegalStateException("JCoreAudio must be in the INITIALIZED state to start playback. " +
      		"It is currently UNINITIALIZED.");
    }
    state = CoreAudioState.RUNNING;
    
    play(true);
  }
  private static native void play(boolean shouldPlay);
  
  /**
   * Pause playback.
   */
  public static synchronized void pause() {
    if (state != CoreAudioState.RUNNING) return;
    state = CoreAudioState.INITIALIZED;
    
    play(false);
  }
  
  /**
   * Indicates if JCoreAudio is currently configured with an input.
   */
  public static synchronized boolean hasInput() {
    return (state.ordinal() >= CoreAudioState.INITIALIZED.ordinal()) &&  (currentInputDevice != null);
  }
  
  /**
   * Indicates if JCoreAudio is currently configured with an output.
   */
  public static synchronized boolean hasOutput() {
    return (state.ordinal() >= CoreAudioState.INITIALIZED.ordinal()) &&  (currentOutputDevice != null);
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
  
  public static synchronized void setListener(CoreAudioListener listener) {
    JCoreAudio.listener = listener;
  }
  
  public static void main(String[] args) {
    System.out.println("=== Audio Device List ===");
    List<AudioDevice> audioDeviceList = JCoreAudio.getAudioDeviceList();
    for (AudioDevice d : audioDeviceList) {
      System.out.println(d.toString());
    }
    
    JCoreAudio.setListener(new CoreAudioAdapter());
    
    Set<AudioLet> inputSet = audioDeviceList.get(0).getInputSet();
    Set<AudioLet> outputSet = audioDeviceList.get(2).getOutputSet();

    JCoreAudio.initialize(inputSet, outputSet, 512, 44100.0f);
    JCoreAudio.play();
    
    try {
      Thread.sleep(2000);
    } catch (InterruptedException e) {
      e.printStackTrace(System.err);
    }
    
    JCoreAudio.pause();
//    JCoreAudio.uninitialize();
    System.out.println("done.");
  }
  
  
  // ------ CoreAudioListener Callbacks ------
  
  private static void fireOnCoreAudioInput(double timestamp) {
    listener.onCoreAudioInput(timestamp, currentInputLets);
  }
  
  private static void fireOnCoreAudioOutput(double timestamp) {
    listener.onCoreAudioOutput(timestamp, currentOutputLets);
  }

}


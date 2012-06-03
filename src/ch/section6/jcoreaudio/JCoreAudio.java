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

package ch.section6.jcoreaudio;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * 
 * @author Martin Roth (mhroth@gmail.com)
 *
 */
public class JCoreAudio {
  
  /** The singleton instance of <code>JCoreAudio</code>. */
  public static final JCoreAudio jcoreaudio;
  
  /** The current Core Audio state. */
  private CoreAudioState state;
  
  /** The currently used input <code>AudioDevice</code>. Only valid if Core Audio is at least INITIALIZED. */
  private AudioDevice currentInputDevice;
  
  /** The currently used output <code>AudioDevice</code>. Only valid if Core Audio is at least INITIALIZED. */
  private AudioDevice currentOutputDevice;
  
  /** The currently used input <code>AudioLet</code>s. */
  private final Set<AudioLet> currentInputLets;
  
  /** The currently used output <code>AudioLet</code>s. */
  private final Set<AudioLet> currentOutputLets;
  
  /** The currently registered <code>CoreAudioListener</code>. */
  private CoreAudioListener listener;
  
  /** A reference to the native data structure belonging to this object. */
  private long nativePtr;
 
  
  static {
    System.loadLibrary("JCoreAudio");
    jcoreaudio = new JCoreAudio(); // create the singleton instance of JCoreAudio
  }
  
  private JCoreAudio() {
    state = CoreAudioState.UNINITIALIZED;
    nativePtr = 0;
    currentInputLets = new HashSet<AudioLet>();
    currentOutputLets = new HashSet<AudioLet>();
  }
  
  @Override
  protected void finalize() throws Throwable {
    try {
      // when garbage collecting this object, make sure that all native components are cleaned up
      returnToState(CoreAudioState.UNINITIALIZED);
    } finally {
      super.finalize();
    }
  }
  
  /** Returns the singleton instance of <code>JCoreAudio</code>. */
  public static JCoreAudio getInstance() {
    return jcoreaudio;
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
  public synchronized JCoreAudio initialize(Set<AudioLet> inputLets, Set<AudioLet> outputLets,
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

    int inputDeviceId = 0;
    int numInputChannels = 0;
    currentInputLets.clear();
    if (inputLets == null || inputLets.isEmpty()) {
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
      inputDeviceId = device.getId();
      
      // defensive copy of letset
      currentInputLets.addAll(inputLets);
      for (AudioLet let : currentInputLets) {
        numInputChannels += let.numChannels;
      }
    }
    
    int outputDeviceId = 0;
    int numOutputChannels = 0;
    currentOutputLets.clear();
    if (outputLets == null || outputLets.isEmpty()) {
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
      outputDeviceId = device.getId();
      
      currentOutputLets.addAll(outputLets);
      for (AudioLet let : currentOutputLets) {
        numOutputChannels += let.numChannels;
      }
    }
    nativePtr = initialize(
        currentInputLets.toArray(), numInputChannels, inputDeviceId,
        currentOutputLets.toArray(), numOutputChannels, outputDeviceId,
        blockSize, sampleRate);
    
    state = CoreAudioState.INITIALIZED;
    
    return jcoreaudio;
  }
  
  // it is guaranteed that at least one of the input or output sets is non-empty
  private static native long initialize(Object[] inputLetArray, int numChannelsInput, int inputAudioDeviceId,
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
  
  public synchronized void uninitialize() {
    switch (state) {
      case RUNNING: pause(); // allow fallthrough
      case INITIALIZED: {
        uninitialize(nativePtr);
        nativePtr = 0;
        currentInputLets.clear();
        currentOutputLets.clear();
        currentInputDevice = null;
        currentOutputDevice = null;
        state = CoreAudioState.UNINITIALIZED;
        break;
      }
      default:
      case UNINITIALIZED: break; // nothing to do
    }
  }
  private static native void uninitialize(long nativePtr);
  
  public synchronized AudioDevice getCurrentInputDevice() {
    return currentInputDevice;
  }
  
  public synchronized AudioDevice getCurrentOutputDevice() {
    return currentOutputDevice;
  }
  
  /** The currently used input <code>AudioLet</code>s. The return value is never <code>null</code>. */
  public synchronized Set<AudioLet> getCurrentInputLets() {
    return new HashSet<AudioLet>(currentInputLets);
  }
  
  /** The currently used output <code>AudioLet</code>s. The return value is never <code>null</code>. */
  public synchronized Set<AudioLet> getCurrentOutputLets() {
    return new HashSet<AudioLet>(currentOutputLets);
  }
  
  /** Returns the current <code>CoreAudioState</code>. */
  public CoreAudioState getState() {
    return state;
  }
  
  /** Indicates if CoreAudio is currently playing. */
  public synchronized boolean isPlaying() {
    return state == CoreAudioState.RUNNING;
  }
  
  /** Indicates if JCoreAudio is initialised. The current state may thus be INITIALIZED or RUNNING. */
  public boolean isInitialized() {
    return (state == CoreAudioState.INITIALIZED || state == CoreAudioState.RUNNING);
  }
  
  /** Indicates of JCoreAudio is uninitialized. */
  public boolean isUninitialized() {
    return (state == CoreAudioState.UNINITIALIZED);
  }
  
  /** Start or resume playback. */
  public synchronized void play() {
    if (state == CoreAudioState.RUNNING) return; // already running, nothing to do
    if (state == CoreAudioState.UNINITIALIZED) {
      throw new IllegalStateException("JCoreAudio must be in the INITIALIZED state to start playback. " +
      		"It is currently UNINITIALIZED.");
    }
    state = CoreAudioState.RUNNING;
    
    play(true, nativePtr);
  }
  private static native void play(boolean shouldPlay, long ptr);
  
  /** Pause playback. */
  public synchronized void pause() {
    if (state != CoreAudioState.RUNNING) return;
    state = CoreAudioState.INITIALIZED;
    
    play(false, nativePtr);
  }
  
  /** Indicates if JCoreAudio is currently configured with an input. */
  public synchronized boolean hasInput() {
    return (state.ordinal() >= CoreAudioState.INITIALIZED.ordinal()) &&  (currentInputDevice != null);
  }
  
  /** Indicates if JCoreAudio is currently configured with an output. */
  public synchronized boolean hasOutput() {
    return (state.ordinal() >= CoreAudioState.INITIALIZED.ordinal()) &&  (currentOutputDevice != null);
  }
  
  /** Return <code>JCoreAudio</code> to the specified state. */
  public synchronized void returnToState(CoreAudioState newState) {
    if (state.ordinal() <= newState.ordinal()) return;
    switch (state) {
      case RUNNING: {
        pause();
        if (newState == CoreAudioState.INITIALIZED) break;
        // allow fallthrough
      }
      case INITIALIZED: uninitialize(); // allow fallthrough
      default:
      case UNINITIALIZED: break;
    }
    state = newState;
  }
  
  public synchronized void setListener(CoreAudioListener listener) {
    this.listener = listener;
  }
  
  
  // ------ CoreAudioListener Callbacks ------
  
  private static void fireOnCoreAudioInput(double timestamp) {
    jcoreaudio.listener.onCoreAudioInput(timestamp, jcoreaudio.currentInputLets);
  }
  
  private static void fireOnCoreAudioOutput(double timestamp) {
    jcoreaudio.listener.onCoreAudioOutput(timestamp, jcoreaudio.currentOutputLets);
  }

}


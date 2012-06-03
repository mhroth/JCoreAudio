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

import java.util.HashSet;
import java.util.Set;

/**
 * An <code>AudioDevice</code> represents a system device capable of processing audio, either
 * as an input, an output, or both.
 * @author Martin Roth (mhroth@gmail.com)
 */
public class AudioDevice {
  
  /** The name of this device. */
  public final String name;
  
  /** The name of the manufacturer of this device. */
  public final String manufacturer;

  /** The system-assigned identifier of this device. */
  public final int id;
  
  private final Set<AudioLet> inputLetSet;
  
  private final Set<AudioLet> outputLetSet;
  
  private AudioDevice(int id, String name, String manufacturer) {
    this.id = id;
    this.name = name;
    this.manufacturer = manufacturer;
    
    this.inputLetSet = new HashSet<AudioLet>();
    queryLetSet(this, id, true, inputLetSet);
    
    this.outputLetSet = new HashSet<AudioLet>();
    queryLetSet(this, id, false, outputLetSet);
  }
  
  private static native void queryLetSet(AudioDevice device, int deviceId, boolean isInput,
      Set<AudioLet> set);
  
  public int getId() {
    return id;
  }
  
  public String getName() {
    return name;
  }
  
  public String getManufacturer() {
    return manufacturer;
  }
  
  /**
   * Returns the set of input <code>AudioLet</code>s of this device. If no inputs exist,
   * the <code>Set</code> is empty.
   */
  public Set<AudioLet> getInputSet() {
    // return a defensive copy of the inputLetSet
    return new HashSet<AudioLet>(inputLetSet);
  }
  
  /**
   * Returns the set of output <code>AudioLet</code>s of this device. If no outputs exist,
   * the <code>Set</code> is empty.
   */
  public Set<AudioLet> getOutputSet() {
    return new HashSet<AudioLet>(outputLetSet);
  }
  
  /** Returns the current buffer size of this device. */
  public int getCurrentBufferSize() {
    return getCurrentBufferSize(id);
  }
  private native static int getCurrentBufferSize(int id);
  
  /** Returns the minimum buffer size of this device. */
  public int getMinimumBufferSize() {
    return getMinimumBufferSize(id);
  }
  private static native int getMinimumBufferSize(int audioDeviceId);
  
  /** Returns the maximum buffer size of this device. */
  public int getMaximumBufferSize() {
    return getMaximumBufferSize(id);
  }
  private static native int getMaximumBufferSize(int audioDeviceid);
  
  /**
   * Returns the current sample rate of this <code>AudioDevice</code>. This can be changed manually
   * by using the OS X Audio MIDI Setup application.
   */
  public float getCurrentSampleRate() {
    return getSampleRate(id);
  }
  private static native float getSampleRate(int id);
  
  @Override
  public String toString() {
    return "Audio Device " + id + ": " + name + " by " + manufacturer + ".";
  }
  
  @Override
  public boolean equals(Object o) {
    if (o == null) return false;
    if (o instanceof AudioDevice) {
      AudioDevice d = (AudioDevice) o;
      return d.id == this.id;
    } else return false;
  }
  
  @Override
  public int hashCode() {
    return id;
  }
}


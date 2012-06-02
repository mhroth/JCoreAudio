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

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.HashSet;
import java.util.Set;

/**
 * An <code>AudioLet</code> represents an individual audio input or output. Each i/o has a number
 * of channels associated with it, usually one (mono) or two (stereo).
 * @author Martin Roth (mhroth@gmail.com)
 */
public class AudioLet {
  
  /**
   * The {@link AudioDevice} that this <code>AudioLet</code> belongs to.
   */
  public final AudioDevice device;
  
  /**
   * The system-assigned index of this <code>AudioLet</code>. Only used for internal tracking.
   */
  private final int index;
  
  /**
   * The index of the first channel in this let. Used for configuring the channel map.
   */
  private final int channelIndex;
  
  /**
   * The name of this let. It may be that the let has no name, in which case an empty
   * <code>String</code> is returned.
   */
  public final String name;
  
  /**
   * If this let is an input or output.
   */
  public final boolean isInput;
  
  /**
   * The number of channels associated with this let.
   */
  public final int numChannels;
  
  private final Set<Float> availableSamplerates;
  
  private FloatBuffer[] buffers;
  
  private AudioLet(AudioDevice device, int index, int channelIndex, String name, boolean isInput, int numChannels) {
    this.device = device;
    this.index = index;
    this.channelIndex = channelIndex;
    this.name = (name == null) ? "" : name;
    this.isInput = isInput;
    this.numChannels = numChannels;
    buffers = new FloatBuffer[numChannels];
    
    availableSamplerates = new HashSet<Float>();
    queryAvailableSamplerates(device.getId(), index, isInput, availableSamplerates);
  }
  
  private static native void queryAvailableSamplerates(int deviceId, int letIndex, boolean isInput,
      Set<Float> formats);
  
  public String getName() {
    return name;
  }
  
  public boolean isInput() {
    return isInput;
  }
  
  public AudioDevice getAudioDevice() {
    return device;
  }
  
  /**
   * Indicates the number of channels represented by this let. It is usually one (mono) or two
   * (stereo), though it may be more. It is never zero.
   */
  public int getNumChannels() {
    return numChannels;
  }
  
  public FloatBuffer getChannelBuffer(int channelIndex) {
    return buffers[channelIndex];
  }
  
  private void setChannelBuffer(int channelIndex, ByteBuffer buffer) {
    // set the endianness of the ByteBuffer, otherwise the samples are not correctly represented
    buffers[channelIndex] = buffer.order(ByteOrder.nativeOrder()).asFloatBuffer();
  }
  
  private int getChannelIndex() {
    return channelIndex;
  }
  
  public Set<Float> getAvailableSamplerates() {
    return new HashSet<Float>(availableSamplerates);
  }
  
  /**
   * Returns <code>true</code> if the <code>AudioDevice</code> supportes the given sample rate.
   * Otherwise <code>false</code>.
   */
  public boolean canSamplerate(float samplerate) {
    return availableSamplerates.contains(new Float(samplerate)); 
  }

  @Override
  public String toString() {
    return "AudioLet " + name + " : " + 
        ((numChannels == 1) ? "mono " : (numChannels == 2) ? "stereo " : numChannels + " ") + 
        (isInput ? "input" : "output") + ".";
  }
  
  @Override
  public boolean equals(Object o) {
    if (o == null) return false;
    if (o instanceof AudioLet) {
      AudioLet l = (AudioLet) o;
      return (l.device.getId() == device.getId()) && (l.index == this.index) && (l.isInput == this.isInput);
    } else return false;
  }
  
  @Override
  public int hashCode() {
    // TODO(mhroth): use a correct hash code
    return (isInput ? 1 : -1) * (index+1);
  }

}

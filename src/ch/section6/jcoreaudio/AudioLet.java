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
 * of channels associated with it, usually one (mono) or two (stereo). Core Audio also refers to
 * this as a <i>stream</i>.
 * @author Martin Roth (mhroth@gmail.com)
 */
public class AudioLet {
  
  /** The {@link AudioDevice} that this <code>AudioLet</code> belongs to. */
  public final AudioDevice device;
  
  /** The system-assigned index of this <code>AudioLet</code>. Only used for internal tracking. */
  private final int index;
  
  /** The index of the first channel in this let. Used for configuring the channel map. */
  private final int channelIndex;
  
  /**
   * The name of this let. It may be that the let has no name, in which case an empty
   * <code>String</code> is returned.
   */
  public final String name;
  
  /** If this let is an input or output. */
  public final boolean isInput;
  
  /** The number of channels associated with this let. */
  public final int numChannels;
  
  private final Set<Float> availableSamplerates;
  
  /** An array containing this let's buffers. */
  private ByteBuffer[] byteBuffers;
  
  /** An array containing this let's buffers, represented as <code>FloatBuffer</code>s. */
  private FloatBuffer[] floatBuffers;
  
  private AudioLet(AudioDevice device, int index, int channelIndex, String name, boolean isInput, int numChannels) {
    this.device = device;
    this.index = index;
    this.channelIndex = channelIndex;
    this.name = (name == null) ? "" : name;
    this.isInput = isInput;
    this.numChannels = numChannels;
    floatBuffers = new FloatBuffer[numChannels];
    byteBuffers = new ByteBuffer[numChannels];
    
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
  
  /** Returns the {@link AudioDevice} to which this <code>AudioLet</code> is associated. */
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
  
  /**
   * Returns the <code>ByteBuffer</code> containing samples for the given channel index.
   * Note that the underlying bytes represent 32-bit <code>float</code>s.
   */
  public ByteBuffer getChannelByteBuffer(int channelIndex) {
    return byteBuffers[channelIndex];
  }
  
  /** Returns the <code>FloatBuffer</code> containing samples for the given channel index. */
  public FloatBuffer getChannelFloatBuffer(int channelIndex) {
    return floatBuffers[channelIndex];
  }
  
  private void setChannelBuffer(int channelIndex, ByteBuffer buffer) {
    // set the endianness of the ByteBuffer, otherwise the samples are not correctly represented
    byteBuffers[channelIndex] = buffer.order(ByteOrder.nativeOrder());
    floatBuffers[channelIndex] = byteBuffers[channelIndex].asFloatBuffer();
  }
  
  /** Returns the index of the first channel in this let. Used for configuring the channel map. */
  private int getChannelIndex() {
    return channelIndex;
  }
  
  public Set<Float> getAvailableSamplerates() {
    return new HashSet<Float>(availableSamplerates);
  }
  
  /**
   * Returns <code>true</code> if the <code>AudioDevice</code> supports the given sample rate.
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
      return (l.device.getId() == device.getId()) && (l.index == this.index) &&
          (l.isInput == this.isInput);
    } else return false;
  }
  
  @Override
  public int hashCode() {
    // NOTE(mhroth): this hash will work as long as devices have less than 64 lets
    return (isInput ? 1 : -1) * (64*device.getId() + index+1);
  }

}

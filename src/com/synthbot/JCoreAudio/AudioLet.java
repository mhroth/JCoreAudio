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
  
  private final Set<AudioFormat> availableFormats;
  
  private AudioLet(AudioDevice device, int index, String name, boolean isInput, int numChannels) {
    this.device = device;
    this.index = index;
    this.name = (name == null) ? "" : name;
    this.isInput = isInput;
    this.numChannels = numChannels;
    
    availableFormats = new HashSet<AudioFormat>();
    queryAvailableFormats(device.getId(), index, isInput, availableFormats);
  }
  
  private static native void queryAvailableFormats(int deviceId, int letIndex, boolean isInput,
      Set<AudioFormat> formats);
  
  /**
   * Returns a set of <code>AudioFormat</code>s for which this <code>AudioLet</code> can be
   * configured.
   */
  public Set<AudioFormat> getAvailableFomats() {
    return new HashSet<AudioFormat>(availableFormats);
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

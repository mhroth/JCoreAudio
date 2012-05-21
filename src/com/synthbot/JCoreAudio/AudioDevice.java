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

/**
 * 
 * @author Martin Roth (mhroth@gmail.com)
 */
public class AudioDevice {
  
  /**
   * 
   */
  public final boolean isInput;
  
  /**
   * 
   */
  public final String name;
  
  /**
   * 
   */
  public final int numChannels;

  /**
   * 
   */
  public final int id;
  
  private AudioDevice(int id, String name, boolean isInput, int numChannels) {
    this.id = id;
    this.name = name;
    this.isInput = isInput;
    this.numChannels = numChannels;
  }
  
  @Override
  public String toString() {
    return "Audio Device " + id + ": " + name + " - " + (isInput ? "input" : "output") + " -> "
        + numChannels + " channels";
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


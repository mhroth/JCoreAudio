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
 * An <code>AudioDevice</code> represents a system device capable of processing audio, either
 * as an input, an output, or both.
 * @author Martin Roth (mhroth@gmail.com)
 */
public class AudioDevice {
  
  /**
   * The name of this device.
   */
  public final String name;
  
  /**
   * The name of the manufacturer of this device.
   */
  public final String manufacturer;

  /**
   * The system-assigned id of this device.
   */
  private final int id;
  
  private final Set<AudioLet> inputLetSet;
  
  private final Set<AudioLet> outputLetSet;
  
  private AudioDevice(int id, String name, String manufacturer,
      Set<AudioLet> inputLetSet, Set<AudioLet> outputLetSet) {
    this.id = id;
    this.name = name;
    this.manufacturer = manufacturer;
    this.inputLetSet = inputLetSet;
    this.outputLetSet = outputLetSet;
  }
  
  /**
   * @return The set of input <code>AudioLet</code>s of this device.
   */
  public Set<AudioLet> getInputSet() {
    // return a defensive copy of the inputLetSet
    return new HashSet<AudioLet>(inputLetSet);
  }
  
  /**
   * @return The set of output <code>AudioLet</code>s of this device.
   */
  public Set<AudioLet> getOutputSet() {
    return new HashSet<AudioLet>(outputLetSet);
  }
  
  /**
   * For debug only.
   */
  @Deprecated
  public void printChannels() {
    for (AudioLet c : inputLetSet) {
      System.out.println(c.toString());
    }
    for (AudioLet c : outputLetSet) {
      System.out.println(c.toString());
    }
  }
  
  @Override
  public String toString() {
    printChannels();
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


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

public class AudioFormat {
  
  public final int sampleRate;
  
  public final int bitDepth;
  
  private AudioFormat(int sampleRate, int bitDepth) {
    this.sampleRate = sampleRate;
    this.bitDepth = bitDepth;
    
    System.out.println(toString());
  }
  
  @Override
  public String toString() {
    return bitDepth + "bits @ " + sampleRate + "Hz";
  }

}

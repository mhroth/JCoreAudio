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

import java.nio.FloatBuffer;
import java.util.Set;

@Deprecated
public class CoreAudioAdapter implements CoreAudioListener {
  
  private long idx = 0;
  
  @Override
  public void onCoreAudioInput(double timestamp, Set<AudioLet> inputLets) {
    // nothing to do
  }

  @Override
  public void onCoreAudioOutput(double timestamp, Set<AudioLet> outputLets) {
    // plays a 440Hz tone
    int blockSize = 0;
    AudioLet let = outputLets.iterator().next();
    for (int i = 0; i < let.numChannels; i++) {
      FloatBuffer buffer = let.getChannelBuffer(i);
      buffer.rewind();
      blockSize = buffer.capacity();
      long toIdx = idx + blockSize;
      for (long j = idx; j < toIdx; j++) { // buffer.getCapacity()
        buffer.put((float) Math.sin(2.0 * Math.PI * j * 440.0 / 44100.0));
      }
    }
    idx += blockSize;
  }
}

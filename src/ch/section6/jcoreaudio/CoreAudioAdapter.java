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

/**
 * <code>CoreAudioAdapter</code> implements default methods for the <code>CoreAudioListener</code>.
 * @author Martin Roth (mhroth@gmail.com)
 */
@SuppressWarnings("unused")
public class CoreAudioAdapter implements CoreAudioListener {

  @Override
  public void onCoreAudioInput(double timestamp, Set<AudioLet> inputLets) {
    // nothing to do
  }

  @Override
  public void onCoreAudioOutput(double timestamp, Set<AudioLet> outputLets) {
    // nothing to do
  }
}

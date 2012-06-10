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

import java.util.Set;

public interface CoreAudioListener {
   
  /**
   * This callback is called when new audio input is available.
   * @param timestamp  The time in samples at the beginning of the block.
   * @param inputLets  The set of input AudioLets with which Core Audio was initialized.
   */
  public void onCoreAudioInput(double timestamp, Set<AudioLet> inputLets);
  
  /**
   * This callback is called when new audio output is required.
   * @param timestamp  The time in samples at the beginning of the block.
   * @param outputLets  The set of output AudioLets with which Core Audio was initialized.
   */
  public void onCoreAudioOutput(double timestamp, Set<AudioLet> outputLets);

}

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
 * <code>CoreAudioState</code> describes the current state of CoreAudio.
 * @author Martin Roth (mhroth@gmail.com)
 */
public enum CoreAudioState {
  
  /**
   * CoreAudio is as yet uninitialised.
   */
  UNINITIALIZED,
  
  /**
   * CoreAudio is initialised and configured with an input and/or output <code>AudioDevice</code>.
   */
  INITIALIZED,
  
  /**
   * CoreAudio is running and providing IO callbacks.
   */
  RUNNING
}

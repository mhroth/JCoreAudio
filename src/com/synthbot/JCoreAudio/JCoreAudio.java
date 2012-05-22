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

import java.util.ArrayList;
import java.util.List;

public class JCoreAudio {
  
  static {
    System.loadLibrary("JCoreAudio");
  }
  
  /**
   * Returns a <code>List</code> of all audio <code>Component</code>s available on the system.
   * These may be used to configure which channels should be activated and used as input and outputs.
   * @return A <code>List</code> of audio <code>Component</code>s.
   */
  public static List<Component> getComponentList() {
    ArrayList<Component> list = new ArrayList<Component>();
    fillComponentList(list);
    return list;
  }
  private static native void fillComponentList(List<Component> list);
  
  /**
   * Returns a <code>List</code> of available <code>AudioDevice</code>s. The audio system may
   * then be configured to use selected ones for input and output.
   * @return A <code>List</code> of available <code>AudioDevice</code>s.
   */
  public static List<AudioDevice> getAudioDeviceList() {
    ArrayList<AudioDevice> list = new ArrayList<AudioDevice>();
    fillAudioDeviceList(list);
    return list;
  }
  private static native void fillAudioDeviceList(List<AudioDevice> list);
  
  public static void main(String[] args) {
    System.out.println("=== Component List ===");
    List<Component> componentList = JCoreAudio.getComponentList();
    for (Component c : componentList) {
      System.out.println(c.toString());
    }
    
    System.out.println();
    System.out.println("=== Audio Device List ===");
    List<AudioDevice> audioDeviceList = JCoreAudio.getAudioDeviceList();
    for (AudioDevice d : audioDeviceList) {
      System.out.println(d.toString());
    }
  }

}

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
 * Describes a media <code>Component</code>, in this case audio, provided by OS X.
 * @author Martin Roth (mhroth@gmail.com)
 */
public class Component {
  
  /**
   * The <code>Component</code>'s name.
   */
  public final String name;
  
  /**
   * The <code>Component</code>'s information string.
   */
  public final String info;
  
  /**
   * The <code>Component</code>'s identification number.
   */
  public final int id; 
  
  // The constructor is private as these objects are only created by the package.
  private Component(int id, String name, String info) {
    this.id = id;
    this.name = name;
    this.info = info;
  }
  
  @Override
  public String toString() {
    return "Component " + id + ": " + name + " - " + info;
  }
  
  @Override
  public boolean equals(Object o) {
    if (o == null) return false;
    if (o instanceof Component) {
      Component c = (Component) o;
      return c.id == this.id;
    } else return false;
  }
  
  @Override
  public int hashCode() {
    return id;
  }
}


# JCoreAudio
JCoreAudio (JCA) is a Java interface to Apple's OS X 10.6+ [Core Audio](http://developer.apple.com/library/ios/#documentation/MusicAudio/Conceptual/CoreAudioOverview/Introduction/Introduction.html) API. It provides low-latecy (< 10ms) input and output access to the available audio hardware, replacing the need to use the outdated and slow Java Sound API. This project is related to:
* [JAsioHost](https://github.com/mhroth/jasiohost): a low-latency interface to ASIO on Windows
* [FrogDisco](https://github.com/mhroth/FrogDisco): a low-latency interface to Core Audio with a simpler API


## Getting Started

JCA comes in two parts, [JCoreAudio.jar]() and [libJCoreAudio.jnilib](). The former is the usual encapsulation of the classes comprising the JCA Java library, and the latter is the JNI interface to Core Audio. The package of JCA is `ch.section6.jcoreaudio`.

The library can be quickly tested from the root directory of the project with `java -jar JCoreAudio.jar -Djava.library.path=./`. You should hear a two second 440Hz tone.

+ Include `JCoreAudio.jar` in your Java project.
+ Make `libJCoreAudio.jnilib` available to your project. This can be done in several ways:
  + Move or copy the library to `/Library/Java/Extensions`. This is the default search location for JNI libraries.
  + Inform the JVM where the library is located. This can be done with, e.g. `java -Djava.library.path=/Library/Java/Extensions`

If the JVM cannot find the dylib, an [UnsatisfiedLinkError](http://docs.oracle.com/javase/1.4.2/docs/api/java/lang/UnsatisfiedLinkError.html) exception will be thrown.


## Example
This example shows how to configure JCoreAudio and receive audio callbacks. It is a synopsis of the code found in [ExampleJca](https://github.com/section6/JCoreAudio/blob/master/src/ch/section6/jcoreaudio/ExampleJca.java).

```Java
/*
 * Obtain a list of all audio devices attached to this system.
 * Printing this list looks something like this on a typical MacBook Pro:
 *
 * Audio Device 51: Built-in Microphone by Apple Inc.
 * Audio Device 42: Built-in Input by Apple Inc.
 * Audio Device 34: Built-in Output by Apple Inc.
 */
List<AudioDevice> audioDeviceList = JCoreAudio.getAudioDeviceList();

// Assemble a set of input/output lets (collections of channels) to provide input and output.
// Some lets are mono (one audio channel), and some are stereo (two channels), but any number
// is possible.
Set<AudioLet> inputSet = audioDeviceList.get(0).getInputSet();
Set<AudioLet> outputSet = audioDeviceList.get(2).getOutputSet();

// Configure JCoreAudio with the input and output let sets (one or the other may also be null.
// A block size of 512 is used, along with the current sample rate. The current sample rate is
// the same as that reported by the Audio MIDI Setup application.
JCoreAudio.getInstance().initialize(
    inputSet, outputSet,
    outputDevice.getCurrentBufferSize(),
    outputDevice.getCurrentSampleRate());
    
// set the callback listener
// a listener MUST be registered before play() is called.
JCoreAudio.getInstance().setListener(new CoreAudioListener() {
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
      for (long j = idx; j < toIdx; j++) {
        buffer.put((float) Math.sin(2.0 * Math.PI * j * 440.0 / 44100.0));
      }
    }
    idx += blockSize;
  }
});

// start playing
JCoreAudio.getInstance().play();

// ...for two seconds
try {
  Thread.sleep(2000);
} catch (InterruptedException e) {
  e.printStackTrace(System.err);
}
    
// shut everything down again
// note that it is also possible to refer to the singleton instance of JCoreAudio directly
JCoreAudio.jcoreaudio.returnToState(CoreAudioState.UNINITIALIZED);
```

## License
JCoreAudio is licensed under a modified [LGPL](http://www.gnu.org/licenses/lgpl.html) with a **non-commercial** clause, in the spirit of the [Creative Commons Attribution-NonCommercial (CC BY-NC)](http://creativecommons.org/licenses/by-nc/3.0/) license. Anyone wishing to use JCoreAudio commercially should contact me directly.
# JCoreAudio
JCoreAudio is a Java interface to Apple's [Core Audio](http://developer.apple.com/library/ios/#documentation/MusicAudio/Conceptual/CoreAudioOverview/Introduction/Introduction.html) API. It provides low-latecy (< 10ms) input and output access to the available audio hardware, replacing the need to use the outdated and slow Java Sound API. This project is related to:
* [JAsioHost](https://github.com/mhroth/jasiohost): a low-latency interface to ASIO on Windows
* [FrogDisco](https://github.com/mhroth/FrogDisco): a low-latency interface to Core Audio with a simpler API

## Getting Started
```Java
AudioDevice outputDevice = audioDeviceList.get(2);
Set<AudioLet> inputSet = audioDeviceList.get(0).getInputSet();
Set<AudioLet> outputSet = outputDevice.getOutputSet();
    
JCoreAudio.getInstance().initialize(inputSet, outputSet, 512,
    outputDevice.getCurrentSampleRate());
    
// set the callback listener
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
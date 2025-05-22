#include "PluginProcessor.h"

OSCStreamingAudioProcessor::OSCStreamingAudioProcessor()
    : AudioProcessor(BusesProperties()
        .withInput("Input", juce::AudioChannelSet::stereo(), true)
        .withOutput("Output", juce::AudioChannelSet::stereo(), true))
{
    if (!oscSender.connect("127.0.0.1", 9001)) {
        DBG("OSC connection error");
    }
}

OSCStreamingAudioProcessor::~OSCStreamingAudioProcessor() {}

void OSCStreamingAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock) {
    juce::ignoreUnused(sampleRate, samplesPerBlock);
}

void OSCStreamingAudioProcessor::releaseResources() {}

void OSCStreamingAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&) {
    juce::ScopedNoDenormals noDenormals;

    // Audio passthrough
    for (int ch = 0; ch < getTotalNumInputChannels(); ++ch) {
        buffer.copyFrom(ch, 0, buffer, ch, 0, buffer.getNumSamples());
    }

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // We build the packet
    juce::OSCMessage msg("/waveform");
    msg.addInt32(numChannels);
    msg.addInt32(numSamples);

    for (int ch = 0; ch < numChannels; ++ch) {
        auto* samples = buffer.getReadPointer(ch);
        for (int i = 0; i < numSamples; ++i) {
            msg.addFloat32(samples[i]);
        }
    }

    // and send it
    oscSender.send(msg);
}

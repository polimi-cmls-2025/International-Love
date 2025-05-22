#pragma once
#include <JuceHeader.h>
#include "PluginProcessor.h"

class OSCStreamingAudioProcessorEditor : public juce::AudioProcessorEditor
{
public:
    OSCStreamingAudioProcessorEditor(OSCStreamingAudioProcessor& p)
        : AudioProcessorEditor(&p), processor(p)
    {
        setSize(400, 200);
    }

    void paint(juce::Graphics& g) override {
        g.fillAll(juce::Colours::black);
        g.setColour(juce::Colours::white);
        g.setFont(15.0f);
        g.drawText("OSC Audio Stream Plugin", getLocalBounds(), juce::Justification::centred, true);
    }

    void resized() override {}

private:
    OSCStreamingAudioProcessor& processor;
};

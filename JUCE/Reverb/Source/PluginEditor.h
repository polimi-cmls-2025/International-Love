#pragma once
#include <JuceHeader.h>
#include "PluginProcessor.h"

class SimpleReverbAudioProcessorEditor : public juce::AudioProcessorEditor
{
public:
    SimpleReverbAudioProcessorEditor(SimpleReverbAudioProcessor&);
    ~SimpleReverbAudioProcessorEditor() override = default;

    void paint(juce::Graphics&) override;
    void resized() override;

private:
    SimpleReverbAudioProcessor& audioProcessor;
    juce::Slider wetSlider;
    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> wetSliderAttachment;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SimpleReverbAudioProcessorEditor)
};
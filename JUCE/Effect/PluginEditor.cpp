#include "PluginEditor.h"

SimpleReverbAudioProcessorEditor::SimpleReverbAudioProcessorEditor(SimpleReverbAudioProcessor& p)
    : AudioProcessorEditor(&p), audioProcessor(p)
{
    wetSlider.setSliderStyle(juce::Slider::Rotary);
    wetSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 100, 20);
    addAndMakeVisible(wetSlider);

    wetSliderAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(audioProcessor.apvts, "WET", wetSlider);

    setSize(200, 200);
}

void SimpleReverbAudioProcessorEditor::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colours::black);
    g.setColour(juce::Colours::white);
    g.setFont(15.0f);
    g.drawFittedText("Simple Reverb", getLocalBounds(), juce::Justification::centred, 1);
}

void SimpleReverbAudioProcessorEditor::resized()
{
    wetSlider.setBounds(50, 50, 100, 100);
}
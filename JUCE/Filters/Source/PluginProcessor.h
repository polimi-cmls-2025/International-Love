#pragma once

#include <JuceHeader.h>

class FiltersAudioProcessor :
    public juce::AudioProcessor,
    public juce::OSCReceiver,
    private juce::OSCReceiver::Listener<juce::OSCReceiver::MessageLoopCallback>
{
public:
    FiltersAudioProcessor();
    ~FiltersAudioProcessor() override;

    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override { return nullptr; }
    bool hasEditor() const override                    { return false; }

    const juce::String getName() const override        { return JucePlugin_Name; }

    double getTailLengthSeconds() const override       { return 0.0; }

    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;

    int getNumPrograms() override                      { return 1; }
    int getCurrentProgram() override                   { return 0; }
    void setCurrentProgram (int index) override        {}
    const juce::String getProgramName (int index) override  { return {}; }
    void changeProgramName (int index, const juce::String& newName) override {}

    void getStateInformation (juce::MemoryBlock& destData) override {}
    void setStateInformation (const void* data, int sizeInBytes) override {}
    
    bool acceptsMidi() const override { return false; }
    bool producesMidi() const override { return false; }
    bool isMidiEffect() const override { return false; }

private:
    void oscMessageReceived(const juce::OSCMessage& message) override;

    enum FilterType { LPF, HPF, BPF, NOTCH, NUM_TYPES };
    std::array<bool, NUM_TYPES> activeFilters { false, false, false, false };
    // Filter state initialization
    std::array<float, NUM_TYPES> cutoffHz { 1000.0f, 1000.0f, 1000.0f, 1000.0f };
    // Filter freqs initialization

    // Separate filters for the 2 channels to avoid artifacts
    static constexpr int NUM_CHANNELS = 2;
    std::array<std::array<juce::dsp::StateVariableTPTFilter<float>, NUM_TYPES>, NUM_CHANNELS> filters;
    juce::dsp::ProcessSpec spec;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (FiltersAudioProcessor)
};

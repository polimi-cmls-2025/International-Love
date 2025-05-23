#include "PluginProcessor.h"
#include <algorithm>

FilterPluginAudioProcessor::FilterPluginAudioProcessor()
{
    this->OSCReceiver::connect(9001);
    this->OSCReceiver::addListener(this);

    // We initialize all filters as lowpass by default
    for (int ch = 0; ch < NUM_CHANNELS; ++ch)
    {
        for (auto& filter : filters[ch])
            filter.setType(juce::dsp::StateVariableTPTFilterType::lowpass);
    }
}

FilterPluginAudioProcessor::~FilterPluginAudioProcessor()
{
    this->OSCReceiver::removeListener(this);
    this->OSCReceiver::disconnect();
}

void FilterPluginAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock)
{
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = samplesPerBlock;
    spec.numChannels = 1; // Each filter process 1 chanel at a time to avoid artifacts
    
    // Prepare all filters
    for (int ch = 0; ch < NUM_CHANNELS; ++ch)
    {
        for (auto& filter : filters[ch])
            filter.prepare(spec);
    }
}

void FilterPluginAudioProcessor::releaseResources()
{
    // Reset all filters
    for (int ch = 0; ch < NUM_CHANNELS; ++ch)
    {
        for (auto& filter : filters[ch])
            filter.reset();
    }
}

bool FilterPluginAudioProcessor::isBusesLayoutSupported(const BusesLayout& layouts) const
{
    // Only stereo audio
    return layouts.getMainInputChannelSet() == juce::AudioChannelSet::stereo()
        && layouts.getMainOutputChannelSet() == juce::AudioChannelSet::stereo();
}

void FilterPluginAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&)
{
    juce::ScopedNoDenormals noDenormals;
    
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    int activeCount = std::count(activeFilters.begin(), activeFilters.end(), true);
    if (activeCount == 0)
        return; // No filter active

    // Chanel wise filter elaboration
    for (int ch = 0; ch < numChannels && ch < NUM_CHANNELS; ++ch)
    {
        // Create an audio block for the current channel
        auto* channelData = buffer.getWritePointer(ch);
        juce::dsp::AudioBlock<float> channelBlock(&channelData, 1, numSamples);
        
        // Apply every active filter to the current channel
        for (int i = 0; i < NUM_TYPES; ++i)
        {
            if (activeFilters[i])
            {
                if (i == NOTCH)
                {
                    float centerFreq = cutoffHz[i]; // This will be the center frequency of our notch
                    float lowCutoff = centerFreq - (bandwidth * 0.5f); // high and low frequencies calculated as a percentage of the cufott, this ensures that the notch lenght varies with the cutoff to be more perceptually accurate
                    float highCutoff = centerFreq + (bandwidth * 0.5f);
                    
                    // We make sure the frequencies are valid
                    lowCutoff = std::max(20.0f, lowCutoff);
                    highCutoff = std::min(20000.0f, highCutoff);
                    
                    filters[ch][LPF].setCutoffFrequency(lowCutoff);
                    filters[ch][LPF].setType(juce::dsp::StateVariableTPTFilterType::lowpass);
                    filters[ch][LPF].process(juce::dsp::ProcessContextReplacing<float>(channelBlock));

                    filters[ch][HPF].setCutoffFrequency(highCutoff);
                    filters[ch][HPF].setType(juce::dsp::StateVariableTPTFilterType::highpass);
                    filters[ch][HPF].process(juce::dsp::ProcessContextReplacing<float>(channelBlock));
                }
                else
                {
                    filters[ch][i].setCutoffFrequency(cutoffHz[i]);
                    filters[ch][i].setType(static_cast<juce::dsp::StateVariableTPTFilterType>(i));
                    filters[ch][i].process(juce::dsp::ProcessContextReplacing<float>(channelBlock));
                }
            }
        }
    }
}

void FilterPluginAudioProcessor::oscMessageReceived(const juce::OSCMessage& message)
{
    if (message.getAddressPattern() == "/filter/active")
    {
        if (message.size() == 2 && message[0].isString() && message[1].isInt32())
        {
            juce::String filterName = message[0].getString();
            int active = message[1].getInt32();

            int idx = -1;
            if (filterName == "LPF") idx = LPF;
            else if (filterName == "HPF") idx = HPF;
            else if (filterName == "BPF") idx = BPF;
            else if (filterName == "NOTCH") idx = NOTCH;

            if (idx != -1)
            {
                activeFilters[idx] = (active != 0);

                // Max 2 filter actives
                int count = 0;
                for (bool a : activeFilters)
                    if (a) ++count;
                if (count > 2)
                    activeFilters[idx] = false;
            }
        }
    }
    else if (message.getAddressPattern() == "/filter/cutoff")
    {
        if (message.size() == 2 && message[0].isString() && message[1].isFloat32())
        {
            juce::String filterName = message[0].getString();
            float cutoffValue = message[1].getFloat32();

            int idx = -1;
            if (filterName == "LPF") idx = LPF;
            else if (filterName == "HPF") idx = HPF;
            else if (filterName == "BPF") idx = BPF;
            else if (filterName == "NOTCH") idx = NOTCH;

            if (idx != -1)
                cutoffHz[idx] = cutoffValue;
        }
    }
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter() // I don't actually know what the function does but the compiler refuses to work without it
{
    return new FilterPluginAudioProcessor();
}

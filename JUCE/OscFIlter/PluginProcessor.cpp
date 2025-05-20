#include "PluginProcessor.h"
#include <algorithm> // per std::count

FilterPluginAudioProcessor::FilterPluginAudioProcessor()
{
    connect(9001); // ascolta OSC sulla porta 9001
    juce::OSCReceiver::addListener(this);

    // Inizializza tutti i filtri come passa basso (per default)
    for (auto& filter : filters)
        filter.setType(juce::dsp::StateVariableTPTFilterType::lowpass);
}

FilterPluginAudioProcessor::~FilterPluginAudioProcessor()
{
    juce::OSCReceiver::removeListener(this);
    disconnect();
}

void FilterPluginAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock)
{
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = samplesPerBlock;
    spec.numChannels = getTotalNumOutputChannels();

    for (auto& filter : filters)
        filter.prepare(spec);
}

void FilterPluginAudioProcessor::releaseResources()
{
    // Non serve per ora
}

bool FilterPluginAudioProcessor::isBusesLayoutSupported(const BusesLayout& layouts) const
{
    // Supporta solo audio stereo in/out
    return layouts.getMainInputChannelSet() == juce::AudioChannelSet::stereo()
        && layouts.getMainOutputChannelSet() == juce::AudioChannelSet::stereo();
}

void FilterPluginAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&)
{
    juce::ScopedNoDenormals noDenormals;
    juce::dsp::AudioBlock<float> block(buffer);

    // Reset buffer temporaneo per elaborare ogni filtro separatamente
    juce::AudioBuffer<float> tempBuffer;
    tempBuffer.makeCopyOf(buffer);

    int activeCount = std::count(activeFilters.begin(), activeFilters.end(), true);
    if (activeCount == 0)
        return; // nessun filtro attivo, esco

    // Elaborazione filtri, massimo 2 attivi contemporaneamente
    for (int i = 0; i < NUM_TYPES; ++i)
    {
        if (activeFilters[i])
        {
            if (i == NOTCH)
            {
                // Fake notch: cascata HPF e LPF
                filters[HPF].setCutoffFrequency(cutoffHz[i]+1000);
                filters[HPF].setType(juce::dsp::StateVariableTPTFilterType::highpass);
                filters[HPF].prepare(spec);
                filters[HPF].process(juce::dsp::ProcessContextReplacing<float>(block));

                filters[LPF].setCutoffFrequency(cutoffHz[i]);
                filters[LPF].setType(juce::dsp::StateVariableTPTFilterType::lowpass);
                filters[LPF].prepare(spec);
                filters[LPF].process(juce::dsp::ProcessContextReplacing<float>(block));
            }
            else
            {
                filters[i].setCutoffFrequency(cutoffHz[i]);
                filters[i].setType(static_cast<juce::dsp::StateVariableTPTFilterType>(i));
                filters[i].prepare(spec);
                filters[i].process(juce::dsp::ProcessContextReplacing<float>(block));
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

                // Controlla massimo 2 attivi
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

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new FilterPluginAudioProcessor();
}

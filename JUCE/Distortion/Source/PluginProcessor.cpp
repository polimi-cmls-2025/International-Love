#include "PluginProcessor.h"
#include "PluginEditor.h"

DistortionAudioProcessor::DistortionAudioProcessor()
    : AudioProcessor(BusesProperties().withInput("Input", juce::AudioChannelSet::stereo(), true)
                                     .withOutput("Output", juce::AudioChannelSet::stereo(), true)),
      apvts(*this, nullptr, "Parameters", createParameters())
{
}

DistortionAudioProcessor::~DistortionAudioProcessor()
{
    this->OSCReceiver::disconnect();
    this->OSCReceiver::removeListener(this);
}

juce::AudioProcessorValueTreeState::ParameterLayout DistortionAudioProcessor::createParameters()
{
    std::vector<std::unique_ptr<juce::RangedAudioParameter>> params;
    params.push_back(std::make_unique<juce::AudioParameterFloat>("DRIVE", "Drive", 0.0f, 1.0f, 0.5f));
    return { params.begin(), params.end() };
}

void DistortionAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock)
{
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = samplesPerBlock;
    spec.numChannels = getTotalNumOutputChannels();
    
    inputGain.prepare(spec);
    
    if (!this->OSCReceiver::connect(9003))
        DBG("OSC Receiver: failed to connect to port 9003");
    else
        DBG("OSC connected to port 9003");
    
    this->OSCReceiver::addListener(this, "/drive");
}

void DistortionAudioProcessor::releaseResources()
{
}

void DistortionAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    driveParam = apvts.getRawParameterValue("DRIVE")->load();
    
    // Aumentamos el rango de ganancia de 1-10 a 1-25 para una distorsión más agresiva
    float inputGainValue = juce::jmap(driveParam, 1.0f, 25.0f);
    inputGain.setGainLinear(inputGainValue);
    
    juce::dsp::AudioBlock<float> block(buffer);
    juce::dsp::ProcessContextReplacing<float> context(block);
    inputGain.process(context);
    
    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);
        
        for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
        {
            // Aplicamos la distorsión dos veces para hacerla más agresiva
            channelData[sample] = std::tanh(channelData[sample] * 1.5f);
            channelData[sample] = std::tanh(channelData[sample] * 1.5f);
            
            // Ajustamos la compensación de volumen
            channelData[sample] *= 1.0f / (0.3f + driveParam * 0.7f);
        }
    }
}

void DistortionAudioProcessor::oscMessageReceived(const juce::OSCMessage& message)
{
    if (message.getAddressPattern().toString() == "/drive" && 
        message.size() == 1 && 
        message[0].isFloat32())
    {
        float value = juce::jlimit(0.0f, 1.0f, message[0].getFloat32());
        apvts.getParameter("DRIVE")->setValueNotifyingHost(value);
        DBG("OSC /drive received: " << value);
    }
}

juce::AudioProcessorEditor* DistortionAudioProcessor::createEditor()
{
    return new juce::GenericAudioProcessorEditor(*this);
}

bool DistortionAudioProcessor::hasEditor() const { return true; }
const juce::String DistortionAudioProcessor::getName() const { return "Distortion"; }
bool DistortionAudioProcessor::acceptsMidi() const { return false; }
bool DistortionAudioProcessor::producesMidi() const { return false; }
bool DistortionAudioProcessor::isMidiEffect() const { return false; }
double DistortionAudioProcessor::getTailLengthSeconds() const { return 0.0; }

int DistortionAudioProcessor::getNumPrograms() { return 1; }
int DistortionAudioProcessor::getCurrentProgram() { return 0; }
void DistortionAudioProcessor::setCurrentProgram(int) {}
const juce::String DistortionAudioProcessor::getProgramName(int) { return {}; }
void DistortionAudioProcessor::changeProgramName(int, const juce::String&) {}

void DistortionAudioProcessor::getStateInformation(juce::MemoryBlock& destData)
{
    if (auto xml = apvts.state.createXml())
        copyXmlToBinary(*xml, destData);
}

void DistortionAudioProcessor::setStateInformation(const void* data, int sizeInBytes)
{
    if (auto xml = getXmlFromBinary(data, sizeInBytes))
    {
        if (xml->hasTagName(apvts.state.getType()))
            apvts.replaceState(juce::ValueTree::fromXml(*xml));
    }
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new DistortionAudioProcessor();
}
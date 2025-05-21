#include "PluginProcessor.h"
#include "PluginEditor.h"

SimpleReverbAudioProcessor::SimpleReverbAudioProcessor()
    : AudioProcessor (BusesProperties().withInput ("Input", juce::AudioChannelSet::stereo(), true)
                                      .withOutput("Output", juce::AudioChannelSet::stereo(), true)),
      apvts(*this, nullptr, "Parameters", createParameters())
{
    reverbParams.roomSize = 0.7f;
    reverbParams.damping = 0.5f;
    reverbParams.width = 1.0f;
    reverbParams.freezeMode = 0.0f;
}

juce::AudioProcessorValueTreeState::ParameterLayout SimpleReverbAudioProcessor::createParameters()
{
    std::vector<std::unique_ptr<juce::RangedAudioParameter>> params;
    params.push_back(std::make_unique<juce::AudioParameterFloat>("WET", "Wetness", 0.0f, 1.0f, 0.5f));
    return { params.begin(), params.end() };
}

void SimpleReverbAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock)
{
    reverb.setSampleRate(sampleRate);

    if (!connect(9001))  // SuperCollider must target this port
        DBG("OSC Receiver: failed to connect to port 9001");

    juce::OSCReceiver::addListener(this, "/wet");
}

void SimpleReverbAudioProcessor::releaseResources() {}

void SimpleReverbAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&)
{
    auto* wetnessParam = apvts.getRawParameterValue("WET");
    float wetness = wetnessParam->load();

    reverbParams.wetLevel = wetness;
    reverbParams.dryLevel = 1.0f - wetness;
    reverb.setParameters(reverbParams);

    juce::dsp::AudioBlock<float> block(buffer);
    juce::dsp::ProcessContextReplacing<float> context(block);

    reverb.processStereo(buffer.getWritePointer(0), buffer.getWritePointer(1), buffer.getNumSamples());
}

void SimpleReverbAudioProcessor::oscMessageReceived(const juce::OSCMessage& message)
{
    if (message.getAddressPattern().toString() == "/wet" && message.size() == 1 && message[0].isFloat32())
    {
        float wetVal = juce::jlimit(0.0f, 1.0f, message[0].getFloat32());
        apvts.getParameter("WET")->setValueNotifyingHost(wetVal);
        DBG("OSC /wet received: " << wetVal);
    }
}

juce::AudioProcessorEditor* SimpleReverbAudioProcessor::createEditor()
{
    return new SimpleReverbAudioProcessorEditor(*this);
}

bool SimpleReverbAudioProcessor::hasEditor() const { return true; }
const juce::String SimpleReverbAudioProcessor::getName() const { return "SimpleReverb"; }
bool SimpleReverbAudioProcessor::acceptsMidi() const { return false; }
bool SimpleReverbAudioProcessor::producesMidi() const { return false; }
bool SimpleReverbAudioProcessor::isMidiEffect() const { return false; }
double SimpleReverbAudioProcessor::getTailLengthSeconds() const { return 0.0; }

int SimpleReverbAudioProcessor::getNumPrograms() { return 1; }
int SimpleReverbAudioProcessor::getCurrentProgram() { return 0; }
void SimpleReverbAudioProcessor::setCurrentProgram(int) {}
const juce::String SimpleReverbAudioProcessor::getProgramName(int) { return {}; }
void SimpleReverbAudioProcessor::changeProgramName(int, const juce::String&) {}

void SimpleReverbAudioProcessor::getStateInformation(juce::MemoryBlock& destData)
{
    if (auto xml = apvts.state.createXml())
        copyXmlToBinary(*xml, destData);
}

void SimpleReverbAudioProcessor::setStateInformation(const void* data, int sizeInBytes)
{
    if (auto xml = getXmlFromBinary(data, sizeInBytes))
    {
        if (xml->hasTagName(apvts.state.getType()))
            apvts.replaceState(juce::ValueTree::fromXml(*xml));
    }
}
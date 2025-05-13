#include <JuceHeader.h>

class MainComponent : public juce::Component,
                     private juce::Timer,
                     private juce::Slider::Listener,
                     private juce::ComboBox::Listener
{
public:
    MainComponent()
    {
        // Configurazione slider frequenza
        freqSlider.setRange(20.0, 2000.0, 1.0);
        freqSlider.setValue(440.0, juce::NotificationType::dontSendNotification);
        freqSlider.setTextValueSuffix(" Hz");
        freqSlider.addListener(this);
        freqSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
        freqSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 100, 25);
        addAndMakeVisible(freqSlider);
        
        // Etichetta slider
        freqLabel.setText("Frequency", juce::NotificationType::dontSendNotification);
        freqLabel.attachToComponent(&freqSlider, false);
        freqLabel.setJustificationType(juce::Justification::centred);
        addAndMakeVisible(freqLabel);

        // Configurazione selezione forma d'onda
        waveShapeSelector.addItem("Sine", 1);
        waveShapeSelector.addItem("Triangle", 2);
        waveShapeSelector.addItem("Square", 3);
        waveShapeSelector.setSelectedId(1, juce::NotificationType::dontSendNotification);
        waveShapeSelector.addListener(this);
        addAndMakeVisible(waveShapeSelector);
        
        // Etichetta selettore
        waveShapeLabel.setText("Wave Shape", juce::NotificationType::dontSendNotification);
        waveShapeLabel.attachToComponent(&waveShapeSelector, false);
        waveShapeLabel.setJustificationType(juce::Justification::centred);
        addAndMakeVisible(waveShapeLabel);

        // Configurazione OSC
        if (!oscSender.connect("127.0.0.1", 9001))
            DBG("Errore nella connessione OSC");
        
        // Inizializza generatore
        setFrequency(freqSlider.getValue());
        currentWaveShape = waveShapeSelector.getSelectedId();
        
        // Invia la frequenza iniziale
        sendFrequency();
        
        startTimerHz(60);
        setSize(800, 600);  // Aumentato per lo spazio aggiuntivo
    }

    ~MainComponent() override {}

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colours::black);
        g.setColour(juce::Colours::white);
        g.setFont(20.0f);
        g.drawText("Sinusoid Generator with OSC", getLocalBounds().removeFromTop(40), juce::Justification::centred, true);
        
        // Visualizza frequenza corrente e forma d'onda
        g.setFont(16.0f);
        juce::String waveType;
        switch(currentWaveShape) {
            case 1: waveType = "Sine"; break;
            case 2: waveType = "Triangle"; break;
            case 3: waveType = "Square"; break;
        }
        g.drawText(juce::String(freqHz, 2) + " Hz | " + waveType,
                  getLocalBounds().removeFromBottom(30),
                  juce::Justification::centred, true);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(20);
        freqSlider.setBounds(bounds.removeFromTop(200));
        waveShapeSelector.setBounds(bounds.removeFromTop(50));
    }

private:
    juce::Slider freqSlider;
    juce::Label freqLabel;
    juce::ComboBox waveShapeSelector;
    juce::Label waveShapeLabel;
    juce::OSCSender oscSender;
    
    float phase = 0.0f;
    float phaseDelta = 0.0f;
    float freqHz = 440.0f;
    float lastSentFreq = 0.0f; // Memorizza l'ultima frequenza inviata
    int currentWaveShape = 1; // 1=Sine, 2=Triangle, 3=Square
    int frameCount = 0; // Contatore per limitare l'invio della frequenza

    void setFrequency(float newFreqHz)
    {
        freqHz = newFreqHz;
        phaseDelta = (freqHz / 44100.0f) * juce::MathConstants<float>::twoPi;
    }

    void sendFrequency()
    {
        // Invia la frequenza solo se è cambiata
        if (freqHz != lastSentFreq) {
            juce::OSCMessage freqMsg("/freq");
            freqMsg.addArgument(freqHz);
            oscSender.send(freqMsg);
            lastSentFreq = freqHz;
        }
    }

    float generateWaveSample(float phase)
    {
        switch(currentWaveShape) {
            case 1: // Sine
                return std::sin(phase);
                
            case 2: // Triangle
            {
                float normPhase = std::fmod(phase, juce::MathConstants<float>::twoPi) / juce::MathConstants<float>::twoPi;
                if (normPhase < 0.25f) return normPhase * 4.0f;
                else if (normPhase < 0.75f) return 2.0f - (normPhase * 4.0f);
                else return -4.0f + (normPhase * 4.0f);
            }
                
            case 3: // Square
                return std::sin(phase) > 0.0f ? 1.0f : -1.0f;
                
            default:
                return std::sin(phase);
        }
    }

    void sliderValueChanged(juce::Slider* slider) override
    {
        if (slider == &freqSlider)
        {
            setFrequency(static_cast<float>(slider->getValue()));
            phase = 0.0f; // Reset della fase
            oscSender.send(juce::OSCMessage("/reset"));
            sendFrequency(); // Invia la nuova frequenza immediatamente
            repaint();
        }
    }

    void comboBoxChanged(juce::ComboBox* comboBox) override
    {
        if (comboBox == &waveShapeSelector)
        {
            currentWaveShape = comboBox->getSelectedId();
            phase = 0.0f; // Reset della fase
            oscSender.send(juce::OSCMessage("/reset"));
            repaint();
        }
    }

    void timerCallback() override {
        // Invia la frequenza solo ogni 10 frame (circa una volta al secondo)
        if (frameCount % 10 == 0) {
            sendFrequency();
        }
        frameCount++;
        
        // Genera l'onda da inviare via OSC
        juce::OSCMessage waveMsg("/waveform");
        
        // Calcola quanti campioni servono per un ciclo completo
        int samplesPerCycle = static_cast<int>(44100.0f / freqHz);
        samplesPerCycle = juce::jlimit(16, 256, samplesPerCycle); // Limita tra 16 e 256 campioni
        
        // Invece di generare un solo ciclo, generiamo campioni continui dell'onda
        for (int i = 0; i < 256; i++) {
            waveMsg.addArgument(generateWaveSample(phase));
            phase += phaseDelta;
            if (phase > juce::MathConstants<float>::twoPi)
                phase = std::fmod(phase, juce::MathConstants<float>::twoPi);
        }
        
        oscSender.send(waveMsg);
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainComponent)
};

#include <JuceHeader.h>
#include "MainComponent.h"

class SinWaveOSCApplication : public juce::JUCEApplication
{
public:
    const juce::String getApplicationName() override       { return "SinWaveOSC"; }
    const juce::String getApplicationVersion() override    { return "1.0"; }

    void initialise(const juce::String&) override {
        mainWindow = std::make_unique<MainWindow>("SinWaveOSC", new MainComponent(), *this);


    }

    void shutdown() override {
        mainWindow = nullptr;
    }

private:
    class MainWindow : public juce::DocumentWindow
    {
    public:  // Cambia da private a public
        MainWindow(juce::String name, juce::Component* c, JUCEApplication& a)
            : DocumentWindow(name,
                             juce::Desktop::getInstance().getDefaultLookAndFeel()
                                 .findColour(ResizableWindow::backgroundColourId),
                             DocumentWindow::allButtons),
              app(a)
        {
            setUsingNativeTitleBar(true);
            setContentOwned(new MainComponent(), true);
            centreWithSize(800, 600);
            setVisible(true);
        }

        void closeButtonPressed() override {
            app.systemRequestedQuit();
        }

    private:
        JUCEApplication& app;
    };

    
    std::unique_ptr<MainWindow> mainWindow;
};

START_JUCE_APPLICATION(SinWaveOSCApplication)

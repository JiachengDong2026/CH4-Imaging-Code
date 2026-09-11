#pragma once

#include "model/fused_point.h"

#include <QMainWindow>

class QComboBox;
class QCheckBox;
class QDoubleSpinBox;
class QLabel;
class QLineEdit;
class QPlainTextEdit;
class QPushButton;
class QSpinBox;
class QStackedWidget;
class QTabBar;
class QTimer;

namespace ch4::device {
class DeviceSession;
}

namespace ch4::storage {
class SessionRecorder;
}

namespace ch4::visualization {
class HarmonicWidget;
class MethaneImageWidget;
class TrajectoryWidget;
}

namespace ch4::app {

class MainWindow final : public QMainWindow {
public:
    explicit MainWindow(QWidget* parent = nullptr);
    ~MainWindow() override;

private:
    QWidget* mirrorPage();
    QWidget* dilaPage();
    QWidget* wmsPage();
    void refreshPorts();
    void toggleConnection();
    void startRun();
    void stopRun();
    void clearCurrentView();
    void clearTrajectory();
    void clearHarmonics();
    void clearImage();
    void clearLog();
    void chooseRecordingDirectory();
    void loadRecordedData();
    void onPoint(const model::FusedPoint& point);
    void appendLog(const QString& text);
    void refreshPlots();
    void applyMirrorConfig();
    void updateScanGeometry();
    void updateStreamRateRange();
    void applyStaticPoint();
    void sendMirrorAction(int action);

    device::DeviceSession* session_ = nullptr;
    storage::SessionRecorder* recorder_ = nullptr;
    QStackedWidget* parameterPages_ = nullptr;
    QTabBar* parameterTabs_ = nullptr;
    QTabBar* viewTabs_ = nullptr;
    QStackedWidget* viewPages_ = nullptr;

    QComboBox* modeBox_ = nullptr;
    QComboBox* portBox_ = nullptr;
    QComboBox* baudBox_ = nullptr;
    QPushButton* connectButton_ = nullptr;
    QPushButton* usbConnectButton_ = nullptr;
    QPushButton* startButton_ = nullptr;
    QPushButton* stopButton_ = nullptr;
    QPushButton* clearViewButton_ = nullptr;
    QLabel* connectionLabel_ = nullptr;
    QLabel* usbConnectionLabel_ = nullptr;
    QLabel* acquisitionLabel_ = nullptr;
    QLabel* framesValue_ = nullptr;
    QLabel* crcErrorsValue_ = nullptr;
    QLabel* discardedValue_ = nullptr;
    QLabel* xAngleValue_ = nullptr;
    QLabel* yAngleValue_ = nullptr;
    QLabel* oneFValue_ = nullptr;
    QLabel* twoFValue_ = nullptr;
    QLabel* ratioValue_ = nullptr;
    QLabel* validCellsValue_ = nullptr;
    QLabel* imagePointsValue_ = nullptr;
    QPlainTextEdit* log_ = nullptr;
    QCheckBox* saveData_ = nullptr;
    QLineEdit* recordingDirectory_ = nullptr;
    visualization::TrajectoryWidget* trajectory_ = nullptr;
    visualization::HarmonicWidget* harmonic_ = nullptr;
    visualization::MethaneImageWidget* image_ = nullptr;

    QDoubleSpinBox* xMin_ = nullptr;
    QDoubleSpinBox* xMax_ = nullptr;
    QDoubleSpinBox* yMin_ = nullptr;
    QDoubleSpinBox* yMax_ = nullptr;
    QSpinBox* lines_ = nullptr;
    QSpinBox* streamRate_ = nullptr;
    QCheckBox* streamAngles_ = nullptr;
    QCheckBox* streamHarmonics_ = nullptr;
    QDoubleSpinBox* xFrequency_ = nullptr;
    QDoubleSpinBox* frameFrequency_ = nullptr;
    QSpinBox* feedback_ = nullptr;
    QComboBox* scanPolicy_ = nullptr;
    QComboBox* stopAction_ = nullptr;
    QDoubleSpinBox* staticX_ = nullptr;
    QDoubleSpinBox* staticY_ = nullptr;
    QTimer* refreshTimer_ = nullptr;
    QTimer* mirrorDetectionTimer_ = nullptr;
    quint64 pointCount_ = 0;
    bool mirrorFeedbackActive_ = false;
    bool uartConnected_ = false;
    bool usbConnected_ = false;
    bool displayingRecordedData_ = false;
    bool dirty_ = false;
};

}  // namespace ch4::app

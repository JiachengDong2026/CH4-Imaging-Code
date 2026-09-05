#include "app/main_window.h"

#include "device/device_session.h"
#include "protocol/generated_registers.h"
#include "storage/session_recorder.h"
#include "visualization/harmonic_widget.h"
#include "visualization/methane_image_widget.h"
#include "visualization/trajectory_widget.h"

#include <QComboBox>
#include <QCheckBox>
#include <QAbstractSpinBox>
#include <QDateTime>
#include <QDoubleSpinBox>
#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QFormLayout>
#include <QFrame>
#include <QGridLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QHash>
#include <QLabel>
#include <QLineEdit>
#include <QLocale>
#include <QMessageBox>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QScrollArea>
#include <QSpinBox>
#include <QSplitter>
#include <QStackedWidget>
#include <QStatusBar>
#include <QScrollBar>
#include <QSyntaxHighlighter>
#include <QTabBar>
#include <QTextCharFormat>
#include <QTextDocument>
#include <QTextStream>
#include <QTimer>
#include <QToolButton>
#include <QVBoxLayout>
#include <QVector>

#include <cmath>
#include <optional>

namespace ch4::app {
namespace {

QLabel* sectionTitle(const QString& text, QWidget* parent = nullptr) {
    auto* label = new QLabel(text, parent);
    label->setObjectName(QStringLiteral("sectionTitle"));
    return label;
}

QLabel* caption(const QString& text, QWidget* parent = nullptr) {
    auto* label = new QLabel(text, parent);
    label->setObjectName(QStringLiteral("caption"));
    label->setWordWrap(true);
    return label;
}

QLabel* headerFieldLabel(const QString& text, QWidget* parent = nullptr) {
    auto* label = new QLabel(text, parent);
    label->setObjectName(QStringLiteral("headerFieldLabel"));
    label->setFixedWidth(48);
    label->setAlignment(Qt::AlignRight | Qt::AlignVCenter);
    return label;
}

QFrame* panel(const QString& objectName, QWidget* parent = nullptr) {
    auto* frame = new QFrame(parent);
    frame->setObjectName(objectName);
    frame->setFrameShape(QFrame::StyledPanel);
    return frame;
}

QWidget* scrollable(QWidget* content) {
    auto* scroll = new QScrollArea;
    scroll->setWidgetResizable(true);
    scroll->setFrameShape(QFrame::NoFrame);
    scroll->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
    content->setMinimumWidth(0);
    content->setSizePolicy(QSizePolicy::Ignored, QSizePolicy::Preferred);
    scroll->setWidget(content);
    return scroll;
}

QWidget* numericEditor(QAbstractSpinBox* spin) {
    // Fusion can hide built-in spinbox arrows when a form row is narrow.
    // Keep a single, explicit button treatment for every numeric editor.
    spin->setButtonSymbols(QAbstractSpinBox::NoButtons);
    spin->setMinimumWidth(0);
    spin->setMinimumHeight(34);
    spin->setSizePolicy(QSizePolicy::Ignored, QSizePolicy::Fixed);
    auto* buttonColumn = new QWidget;
    auto* buttonLayout = new QVBoxLayout(buttonColumn);
    buttonLayout->setContentsMargins(0, 0, 0, 0);
    buttonLayout->setSpacing(0);
    auto* up = new QToolButton;
    auto* down = new QToolButton;
    up->setObjectName(QStringLiteral("numericStepButton"));
    down->setObjectName(QStringLiteral("numericStepButton"));
    up->setArrowType(Qt::UpArrow);
    down->setArrowType(Qt::DownArrow);
    up->setFixedSize(24, 17);
    down->setFixedSize(24, 17);
    up->setToolTip(QStringLiteral("Increase value"));
    down->setToolTip(QStringLiteral("Decrease value"));
    buttonLayout->addWidget(up);
    buttonLayout->addWidget(down);
    QObject::connect(up, &QToolButton::clicked, spin, &QAbstractSpinBox::stepUp);
    QObject::connect(down, &QToolButton::clicked, spin, &QAbstractSpinBox::stepDown);
    auto* editor = new QWidget;
    auto* editorLayout = new QHBoxLayout(editor);
    editorLayout->setContentsMargins(0, 0, 0, 0);
    editorLayout->setSpacing(0);
    editorLayout->addWidget(spin, 1);
    editorLayout->addWidget(buttonColumn);
    return editor;
}

QWidget* rangeEditor(QDoubleSpinBox* minimum, QDoubleSpinBox* maximum) {
    auto* row = new QWidget;
    auto* layout = new QHBoxLayout(row);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(4);
    layout->addWidget(numericEditor(minimum), 1);
    layout->addWidget(numericEditor(maximum), 1);
    return row;
}

QWidget* comboEditor(QComboBox* combo) {
    combo->setObjectName(QStringLiteral("comboWithoutArrow"));
    combo->setMinimumHeight(34);
    combo->setSizePolicy(QSizePolicy::Ignored, QSizePolicy::Fixed);
    auto* arrow = new QToolButton;
    arrow->setObjectName(QStringLiteral("comboArrowButton"));
    arrow->setArrowType(Qt::DownArrow);
    arrow->setFixedSize(24, 34);
    arrow->setToolTip(QStringLiteral("Show options"));
    QObject::connect(arrow, &QToolButton::clicked, combo, &QComboBox::showPopup);

    auto* editor = new QWidget;
    auto* layout = new QHBoxLayout(editor);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);
    layout->addWidget(combo, 1);
    layout->addWidget(arrow);
    return editor;
}

std::optional<model::FusedPoint> parseRecordedPoint(const QStringList& fields,
                                                     const QHash<QString, int>& columns) {
    const auto value = [&fields, &columns](const QString& name) { return fields.at(columns.value(name)); };
    model::FusedPoint point;
    bool ok = false;
    point.measurementTime = value(QStringLiteral("measurement_ticks")).toULongLong(&ok); if (!ok) return {};
    point.imageId = value(QStringLiteral("image_id")).toUInt(&ok); if (!ok) return {};
    point.lineId = value(QStringLiteral("line_id")).toUShort(&ok); if (!ok) return {};
    point.pointId = value(QStringLiteral("point_id")).toUShort(&ok); if (!ok) return {};
    point.xAngleQ13 = value(QStringLiteral("x_q13")).toShort(&ok); if (!ok) return {};
    point.yAngleQ13 = value(QStringLiteral("y_q13")).toShort(&ok); if (!ok) return {};
    point.i1 = value(QStringLiteral("i1")).toInt(&ok); if (!ok) return {};
    point.q1 = value(QStringLiteral("q1")).toInt(&ok); if (!ok) return {};
    point.i2 = value(QStringLiteral("i2")).toInt(&ok); if (!ok) return {};
    point.q2 = value(QStringLiteral("q2")).toInt(&ok); if (!ok) return {};
    point.a1 = value(QStringLiteral("a1")).toUInt(&ok); if (!ok) return {};
    point.a2 = value(QStringLiteral("a2")).toUInt(&ok); if (!ok) return {};
    point.flags = value(QStringLiteral("flags")).toUShort(&ok, 16); if (!ok) return {};
    point.configRevision = value(QStringLiteral("config_revision")).toUShort(&ok); if (!ok) return {};
    return point;
}

struct RecordedCsvTable {
    QHash<QString, int> columns;
    QVector<QStringList> rows;
};

std::optional<RecordedCsvTable> readRecordedCsv(const QString& fileName,
                                                 const QStringList& requiredColumns) {
    QFile file(fileName);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    QTextStream input(&file);
    const QStringList header = input.readLine().split(',');
    RecordedCsvTable table;
    for (const QString& column : requiredColumns) {
        const int index = header.indexOf(column);
        if (index < 0)
            return {};
        table.columns.insert(column, index);
    }
    while (!input.atEnd()) {
        const QString line = input.readLine();
        if (line.trimmed().isEmpty())
            continue;
        const QStringList fields = line.split(',');
        if (fields.size() >= header.size())
            table.rows.append(fields);
    }
    return table;
}

std::optional<model::AngleSample> parseRecordedAngle(const QStringList& fields,
                                                      const QHash<QString, int>& columns) {
    const auto value = [&fields, &columns](const QString& name) { return fields.at(columns.value(name)); };
    model::AngleSample sample;
    bool ok = false;
    sample.measurementTime = value(QStringLiteral("measurement_ticks")).toULongLong(&ok); if (!ok) return {};
    sample.sampleIndex = value(QStringLiteral("sample_index")).toUInt(&ok); if (!ok) return {};
    sample.xAngleQ13 = value(QStringLiteral("x_q13")).toShort(&ok); if (!ok) return {};
    sample.yAngleQ13 = value(QStringLiteral("y_q13")).toShort(&ok); if (!ok) return {};
    return sample;
}

std::optional<model::HarmonicCurve> parseRecordedHarmonic(const QStringList& fields,
                                                           const QHash<QString, int>& columns) {
    const auto value = [&fields, &columns](const QString& name) { return fields.at(columns.value(name)); };
    model::HarmonicCurve curve;
    bool ok = false;
    curve.measurementTime = value(QStringLiteral("measurement_ticks")).toULongLong(&ok); if (!ok) return {};
    curve.sampleIndex = value(QStringLiteral("sample_index")).toUInt(&ok); if (!ok) return {};
    curve.i1 = value(QStringLiteral("i1")).toInt(&ok); if (!ok) return {};
    curve.q1 = value(QStringLiteral("q1")).toInt(&ok); if (!ok) return {};
    curve.i2 = value(QStringLiteral("i2")).toInt(&ok); if (!ok) return {};
    curve.q2 = value(QStringLiteral("q2")).toInt(&ok); if (!ok) return {};
    return curve;
}

class LogHighlighter final : public QSyntaxHighlighter {
public:
    explicit LogHighlighter(QTextDocument* document) : QSyntaxHighlighter(document) {}
private:
    void highlightBlock(const QString& text) override {
        const auto colorLevel = [this, &text](const QString& level, const QColor& color) {
            const int position = text.indexOf(level);
            if (position < 0) return;
            QTextCharFormat format;
            format.setForeground(color);
            format.setFontWeight(QFont::DemiBold);
            setFormat(position, level.size(), format);
        };
        colorLevel(QStringLiteral("ERROR"), QColor("#b42318"));
        colorLevel(QStringLiteral("WARNING"), QColor("#9a6700"));
        colorLevel(QStringLiteral("TX"), QColor("#175cd3"));
        colorLevel(QStringLiteral("RX"), QColor("#087443"));
        colorLevel(QStringLiteral("INFO"), QColor("#475467"));
    }
};

}  // namespace

MainWindow::MainWindow(QWidget* parent)
    : QMainWindow(parent),
      session_(new device::DeviceSession(this)),
      recorder_(new storage::SessionRecorder(this)),
      parameterPages_(new QStackedWidget),
      parameterTabs_(new QTabBar),
      viewTabs_(new QTabBar),
      viewPages_(new QStackedWidget),
      refreshTimer_(new QTimer(this)) {
    setWindowTitle(QStringLiteral("CH4 Scan Imaging Console"));
    resize(1540, 920);
    setMinimumSize(1180, 720);

    auto* root = new QWidget;
    auto* rootLayout = new QVBoxLayout(root);
    rootLayout->setContentsMargins(14, 12, 14, 14);
    rootLayout->setSpacing(10);

    auto* header = panel(QStringLiteral("appHeader"));
    auto* headerLayout = new QHBoxLayout(header);
    headerLayout->setContentsMargins(12, 8, 12, 8);
    headerLayout->setSpacing(8);
    auto* title = new QLabel(QStringLiteral("CH4 Scan Imaging"));
    title->setObjectName(QStringLiteral("appTitle"));
    title->setMinimumWidth(175);
    headerLayout->addWidget(title);

    modeBox_ = new QComboBox;
    modeBox_->addItem(QStringLiteral("Mock demonstration"));
    modeBox_->addItem(QStringLiteral("UART serial"));
    modeBox_->setFixedWidth(120);
    portBox_ = new QComboBox;
    portBox_->setFixedWidth(94);
    baudBox_ = new QComboBox;
    const QList<QPair<QString, int>> baudRates = {{QStringLiteral("115200"), 115200},
                                                  {QStringLiteral("230400"), 230400},
                                                  {QStringLiteral("460800"), 460800},
                                                  {QStringLiteral("921600"), 921600},
                                                  {QStringLiteral("1500000"), 1500000},
                                                  {QStringLiteral("2000000"), 2000000}};
    for (const auto& baudRate : baudRates)
        baudBox_->addItem(baudRate.first, baudRate.second);
    baudBox_->setCurrentIndex(3);
    baudBox_->setFixedWidth(82);
    auto* refreshButton = new QPushButton(QStringLiteral("Refresh"));
    refreshButton->setObjectName(QStringLiteral("secondaryButton"));
    refreshButton->setFixedWidth(66);
    connectButton_ = new QPushButton(QStringLiteral("Connect"));
    connectButton_->setObjectName(QStringLiteral("primaryButton"));
    connectButton_->setFixedWidth(90);
    connectionLabel_ = new QLabel(QStringLiteral("● Disconnected"));
    connectionLabel_->setObjectName(QStringLiteral("stateIdle"));
    connectionLabel_->setMinimumWidth(190);
    acquisitionLabel_ = new QLabel(QStringLiteral("● Idle"));
    acquisitionLabel_->setObjectName(QStringLiteral("stateIdle"));
    acquisitionLabel_->setMinimumWidth(76);
    headerLayout->addWidget(headerFieldLabel(QStringLiteral("Source")));
    headerLayout->addWidget(modeBox_);
    headerLayout->addWidget(headerFieldLabel(QStringLiteral("Port")));
    headerLayout->addWidget(portBox_);
    headerLayout->addWidget(headerFieldLabel(QStringLiteral("Baud")));
    headerLayout->addWidget(baudBox_);
    headerLayout->addWidget(refreshButton);
    headerLayout->addWidget(connectButton_);
    headerLayout->addSpacing(8);
    headerLayout->addWidget(connectionLabel_);
    headerLayout->addWidget(acquisitionLabel_);
    startButton_ = new QPushButton(QStringLiteral("Start acquisition"));
    startButton_->setObjectName(QStringLiteral("primaryButton"));
    stopButton_ = new QPushButton(QStringLiteral("Stop"));
    stopButton_->setObjectName(QStringLiteral("dangerButton"));
    startButton_->setEnabled(false);
    stopButton_->setEnabled(false);
    startButton_->setFixedWidth(138);
    stopButton_->setFixedWidth(68);
    headerLayout->addWidget(startButton_);
    headerLayout->addWidget(stopButton_);
    headerLayout->addStretch(1);
    header->setMaximumHeight(72);
    rootLayout->addWidget(header);

    auto* body = new QSplitter(Qt::Horizontal);
    body->setChildrenCollapsible(false);

    auto* left = panel(QStringLiteral("sidePanel"));
    left->setMinimumWidth(350);
    left->setMaximumWidth(390);
    auto* leftLayout = new QVBoxLayout(left);
    leftLayout->setContentsMargins(12, 12, 12, 12);
    leftLayout->setSpacing(6);
    leftLayout->addWidget(sectionTitle(QStringLiteral("Device configuration")));

    parameterTabs_->addTab(QStringLiteral("Scan"));
    parameterTabs_->addTab(QStringLiteral("DILA"));
    parameterTabs_->addTab(QStringLiteral("WMS"));
    parameterTabs_->setExpanding(true);
    parameterPages_->addWidget(scrollable(mirrorPage()));
    parameterPages_->addWidget(scrollable(dilaPage()));
    parameterPages_->addWidget(scrollable(wmsPage()));
    leftLayout->addWidget(parameterTabs_);
    leftLayout->addWidget(parameterPages_, 1);

    auto* center = panel(QStringLiteral("workspacePanel"));
    auto* centerLayout = new QVBoxLayout(center);
    centerLayout->setContentsMargins(14, 12, 14, 14);
    centerLayout->setSpacing(8);
    auto* workspaceHeading = new QHBoxLayout;
    workspaceHeading->addWidget(sectionTitle(QStringLiteral("Live workspace")));
    workspaceHeading->addStretch();
    auto* trajectoryDisplay = new QComboBox;
    trajectoryDisplay->addItem(QStringLiteral("Trajectory"),
                               static_cast<int>(visualization::TrajectoryWidget::DisplayMode::Trajectory));
    trajectoryDisplay->addItem(QStringLiteral("Scatter"),
                               static_cast<int>(visualization::TrajectoryWidget::DisplayMode::Scatter));
    trajectoryDisplay->setFixedWidth(110);
    workspaceHeading->addWidget(new QLabel(QStringLiteral("Display")));
    workspaceHeading->addWidget(trajectoryDisplay);
    clearViewButton_ = new QPushButton(QStringLiteral("Clear trajectory"));
    clearViewButton_->setObjectName(QStringLiteral("secondaryButton"));
    workspaceHeading->addWidget(clearViewButton_);
    centerLayout->addLayout(workspaceHeading);

    viewTabs_->addTab(QStringLiteral("Mirror trajectory"));
    viewTabs_->addTab(QStringLiteral("1f / 2f harmonics"));
    viewTabs_->addTab(QStringLiteral("Methane image"));
    viewTabs_->setExpanding(true);
    centerLayout->addWidget(viewTabs_);
    trajectory_ = new visualization::TrajectoryWidget;
    harmonic_ = new visualization::HarmonicWidget;
    image_ = new visualization::MethaneImageWidget;
    viewPages_->addWidget(trajectory_);
    viewPages_->addWidget(harmonic_);
    viewPages_->addWidget(image_);
    centerLayout->addWidget(viewPages_, 1);
    body->addWidget(left);
    body->addWidget(center);

    auto* right = panel(QStringLiteral("diagnosticsPanel"));
    right->setMinimumWidth(300);
    right->setMaximumWidth(340);
    auto* rightLayout = new QVBoxLayout(right);
    rightLayout->setContentsMargins(12, 12, 12, 12);
    rightLayout->setSpacing(10);
    rightLayout->addWidget(sectionTitle(QStringLiteral("Run diagnostics")));

    rightLayout->addWidget(sectionTitle(QStringLiteral("Telemetry")));
    auto* telemetry = new QWidget;
    auto* telemetryLayout = new QGridLayout(telemetry);
    telemetryLayout->setContentsMargins(0, 0, 0, 0);
    telemetryLayout->setHorizontalSpacing(10);
    telemetryLayout->setVerticalSpacing(3);
    telemetryLayout->setColumnStretch(1, 1);
    const auto addTelemetry = [telemetryLayout](int& row, const QString& name, QLabel*& value) {
        auto* label = new QLabel(name);
        label->setObjectName(QStringLiteral("telemetryLabel"));
        value = new QLabel(QStringLiteral("0"));
        value->setObjectName(QStringLiteral("telemetryValue"));
        value->setAlignment(Qt::AlignRight | Qt::AlignVCenter);
        value->setMinimumWidth(112);
        telemetryLayout->addWidget(label, row, 0);
        telemetryLayout->addWidget(value, row++, 1);
    };
    const auto addTelemetrySection = [telemetryLayout](int& row, const QString& name) {
        auto* label = new QLabel(name);
        label->setObjectName(QStringLiteral("telemetrySection"));
        telemetryLayout->addWidget(label, row++, 0, 1, 2);
    };
    int telemetryRow = 0;
    addTelemetrySection(telemetryRow, QStringLiteral("PACKETS"));
    addTelemetry(telemetryRow, QStringLiteral("Frames"), framesValue_);
    addTelemetry(telemetryRow, QStringLiteral("CRC errors"), crcErrorsValue_);
    addTelemetry(telemetryRow, QStringLiteral("Discarded"), discardedValue_);
    addTelemetrySection(telemetryRow, QStringLiteral("MIRROR"));
    addTelemetry(telemetryRow, QStringLiteral("X angle"), xAngleValue_);
    addTelemetry(telemetryRow, QStringLiteral("Y angle"), yAngleValue_);
    addTelemetrySection(telemetryRow, QStringLiteral("HARMONICS"));
    addTelemetry(telemetryRow, QStringLiteral("1f"), oneFValue_);
    addTelemetry(telemetryRow, QStringLiteral("2f"), twoFValue_);
    addTelemetry(telemetryRow, QStringLiteral("2f/1f"), ratioValue_);
    addTelemetrySection(telemetryRow, QStringLiteral("IMAGING"));
    addTelemetry(telemetryRow, QStringLiteral("Valid cells"), validCellsValue_);
    addTelemetry(telemetryRow, QStringLiteral("Image points"), imagePointsValue_);
    rightLayout->addWidget(telemetry);

    auto* eventHeading = new QHBoxLayout;
    eventHeading->addWidget(sectionTitle(QStringLiteral("Event log")));
    eventHeading->addStretch();
    auto* clearLogButton = new QPushButton(QStringLiteral("Clear"));
    clearLogButton->setObjectName(QStringLiteral("secondaryButton"));
    eventHeading->addWidget(clearLogButton);
    rightLayout->addLayout(eventHeading);
    log_ = new QPlainTextEdit;
    log_->setReadOnly(true);
    log_->setMaximumBlockCount(1500);
    log_->setPlaceholderText(QStringLiteral("Connection and acquisition events appear here."));
    new LogHighlighter(log_->document());
    rightLayout->addWidget(log_, 1);
    body->addWidget(right);
    body->setStretchFactor(0, 0);
    body->setStretchFactor(1, 1);
    body->setStretchFactor(2, 0);
    body->setSizes({370, 840, 320});
    rootLayout->addWidget(body, 1);
    setCentralWidget(root);

    connect(parameterTabs_, &QTabBar::currentChanged, parameterPages_, &QStackedWidget::setCurrentIndex);
    connect(viewTabs_, &QTabBar::currentChanged, viewPages_, &QStackedWidget::setCurrentIndex);
    connect(trajectoryDisplay, qOverload<int>(&QComboBox::currentIndexChanged), this,
            [this, trajectoryDisplay](int) {
                trajectory_->setDisplayMode(static_cast<visualization::TrajectoryWidget::DisplayMode>(
                    trajectoryDisplay->currentData().toInt()));
            });
    connect(refreshButton, &QPushButton::clicked, this, &MainWindow::refreshPorts);
    connect(connectButton_, &QPushButton::clicked, this, &MainWindow::toggleConnection);
    connect(startButton_, &QPushButton::clicked, this, &MainWindow::startRun);
    connect(stopButton_, &QPushButton::clicked, this, &MainWindow::stopRun);
    connect(clearViewButton_, &QPushButton::clicked, this, &MainWindow::clearCurrentView);
    connect(clearLogButton, &QPushButton::clicked, this, &MainWindow::clearLog);
    connect(viewTabs_, &QTabBar::currentChanged, this, [this](int index) {
        clearViewButton_->setText(index == 0 ? QStringLiteral("Clear trajectory")
                                   : index == 1 ? QStringLiteral("Clear waveform")
                                                : QStringLiteral("Clear image"));
    });
    connect(modeBox_, qOverload<int>(&QComboBox::currentIndexChanged), this, [this](int index) {
        portBox_->setEnabled(index == 1);
        baudBox_->setEnabled(index == 1);
    });
    connect(session_, &device::DeviceSession::connectionChanged, this,
            [this](bool connected, const QString& detail) {
                const bool mock = connected && modeBox_->currentIndex() == 0;
                connectionLabel_->setText(connected ? (mock ? QStringLiteral("● Mock mode")
                                                              : QStringLiteral("● Connected · %1").arg(detail))
                                                     : QStringLiteral("● Disconnected"));
                connectionLabel_->setObjectName(connected ? QStringLiteral("stateConnected") : QStringLiteral("stateIdle"));
                connectionLabel_->style()->unpolish(connectionLabel_);
                connectionLabel_->style()->polish(connectionLabel_);
                connectButton_->setText(connected ? QStringLiteral("Disconnect") : QStringLiteral("Connect"));
                modeBox_->setEnabled(!connected);
                portBox_->setEnabled(!connected && modeBox_->currentIndex() == 1);
                baudBox_->setEnabled(!connected && modeBox_->currentIndex() == 1);
                connectButton_->setObjectName(connected ? QStringLiteral("secondaryButton") : QStringLiteral("primaryButton"));
                connectButton_->style()->unpolish(connectButton_);
                connectButton_->style()->polish(connectButton_);
                startButton_->setEnabled(connected && !session_->running());
                stopButton_->setEnabled(connected && session_->running());
                if (!connected) {
                    acquisitionLabel_->setText(QStringLiteral("● Idle"));
                    acquisitionLabel_->setObjectName(QStringLiteral("stateIdle"));
                }
                statusBar()->showMessage(connected ? (mock ? QStringLiteral("Mock mode connected.")
                                                             : QStringLiteral("Connected to %1.").arg(detail))
                                                   : QStringLiteral("Disconnected."));
            });
    connect(session_, &device::DeviceSession::runningChanged, this,
            [this](bool running) {
                startButton_->setEnabled(session_->connected() && !running);
                stopButton_->setEnabled(session_->connected() && running);
                acquisitionLabel_->setText(running ? QStringLiteral("● Running") : QStringLiteral("● Idle"));
                acquisitionLabel_->setObjectName(running ? QStringLiteral("stateRunning") : QStringLiteral("stateIdle"));
                acquisitionLabel_->style()->unpolish(acquisitionLabel_);
                acquisitionLabel_->style()->polish(acquisitionLabel_);
                statusBar()->showMessage(running ? QStringLiteral("Acquisition started.") : QStringLiteral("Acquisition stopped."));
            });
    connect(session_, &device::DeviceSession::pointReceived, this, &MainWindow::onPoint);
    connect(session_, &device::DeviceSession::angleSampleReceived, this, [this](const model::AngleSample& sample) {
        trajectory_->append(sample.xDegrees(), sample.yDegrees());
        recorder_->append(sample);
        xAngleValue_->setText(QStringLiteral("%1°").arg(sample.xDegrees(), 0, 'f', 3));
        yAngleValue_->setText(QStringLiteral("%1°").arg(sample.yDegrees(), 0, 'f', 3));
        dirty_ = true;
    });
    connect(session_, &device::DeviceSession::harmonicCurveReceived, this, [this](const model::HarmonicCurve& curve) {
        const double amplitude1f = curve.amplitude1f();
        const double amplitude2f = curve.amplitude2f();
        harmonic_->appendRaw(curve.sampleIndex, amplitude1f, amplitude2f);
        recorder_->append(curve);
        oneFValue_->setText(QString::number(amplitude1f, 'f', 3));
        twoFValue_->setText(QString::number(amplitude2f, 'f', 3));
        ratioValue_->setText(QString::number(amplitude1f == 0.0 ? 0.0 : amplitude2f / amplitude1f, 'f', 4));
        dirty_ = true;
    });
    connect(session_, &device::DeviceSession::logMessage, this, &MainWindow::appendLog);
    connect(session_, &device::DeviceSession::protocolStatsChanged, this,
            [this](quint64 frames, quint64 crcErrors, quint64 discardedBytes) {
                framesValue_->setText(QLocale().toString(frames));
                crcErrorsValue_->setText(QLocale().toString(crcErrors));
                discardedValue_->setText(QLocale().toString(discardedBytes));
            });

    refreshTimer_->setInterval(40);
    connect(refreshTimer_, &QTimer::timeout, this, &MainWindow::refreshPlots);
    refreshTimer_->start();
    refreshPorts();
    portBox_->setEnabled(false);
    baudBox_->setEnabled(false);
    image_->configure(50, lines_->value(), xMin_->value(), xMax_->value(), yMin_->value(), yMax_->value());
    trajectory_->configureRange(xMin_->value(), xMax_->value(), yMin_->value(), yMax_->value());
    statusBar()->showMessage(QStringLiteral("Ready. Connect a device or use mock demonstration mode."));
}

MainWindow::~MainWindow() {
    session_->stop();
    recorder_->stop();
}

QWidget* MainWindow::mirrorPage() {
    auto* page = new QWidget;
    auto* layout = new QVBoxLayout(page);
    layout->setContentsMargins(2, 2, 2, 2);
    layout->setSpacing(6);

    auto angleSpinBox = [](double value) {
        auto* spin = new QDoubleSpinBox;
        spin->setRange(-4.0, 4.0);
        spin->setDecimals(3);
        spin->setSingleStep(0.1);
        spin->setValue(value);
        spin->setSuffix(QStringLiteral("°"));
        return spin;
    };
    auto integerSpinBox = [](int minimum, int maximum, int value, const QString& suffix) {
        auto* spin = new QSpinBox;
        spin->setRange(minimum, maximum);
        spin->setValue(value);
        spin->setSuffix(suffix);
        return spin;
    };

    auto* scanBox = new QGroupBox(QStringLiteral("Scan geometry"));
    auto* form = new QFormLayout(scanBox);
    form->setContentsMargins(8, 8, 8, 8);
    form->setVerticalSpacing(4);
    form->setHorizontalSpacing(8);
    form->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);
    xMin_ = angleSpinBox(-1.0);
    xMax_ = angleSpinBox(1.0);
    yMin_ = angleSpinBox(-1.0);
    yMax_ = angleSpinBox(1.0);
    xFrequency_ = new QDoubleSpinBox;
    xFrequency_->setRange(1.0, 20.0);
    xFrequency_->setDecimals(3);
    xFrequency_->setSingleStep(0.25);
    xFrequency_->setValue(15.0);
    xFrequency_->setSuffix(QStringLiteral(" Hz"));
    frameFrequency_ = new QDoubleSpinBox;
    frameFrequency_->setRange(0.001, 40.0);
    frameFrequency_->setDecimals(3);
    frameFrequency_->setSingleStep(0.1);
    frameFrequency_->setValue(0.4);
    frameFrequency_->setSuffix(QStringLiteral(" Hz"));
    feedback_ = integerSpinBox(100, 2500, 2000, QStringLiteral(" Hz"));
    lines_ = integerSpinBox(2, 2048, 75, QStringLiteral(" lines"));
    lines_->setReadOnly(true);
    streamRate_ = integerSpinBox(1, 2000, 500, QStringLiteral(" points/s"));
    streamAngles_ = new QCheckBox(QStringLiteral("Send scan trajectory (angle)"));
    streamAngles_->setChecked(true);
    streamHarmonics_ = new QCheckBox(QStringLiteral("Send harmonic waveform (I/Q)"));
    streamHarmonics_->setChecked(false);
    scanPolicy_ = new QComboBox;
    scanPolicy_->addItems({QStringLiteral("Frequency priority"), QStringLiteral("Waveform priority")});
    scanPolicy_->setCurrentIndex(1);
    stopAction_ = new QComboBox;
    stopAction_->addItems({QStringLiteral("Hold position"), QStringLiteral("Return zero"), QStringLiteral("Return scan origin")});
    form->addRow(QStringLiteral("X range"), rangeEditor(xMin_, xMax_));
    form->addRow(QStringLiteral("Y range"), rangeEditor(yMin_, yMax_));
    form->addRow(QStringLiteral("X frequency"), numericEditor(xFrequency_));
    form->addRow(QStringLiteral("Mirror frame rate"), numericEditor(frameFrequency_));
    form->addRow(QStringLiteral("Feedback rate"), numericEditor(feedback_));
    form->addRow(QStringLiteral("Image lines"), numericEditor(lines_));
    form->addRow(QString(), caption(QStringLiteral("Image lines are derived from floor(2 × X frequency / frame rate) to match the physical raster.")));
    form->addRow(QStringLiteral("Stream rate"), numericEditor(streamRate_));
    form->addRow(QStringLiteral("Data streams"), streamAngles_);
    form->addRow(QString(), streamHarmonics_);
    form->addRow(QString(), caption(QStringLiteral("Trajectory is sent only after valid fast-mirror feedback is received.")));
    form->addRow(QStringLiteral("Scheduling"), comboEditor(scanPolicy_));
    form->addRow(QStringLiteral("On stop"), comboEditor(stopAction_));
    auto* applyButton = new QPushButton(QStringLiteral("Apply scan parameters"));
    applyButton->setObjectName(QStringLiteral("primaryButton"));
    form->addRow(QString(), applyButton);
    connect(applyButton, &QPushButton::clicked, this, &MainWindow::applyMirrorConfig);
    connect(streamAngles_, &QCheckBox::toggled, this, [this] { updateStreamRateRange(); session_->setStreamSelection(streamAngles_->isChecked(), streamHarmonics_->isChecked()); });
    connect(streamHarmonics_, &QCheckBox::toggled, this, [this] { updateStreamRateRange(); session_->setStreamSelection(streamAngles_->isChecked(), streamHarmonics_->isChecked()); });
    connect(xFrequency_, QOverload<double>::of(&QDoubleSpinBox::valueChanged), this, [this] { updateScanGeometry(); });
    connect(frameFrequency_, QOverload<double>::of(&QDoubleSpinBox::valueChanged), this, [this] { updateScanGeometry(); });
    updateScanGeometry();
    updateStreamRateRange();
    layout->addWidget(scanBox);

    auto* staticBox = new QGroupBox(QStringLiteral("Static mirror offset"));
    auto* staticForm = new QFormLayout(staticBox);
    staticX_ = angleSpinBox(0.0);
    staticY_ = angleSpinBox(0.0);
    staticX_->setDecimals(4);
    staticY_->setDecimals(4);
    staticForm->addRow(QStringLiteral("X angle"), numericEditor(staticX_));
    staticForm->addRow(QStringLiteral("Y angle"), numericEditor(staticY_));
    auto* staticButton = new QPushButton(QStringLiteral("Set static offset"));
    staticButton->setObjectName(QStringLiteral("secondaryButton"));
    staticForm->addRow(QString(), staticButton);
    connect(staticButton, &QPushButton::clicked, this, &MainWindow::applyStaticPoint);
    layout->addWidget(staticBox);

    auto* serviceBox = new QGroupBox(QStringLiteral("Device actions"));
    auto* serviceLayout = new QGridLayout(serviceBox);
    auto* statusButton = new QPushButton(QStringLiteral("Query status"));
    auto* zeroButton = new QPushButton(QStringLiteral("Return zero"));
    auto* originButton = new QPushButton(QStringLiteral("Return scan origin"));
    serviceLayout->addWidget(statusButton, 0, 0, 1, 2);
    serviceLayout->addWidget(zeroButton, 1, 0);
    serviceLayout->addWidget(originButton, 1, 1);
    connect(statusButton, &QPushButton::clicked, this, [this] { session_->queryStatus(); });
    connect(zeroButton, &QPushButton::clicked, this, [this] { sendMirrorAction(0); });
    connect(originButton, &QPushButton::clicked, this, [this] { sendMirrorAction(1); });
    layout->addWidget(serviceBox);

    auto* dataBox = new QGroupBox(QStringLiteral("Data recording"));
    auto* dataForm = new QFormLayout(dataBox);
    dataForm->setContentsMargins(8, 8, 8, 8);
    saveData_ = new QCheckBox(QStringLiteral("Save acquisition data"));
    saveData_->setChecked(true);
    recordingDirectory_ = new QLineEdit(QDir(QStringLiteral(CH4_PROJECT_ROOT "/Data")).absolutePath());
    recordingDirectory_->setReadOnly(true);
    recordingDirectory_->setToolTip(QStringLiteral("New session folders are created here."));
    auto* chooseDirectoryButton = new QPushButton(QStringLiteral("Browse…"));
    chooseDirectoryButton->setObjectName(QStringLiteral("secondaryButton"));
    auto* directoryEditor = new QWidget;
    auto* directoryLayout = new QHBoxLayout(directoryEditor);
    directoryLayout->setContentsMargins(0, 0, 0, 0);
    directoryLayout->setSpacing(4);
    directoryLayout->addWidget(recordingDirectory_, 1);
    directoryLayout->addWidget(chooseDirectoryButton);
    auto* loadDataButton = new QPushButton(QStringLiteral("Open recorded data"));
    loadDataButton->setObjectName(QStringLiteral("secondaryButton"));
    dataForm->addRow(QStringLiteral("Save data"), saveData_);
    dataForm->addRow(QStringLiteral("Save location"), directoryEditor);
    dataForm->addRow(QString(), caption(QStringLiteral("The setting takes effect when a new acquisition starts.")));
    dataForm->addRow(QStringLiteral("Recorded data"), loadDataButton);
    connect(chooseDirectoryButton, &QPushButton::clicked, this, &MainWindow::chooseRecordingDirectory);
    connect(loadDataButton, &QPushButton::clicked, this, &MainWindow::loadRecordedData);
    layout->addWidget(dataBox);
    layout->addStretch();
    return page;
}

QWidget* MainWindow::dilaPage() {
    auto* page = new QWidget;
    auto* layout = new QVBoxLayout(page);
    layout->setContentsMargins(2, 4, 2, 4);
    layout->setSpacing(10);
    layout->addWidget(caption(QStringLiteral("The current FPGA image pipeline uses the validated ROM baseline. These values are informational until runtime DILA tuning is exposed by firmware.")));

    auto* pipelineBox = new QGroupBox(QStringLiteral("Active signal chain"));
    auto* form = new QFormLayout(pipelineBox);
    auto readOnly = [](const QString& value) {
        auto* label = new QLabel(value);
        label->setObjectName(QStringLiteral("readoutValue"));
        return label;
    };
    form->addRow(QStringLiteral("Sampling rate"), readOnly(QStringLiteral("25.6 MSPS")));
    form->addRow(QStringLiteral("Simulated sawtooth scan"), readOnly(QStringLiteral("2 kHz (25.6 MHz / 12800)")));
    form->addRow(QStringLiteral("Reference modulation"), readOnly(QStringLiteral("200 kHz")));
    form->addRow(QStringLiteral("CIC / FIR"), readOnly(QStringLiteral("x8 / x16 decimation")));
    form->addRow(QStringLiteral("Feature window"), readOnly(QStringLiteral("160 ... 1440")));
    layout->addWidget(pipelineBox);
    layout->addStretch();
    return page;
}

QWidget* MainWindow::wmsPage() {
    auto* page = new QWidget;
    auto* layout = new QVBoxLayout(page);
    layout->setContentsMargins(2, 4, 2, 4);
    layout->setSpacing(10);
    layout->addWidget(caption(QStringLiteral("WMS metadata describes the calibrated simulation source. Hardware laser, DAC bias and safety limits are not yet controlled from this page.")));

    auto* metadataBox = new QGroupBox(QStringLiteral("Simulation metadata"));
    auto* form = new QFormLayout(metadataBox);
    auto readOnly = [](const QString& value) {
        auto* label = new QLabel(value);
        label->setObjectName(QStringLiteral("readoutValue"));
        return label;
    };
    form->addRow(QStringLiteral("Target gas"), readOnly(QStringLiteral("CH4")));
    form->addRow(QStringLiteral("Concentration"), readOnly(QStringLiteral("5000 ppm")));
    form->addRow(QStringLiteral("Temperature / pressure"), readOnly(QStringLiteral("296 K / 1 atm")));
    form->addRow(QStringLiteral("Optical path / profile"), readOnly(QStringLiteral("1 m / Voigt")));
    layout->addWidget(metadataBox);
    layout->addStretch();
    return page;
}

void MainWindow::refreshPorts() {
    const QString current = portBox_->currentText();
    portBox_->clear();
    portBox_->addItems(device::DeviceSession::serialPorts());
    const int index = portBox_->findText(current);
    if (index >= 0)
        portBox_->setCurrentIndex(index);
}

void MainWindow::toggleConnection() {
    if (session_->connected()) {
        session_->disconnectDevice();
        return;
    }

    const auto mode = modeBox_->currentIndex() == 0 ? device::DeviceSession::Mode::Mock : device::DeviceSession::Mode::Serial;
    const int baudRate = baudBox_->currentData().toInt();
    if (!session_->connectDevice(mode, portBox_->currentText(), baudRate) && mode == device::DeviceSession::Mode::Serial) {
        connectionLabel_->setText(QStringLiteral("● Connection error"));
        connectionLabel_->setObjectName(QStringLiteral("stateError"));
        connectionLabel_->style()->unpolish(connectionLabel_);
        connectionLabel_->style()->polish(connectionLabel_);
        statusBar()->showMessage(QStringLiteral("Connection error. Check the selected serial port."));
        QMessageBox::warning(this, QStringLiteral("Connection failed"),
                             QStringLiteral("Check that the selected serial port exists and is not in use."));
    }
}

void MainWindow::startRun() {
    if (session_->running())
        return;
    pointCount_ = 0;
    displayingRecordedData_ = false;
    trajectory_->clear();
    harmonic_->clear();
    image_->clear();
    session_->setStreamSelection(streamAngles_->isChecked(), streamHarmonics_->isChecked());
    const QString mode = modeBox_->currentIndex() == 0 ? QStringLiteral("mock") : QStringLiteral("uart");
    if (saveData_->isChecked()) {
        if (!recorder_->start(recordingDirectory_->text(), mode))
            appendLog(QStringLiteral("WARNING  Unable to create the session record."));
        else
            appendLog(QStringLiteral("INFO  Session data: %1").arg(recorder_->directory()));
    } else {
        recorder_->stop();
        appendLog(QStringLiteral("INFO  Acquisition data recording is disabled."));
    }
    session_->start();
}

void MainWindow::stopRun() {
    session_->stop();
    recorder_->stop();
}

void MainWindow::clearCurrentView() {
    switch (viewTabs_->currentIndex()) {
    case 0: clearTrajectory(); break;
    case 1: clearHarmonics(); break;
    case 2: clearImage(); break;
    default: break;
    }
}

void MainWindow::clearTrajectory() {
    trajectory_->clear();
    dirty_ = true;
}

void MainWindow::clearHarmonics() {
    harmonic_->clear();
    dirty_ = true;
}

void MainWindow::clearImage() {
    image_->clear();
    pointCount_ = 0;
    dirty_ = true;
}

void MainWindow::clearLog() {
    log_->clear();
}

void MainWindow::chooseRecordingDirectory() {
    const QString directory = QFileDialog::getExistingDirectory(
        this, QStringLiteral("Choose data save location"), recordingDirectory_->text());
    if (!directory.isEmpty())
        recordingDirectory_->setText(QDir::toNativeSeparators(directory));
}

void MainWindow::loadRecordedData() {
    if (session_->running()) {
        QMessageBox::information(this, QStringLiteral("Acquisition in progress"),
                                 QStringLiteral("Stop acquisition before opening recorded data."));
        return;
    }

    const QString fileName = QFileDialog::getOpenFileName(
        this, QStringLiteral("Open a recorded session file"), recordingDirectory_->text(),
        QStringLiteral("Recorded session files (session.json fused_points.csv angles.csv harmonics.csv);;All files (*)"));
    if (fileName.isEmpty())
        return;

    const QDir sessionDirectory(QFileInfo(fileName).absolutePath());
    const QString fusedPath = sessionDirectory.filePath(QStringLiteral("fused_points.csv"));
    const QString anglesPath = sessionDirectory.filePath(QStringLiteral("angles.csv"));
    const QString harmonicsPath = sessionDirectory.filePath(QStringLiteral("harmonics.csv"));
    if (!QFileInfo::exists(fusedPath) && !QFileInfo::exists(anglesPath) && !QFileInfo::exists(harmonicsPath)) {
        QMessageBox::warning(this, QStringLiteral("Unsupported data folder"),
                             QStringLiteral("Select a file from a recorded session folder."));
        return;
    }

    const QStringList fusedColumns = {
        QStringLiteral("measurement_ticks"), QStringLiteral("image_id"), QStringLiteral("line_id"),
        QStringLiteral("point_id"), QStringLiteral("x_q13"), QStringLiteral("y_q13"),
        QStringLiteral("i1"), QStringLiteral("q1"), QStringLiteral("i2"), QStringLiteral("q2"),
        QStringLiteral("a1"), QStringLiteral("a2"), QStringLiteral("flags"), QStringLiteral("config_revision")};
    QVector<model::FusedPoint> points;
    qsizetype invalidRows = 0;
    if (QFileInfo::exists(fusedPath)) {
        const auto table = readRecordedCsv(fusedPath, fusedColumns);
        if (!table) {
            QMessageBox::warning(this, QStringLiteral("Unsupported data file"),
                                 QStringLiteral("fused_points.csv does not match the supported recording format."));
            return;
        }
        for (const QStringList& fields : table->rows) {
            const auto point = parseRecordedPoint(fields, table->columns);
            if (point) points.append(*point); else ++invalidRows;
        }
    }

    const QStringList angleColumns = {QStringLiteral("measurement_ticks"), QStringLiteral("sample_index"),
                                      QStringLiteral("x_q13"), QStringLiteral("y_q13")};
    QVector<model::AngleSample> angles;
    if (points.isEmpty() && QFileInfo::exists(anglesPath)) {
        const auto table = readRecordedCsv(anglesPath, angleColumns);
        if (!table) {
            QMessageBox::warning(this, QStringLiteral("Unsupported data file"),
                                 QStringLiteral("angles.csv does not match the supported recording format."));
            return;
        }
        for (const QStringList& fields : table->rows) {
            const auto sample = parseRecordedAngle(fields, table->columns);
            if (sample) angles.append(*sample); else ++invalidRows;
        }
    }

    const QStringList harmonicColumns = {QStringLiteral("measurement_ticks"), QStringLiteral("sample_index"),
                                         QStringLiteral("i1"), QStringLiteral("q1"), QStringLiteral("i2"), QStringLiteral("q2")};
    QVector<model::HarmonicCurve> harmonics;
    if (points.isEmpty() && QFileInfo::exists(harmonicsPath)) {
        const auto table = readRecordedCsv(harmonicsPath, harmonicColumns);
        if (!table) {
            QMessageBox::warning(this, QStringLiteral("Unsupported data file"),
                                 QStringLiteral("harmonics.csv does not match the supported recording format."));
            return;
        }
        for (const QStringList& fields : table->rows) {
            const auto curve = parseRecordedHarmonic(fields, table->columns);
            if (curve) harmonics.append(*curve); else ++invalidRows;
        }
    }
    if (points.isEmpty() && angles.isEmpty() && harmonics.isEmpty()) {
        QMessageBox::warning(this, QStringLiteral("No usable data"),
                             QStringLiteral("The selected session does not contain any valid data rows."));
        return;
    }

    trajectory_->clear();
    harmonic_->clear();
    image_->clear();
    int displayTab = 0;
    if (!points.isEmpty()) {
        double xMinimum = points.first().xDegrees(), xMaximum = xMinimum;
        double yMinimum = points.first().yDegrees(), yMaximum = yMinimum;
        quint16 maximumPoint = 0, maximumLine = 0;
        for (const model::FusedPoint& point : points) {
            xMinimum = qMin(xMinimum, point.xDegrees()); xMaximum = qMax(xMaximum, point.xDegrees());
            yMinimum = qMin(yMinimum, point.yDegrees()); yMaximum = qMax(yMaximum, point.yDegrees());
            maximumPoint = qMax(maximumPoint, point.pointId); maximumLine = qMax(maximumLine, point.lineId);
        }
        if (qFuzzyCompare(xMinimum, xMaximum)) { xMinimum -= 0.5; xMaximum += 0.5; }
        if (qFuzzyCompare(yMinimum, yMaximum)) { yMinimum -= 0.5; yMaximum += 0.5; }
        trajectory_->configureRange(xMinimum, xMaximum, yMinimum, yMaximum);
        image_->configure(qMax(2, int(maximumPoint) + 1), qMax(2, int(maximumLine) + 1), xMinimum, xMaximum, yMinimum, yMaximum);
        for (const model::FusedPoint& point : points) {
            trajectory_->append(point.xDegrees(), point.yDegrees());
            harmonic_->append(point.amplitude1f(), point.amplitude2f(), point.ratio());
            image_->add(point);
        }
        const model::FusedPoint& last = points.last();
        xAngleValue_->setText(QStringLiteral("%1°").arg(last.xDegrees(), 0, 'f', 3));
        yAngleValue_->setText(QStringLiteral("%1°").arg(last.yDegrees(), 0, 'f', 3));
        oneFValue_->setText(QString::number(last.amplitude1f(), 'f', 3));
        twoFValue_->setText(QString::number(last.amplitude2f(), 'f', 3));
        ratioValue_->setText(QString::number(last.ratio(), 'f', 4));
        displayTab = 2;
    } else {
        if (!angles.isEmpty()) {
            double xMinimum = angles.first().xDegrees(), xMaximum = xMinimum;
            double yMinimum = angles.first().yDegrees(), yMaximum = yMinimum;
            for (const model::AngleSample& sample : angles) {
                xMinimum = qMin(xMinimum, sample.xDegrees()); xMaximum = qMax(xMaximum, sample.xDegrees());
                yMinimum = qMin(yMinimum, sample.yDegrees()); yMaximum = qMax(yMaximum, sample.yDegrees());
            }
            if (qFuzzyCompare(xMinimum, xMaximum)) { xMinimum -= 0.5; xMaximum += 0.5; }
            if (qFuzzyCompare(yMinimum, yMaximum)) { yMinimum -= 0.5; yMaximum += 0.5; }
            trajectory_->configureRange(xMinimum, xMaximum, yMinimum, yMaximum);
            for (const model::AngleSample& sample : angles) trajectory_->append(sample.xDegrees(), sample.yDegrees());
            const model::AngleSample& last = angles.last();
            xAngleValue_->setText(QStringLiteral("%1°").arg(last.xDegrees(), 0, 'f', 3));
            yAngleValue_->setText(QStringLiteral("%1°").arg(last.yDegrees(), 0, 'f', 3));
        }
        if (!harmonics.isEmpty()) {
            for (const model::HarmonicCurve& curve : harmonics)
                harmonic_->append(curve.amplitude1f(), curve.amplitude2f(), curve.amplitude1f() == 0.0 ? 0.0 : curve.amplitude2f() / curve.amplitude1f());
            const model::HarmonicCurve& last = harmonics.last();
            oneFValue_->setText(QString::number(last.amplitude1f(), 'f', 3));
            twoFValue_->setText(QString::number(last.amplitude2f(), 'f', 3));
            ratioValue_->setText(QString::number(last.amplitude1f() == 0.0 ? 0.0 : last.amplitude2f() / last.amplitude1f(), 'f', 4));
            if (angles.isEmpty()) displayTab = 1;
        }
    }
    pointCount_ = points.size();
    displayingRecordedData_ = true;
    dirty_ = true;
    viewTabs_->setCurrentIndex(displayTab);
    appendLog(QStringLiteral("INFO  Loaded recorded data from %1%2.")
                  .arg(QDir::toNativeSeparators(sessionDirectory.absolutePath()))
                  .arg(invalidRows ? QStringLiteral(" (%1 invalid rows skipped)").arg(invalidRows) : QString()));
    statusBar()->showMessage(QStringLiteral("Recorded data loaded: %1 fused points, %2 angle samples, %3 harmonic samples.")
                                 .arg(points.size()).arg(angles.size()).arg(harmonics.size()));
}

void MainWindow::onPoint(const model::FusedPoint& point) {
    if (!streamAngles_->isChecked() || !streamHarmonics_->isChecked())
        return;
    mirrorFeedbackActive_ = (point.flags & 0x0010u) != 0;
    displayingRecordedData_ = false;
    ++pointCount_;
    image_->add(point);
    recorder_->append(point);
    dirty_ = true;
}

void MainWindow::appendLog(const QString& text) {
    if (log_) {
        auto* scrollbar = log_->verticalScrollBar();
        const bool followTail = scrollbar->value() >= scrollbar->maximum();
        log_->appendPlainText(QStringLiteral("[%1] %2")
                                  .arg(QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss.zzz")), text));
        if (followTail)
            scrollbar->setValue(scrollbar->maximum());
    }
}

void MainWindow::refreshPlots() {
    if (!dirty_)
        return;
    trajectory_->update();
    harmonic_->update();
    image_->update();
    const bool showImageStatistics = displayingRecordedData_ || (streamAngles_->isChecked() && streamHarmonics_->isChecked());
    validCellsValue_->setText(showImageStatistics
                                  ? QLocale().toString(image_->validCells()) : QStringLiteral("—"));
    imagePointsValue_->setText(showImageStatistics
                                   ? QLocale().toString(pointCount_) : QStringLiteral("—"));
    dirty_ = false;
}

void MainWindow::applyMirrorConfig() {
    if (xMin_->value() >= xMax_->value() || yMin_->value() >= yMax_->value()) {
        QMessageBox::warning(this, QStringLiteral("Invalid scan range"),
                             QStringLiteral("The minimum angle must be smaller than the maximum angle."));
        return;
    }
    if (frameFrequency_->value() > xFrequency_->value() * 2.0) {
        QMessageBox::warning(this, QStringLiteral("Invalid frame rate"),
                             QStringLiteral("Mirror frame rate must not exceed twice the X frequency."));
        return;
    }

    using Register = registers::Address;
    const auto toQ13 = [](double degrees) {
        return qint16(qBound(-32768LL, qRound64(degrees * 8192.0), 32767LL));
    };
    const qint16 xMinimum = toQ13(xMin_->value());
    const qint16 xMaximum = toQ13(xMax_->value());
    const qint16 yMinimum = toQ13(yMin_->value());
    const qint16 yMaximum = toQ13(yMax_->value());
    session_->writeRegister(quint32(Register::MirrorXMinQ13), quint32(quint16(xMinimum)));
    session_->writeRegister(quint32(Register::MirrorXMaxQ13), quint32(quint16(xMaximum)));
    session_->writeRegister(quint32(Register::MirrorYMinQ13), quint32(quint16(yMinimum)));
    session_->writeRegister(quint32(Register::MirrorYMaxQ13), quint32(quint16(yMaximum)));
    session_->writeRegister(quint32(Register::MirrorXFreqMhz), quint32(qRound64(xFrequency_->value() * 1000.0)));
    session_->writeRegister(quint32(Register::MirrorFrameFreqMhz), quint32(qRound64(frameFrequency_->value() * 1000.0)));
    session_->writeRegister(quint32(Register::MirrorFeedbackHz), quint32(feedback_->value()));
    session_->writeRegister(quint32(Register::ScanPolicy), quint32(scanPolicy_->currentIndex()));
    session_->writeRegister(quint32(Register::StopAction), quint32(stopAction_->currentIndex()));
    session_->writeRegister(quint32(Register::ImageLineCount), quint32(lines_->value()));
    session_->writeRegister(quint32(Register::StreamRateLimitHz), quint32(streamRate_->value()));
    session_->validateAndCommit();
    image_->configure(50, lines_->value(), xMin_->value(), xMax_->value(), yMin_->value(), yMax_->value());
    trajectory_->configureRange(xMin_->value(), xMax_->value(), yMin_->value(), yMax_->value());
    statusBar()->showMessage(QStringLiteral("Scan parameters applied."));
    appendLog(QStringLiteral("INFO  Scan parameters applied: X %1 Hz, frame %2 Hz, %3 image lines, %4.")
                   .arg(xFrequency_->value(), 0, 'f', 3)
                   .arg(frameFrequency_->value(), 0, 'f', 3)
                   .arg(lines_->value())
                   .arg(scanPolicy_->currentText()));
}

void MainWindow::updateScanGeometry() {
    const double xFrequency = xFrequency_->value();
    // The image path has a 2..2048-line geometry.  Bound the selectable frame
    // rate so its physical raster line count always fits that geometry.
    const double minimumFrameRate = qMax(0.001, 2.0 * xFrequency / 2048.0);
    const double maximumFrameRate = qMin(40.0, xFrequency);
    frameFrequency_->setRange(minimumFrameRate, maximumFrameRate);
    const int physicalLines = qBound(2, static_cast<int>(std::floor(
        (2.0 * xFrequency) / frameFrequency_->value())), 2048);
    lines_->setValue(physicalLines);
}

void MainWindow::updateStreamRateRange() {
    // A 48-byte fused frame exceeds 921600 baud at 2 kHz.  Single-stream
    // operation is safe at 2 kHz; keep the legacy 500 Hz cap for fused data.
    const int maximumRate = streamAngles_->isChecked() && streamHarmonics_->isChecked() ? 500 : 2000;
    streamRate_->setMaximum(maximumRate);
    if (streamRate_->value() > maximumRate)
        streamRate_->setValue(maximumRate);
}

void MainWindow::applyStaticPoint() {
    const auto toQ13 = [](double degrees) {
        return qint16(qBound(-32768LL, qRound64(degrees * 8192.0), 32767LL));
    };
    session_->staticPoint(toQ13(staticX_->value()), toQ13(staticY_->value()));
    appendLog(QStringLiteral("INFO  Static offset sent: X %1 deg, Y %2 deg.")
                  .arg(staticX_->value(), 0, 'f', 4)
                  .arg(staticY_->value(), 0, 'f', 4));
}

void MainWindow::sendMirrorAction(int action) {
    if (action == 0) {
        session_->returnZero();
        appendLog(QStringLiteral("INFO  Return-zero command sent."));
    } else {
        session_->returnScanStart();
        appendLog(QStringLiteral("INFO  Return-to-origin command sent."));
    }
}

}  // namespace ch4::app

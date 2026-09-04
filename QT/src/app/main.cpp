#include "app/main_window.h"

#include <QApplication>
#include <QStyleFactory>
#include <QTimer>

int main(int argc, char* argv[]) {
    QApplication application(argc, argv);
    QApplication::setApplicationName(QStringLiteral("CH4 Imaging Control"));
    QApplication::setOrganizationName(QStringLiteral("CH4 Imaging"));
    QApplication::setStyle(QStyleFactory::create(QStringLiteral("Fusion")));
    application.setStyleSheet(QStringLiteral(R"(
        QWidget { background: #f3f4f6; color: #263238; font-family: "Microsoft YaHei UI"; font-size: 12px; }
        #appHeader, #sidePanel, #workspacePanel, #diagnosticsPanel { background: #ffffff; border: 1px solid #cfd5da; border-radius: 2px; }
        #appTitle { font-size: 18px; font-weight: 700; color: #263238; }
        #headerFieldLabel { background: transparent; color: #37474f; }
        #sectionTitle { font-size: 14px; font-weight: 600; color: #263238; }
        #caption { color: #607d8b; font-size: 11px; }
        #stateConnected { color: #087443; font-weight: 600; }
        #stateRunning { color: #175cd3; font-weight: 600; }
        #stateIdle { color: #78909c; }
        #stateError { color: #b42318; font-weight: 600; }
        #telemetryLabel { color: #475467; }
        #telemetryValue { color: #101828; font-family: Consolas, "Cascadia Mono", monospace; font-weight: 600; }
        #telemetrySection { color: #667085; font-size: 10px; font-weight: 600; padding-top: 6px; border-bottom: 1px solid #e4e7ec; }
        QTabBar { background: #edf0f2; }
        QTabBar::tab { padding: 6px 10px; border: 1px solid transparent; color: #455a64; background: #edf0f2; }
        QTabBar::tab:hover { background: #e1e7eb; }
        QTabBar::tab:selected { color: #1f4e68; background: #ffffff; border: 1px solid #cfd5da; font-weight: 600; }
        QLineEdit, QPlainTextEdit, QComboBox, QSpinBox, QDoubleSpinBox { background: #ffffff; border: 1px solid #b9c1c7; border-radius: 2px; padding: 3px 6px; selection-background-color: #b8d3e2; }
        QLineEdit:focus, QComboBox:focus, QSpinBox:focus, QDoubleSpinBox:focus, QPlainTextEdit:focus { border: 1px solid #285a75; }
        QPushButton { background: #fafafa; border: 1px solid #aeb8bf; border-radius: 2px; padding: 5px 10px; min-height: 18px; }
        QPushButton:hover { background: #e8f0f4; border-color: #285a75; }
        QPushButton:pressed { background: #d6e5ec; }
        QPushButton:disabled { color: #9aa4aa; background: #eef0f1; border-color: #d5dadd; }
        #numericStepButton { background: #f7f9fa; border: 1px solid #b9c1c7; border-radius: 0px; padding: 0px; min-height: 0px; }
        #numericStepButton:hover { background: #dcebf3; border-color: #285a75; }
        #numericStepButton:pressed { background: #c6dce8; }
        #primaryButton { background: #285a75; color: white; border-color: #285a75; }
        #primaryButton:hover { background: #356f8d; }
        #dangerButton { color: #a33a35; }
        QGroupBox { background: transparent; border: 1px solid #d9dfe3; border-radius: 2px; margin-top: 9px; padding: 8px 6px 6px; font-weight: 600; color: #37474f; }
        QGroupBox::title { subcontrol-origin: margin; left: 6px; padding: 0 3px; background: #ffffff; }
        #notice { color: #546e7a; background: #f5f7f8; border-left: 3px solid #78909c; padding: 7px; }
        QSplitter::handle { background: #cfd5da; }
        QStatusBar { background: #ffffff; border-top: 1px solid #cfd5da; color: #607d8b; }
    )"));
    ch4::app::MainWindow window;
    window.show();
    if (application.arguments().contains(QStringLiteral("--smoke-test")))
        QTimer::singleShot(250, &application, &QCoreApplication::quit);
    return application.exec();
}

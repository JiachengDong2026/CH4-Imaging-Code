#include "app/main_window.h"

#include <QApplication>
#include <QStyleFactory>

int main(int argc, char* argv[]) {
    QApplication application(argc, argv);
    QApplication::setApplicationName(QStringLiteral("CH4 Imaging Control"));
    QApplication::setOrganizationName(QStringLiteral("CH4 Imaging"));
    QApplication::setStyle(QStyleFactory::create(QStringLiteral("Fusion")));
    application.setStyleSheet(QStringLiteral(R"(
        QWidget { background: #f7f9fc; color: #1f2937; font-family: "Microsoft YaHei UI"; font-size: 14px; }
        #navigation { background: #ffffff; border: 0; border-right: 1px solid #e5e7eb; padding: 18px 10px; outline: 0; }
        #navigation::item { height: 44px; padding-left: 14px; border-radius: 7px; }
        #navigation::item:selected { background: #e8f1ff; color: #1769aa; font-weight: 600; }
        #pageTitle { font-size: 26px; font-weight: 700; color: #111827; }
        #secondary { color: #667085; }
        #card { background: #ffffff; border: 1px solid #e5e7eb; border-radius: 10px; min-height: 150px; }
        #cardTitle { color: #667085; font-size: 13px; }
        #cardValue { color: #1769aa; font-size: 25px; font-weight: 700; }
        QStatusBar { background: #ffffff; border-top: 1px solid #e5e7eb; }
    )"));
    ch4::app::MainWindow window;
    window.show();
    return application.exec();
}


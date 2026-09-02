#pragma once

#include <QMainWindow>

class QListWidget;
class QStackedWidget;

namespace ch4::app {

class MainWindow final : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(QWidget* parent = nullptr);

private:
    QWidget* createOverviewPage();
    QWidget* createPlaceholderPage(const QString& title, const QString& description);
    QListWidget* navigation_ = nullptr;
    QStackedWidget* pages_ = nullptr;
};

}  // namespace ch4::app


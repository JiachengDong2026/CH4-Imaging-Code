#include "app/main_window.h"

#include "protocol/generated_protocol.h"

#include <QFrame>
#include <QHBoxLayout>
#include <QLabel>
#include <QListWidget>
#include <QStackedWidget>
#include <QStatusBar>
#include <QVBoxLayout>

namespace ch4::app {

namespace {
QLabel* heading(const QString& text) {
    auto* label = new QLabel(text);
    label->setObjectName(QStringLiteral("pageTitle"));
    return label;
}

QFrame* statusCard(const QString& title, const QString& value, const QString& note) {
    auto* card = new QFrame;
    card->setObjectName(QStringLiteral("card"));
    auto* layout = new QVBoxLayout(card);
    auto* titleLabel = new QLabel(title);
    titleLabel->setObjectName(QStringLiteral("cardTitle"));
    auto* valueLabel = new QLabel(value);
    valueLabel->setObjectName(QStringLiteral("cardValue"));
    auto* noteLabel = new QLabel(note);
    noteLabel->setWordWrap(true);
    noteLabel->setObjectName(QStringLiteral("secondary"));
    layout->addWidget(titleLabel);
    layout->addWidget(valueLabel);
    layout->addWidget(noteLabel);
    layout->addStretch();
    return card;
}
}

MainWindow::MainWindow(QWidget* parent) : QMainWindow(parent) {
    setWindowTitle(QStringLiteral("甲烷扫描成像控制中心 — 阶段 0"));
    resize(1180, 760);
    setMinimumSize(920, 620);

    auto* central = new QWidget;
    auto* root = new QHBoxLayout(central);
    root->setContentsMargins(0, 0, 0, 0);
    root->setSpacing(0);

    navigation_ = new QListWidget;
    navigation_->setObjectName(QStringLiteral("navigation"));
    navigation_->setFixedWidth(210);
    navigation_->addItems({QStringLiteral("总览"), QStringLiteral("连接与设备"),
                           QStringLiteral("快反镜"), QStringLiteral("采集与 DILA"),
                           QStringLiteral("WMS 与仿真"), QStringLiteral("甲烷图像"),
                           QStringLiteral("数据与日志")});

    pages_ = new QStackedWidget;
    pages_->addWidget(createOverviewPage());
    pages_->addWidget(createPlaceholderPage(QStringLiteral("连接与设备"), QStringLiteral("阶段 1 接入 Mock 和 UART；阶段 2 接入 USB3.0。")));
    pages_->addWidget(createPlaceholderPage(QStringLiteral("快反镜"), QStringLiteral("阶段 1 接入扫描参数、静态偏转、实际轨迹和回零控制。")));
    pages_->addWidget(createPlaceholderPage(QStringLiteral("采集与 DILA"), QStringLiteral("阶段 1 接入仿真 ROM、1f/2f 解调参数和波形显示。")));
    pages_->addWidget(createPlaceholderPage(QStringLiteral("WMS 与仿真"), QStringLiteral("当前只显示仿真参数；真实 DAC 和激光安全控制在阶段 3 实现。")));
    pages_->addWidget(createPlaceholderPage(QStringLiteral("甲烷图像"), QStringLiteral("阶段 1 按实际反馈角度重建相对甲烷信号图像，不标注真实 ppm·m。")));
    pages_->addWidget(createPlaceholderPage(QStringLiteral("数据与日志"), QStringLiteral("阶段 1 将每次会话写入项目 Data 目录，并显示通信与错误统计。")));
    connect(navigation_, &QListWidget::currentRowChanged, pages_, &QStackedWidget::setCurrentIndex);
    navigation_->setCurrentRow(0);

    root->addWidget(navigation_);
    root->addWidget(pages_, 1);
    setCentralWidget(central);
    statusBar()->showMessage(QStringLiteral("工程骨架已就绪；当前未连接设备"));
}

QWidget* MainWindow::createOverviewPage() {
    auto* page = new QWidget;
    auto* layout = new QVBoxLayout(page);
    layout->setContentsMargins(32, 28, 32, 28);
    layout->setSpacing(18);
    layout->addWidget(heading(QStringLiteral("系统总览")));
    auto* subtitle = new QLabel(QStringLiteral("阶段 0 · 工程骨架与统一协议已冻结"));
    subtitle->setObjectName(QStringLiteral("secondary"));
    layout->addWidget(subtitle);

    auto* cards = new QHBoxLayout;
    cards->setSpacing(16);
    cards->addWidget(statusCard(QStringLiteral("设备连接"), QStringLiteral("未连接"), QStringLiteral("阶段 1 提供 Mock 与真实串口模式")));
    cards->addWidget(statusCard(QStringLiteral("协议"), QStringLiteral("V%1").arg(protocol::kVersion), QStringLiteral("A5 5A · 小端 · CRC-16/CCITT-FALSE")));
    cards->addWidget(statusCard(QStringLiteral("成像量"), QStringLiteral("相对信号"), QStringLiteral("未标定前不显示真实浓度")));
    layout->addLayout(cards);
    layout->addStretch();
    return page;
}

QWidget* MainWindow::createPlaceholderPage(const QString& title, const QString& description) {
    auto* page = new QWidget;
    auto* layout = new QVBoxLayout(page);
    layout->setContentsMargins(32, 28, 32, 28);
    layout->addWidget(heading(title));
    auto* text = new QLabel(description);
    text->setObjectName(QStringLiteral("secondary"));
    text->setWordWrap(true);
    layout->addWidget(text);
    layout->addStretch();
    return page;
}

}  // namespace ch4::app

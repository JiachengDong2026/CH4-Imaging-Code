/* CH569 USB3/HSPI unidirectional streaming firmware.
 * FPGA -> HSPI RX DMA -> endp1RTbuff -> USB3 EP1 IN -> PC.
 */
#define FREQ_SYS 120000000

#include "CH56x_common.h"
#include "CH56x_usb20.h"
#include "CH56x_usb30.h"
#include "CH56xUSB30_LIB.H"

#define STREAM_BLOCK_BYTES 4096u
#define FPGA_TX_ENABLE(value) do {        \
    if (value) R32_PA_OUT |= GPIO_Pin_15; \
    else       R32_PA_CLR |= GPIO_Pin_15; \
} while (0)

volatile UINT8 HspiRxDone = 0;
volatile UINT8 HspiRxError = 0;
volatile UINT32 HspiBlocksReceived = 0;
volatile UINT32 HspiBlocksDropped = 0;
volatile UINT32 UsbBlocksSent = 0;

void HSPI_IRQHandler(void) __attribute__((interrupt("WCH-Interrupt-fast")));

static void DebugInit(UINT32 baudrate)
{
    UINT32 system_clock = FREQ_SYS;
    UINT32 divisor = 10 * system_clock * 2 / 16 / baudrate;
    divisor = (divisor + 5) / 10;
    R8_UART1_DIV = 1;
    R16_UART1_DL = divisor;
    R8_UART1_FCR = RB_FCR_FIFO_TRIG | RB_FCR_TX_FIFO_CLR |
                   RB_FCR_RX_FIFO_CLR | RB_FCR_FIFO_EN;
    R8_UART1_LCR = RB_LCR_WORD_SZ;
    R8_UART1_IER = RB_IER_TXD_EN;
    R32_PA_SMT |= (1 << 8) | (1 << 7);
    R32_PA_DIR |= (1 << 8);
}

static void HspiInit(void)
{
    R32_PA_DIR |= (1 << 9) | (1 << 11) | (1 << 21);
    R32_PA_DIR |= (1 << 10);
    R32_PA_DRV |= (1 << 11);

    R8_HSPI_CFG &= ~(RB_HSPI_MODE | RB_HSPI_MSK_SIZE);
    R8_HSPI_CFG |= RB_HSPI_MODE | RB_HSPI_DAT32_MOD;
    R8_HSPI_CFG &= ~(RB_HSPI_HW_ACK | RB_HSPI_RX_TOG_EN | RB_HSPI_TX_TOG_EN);
    R8_HSPI_AUX |= RB_HSPI_REQ_FT | RB_HSPI_TCK_MOD | RB_HSPI_RCK_MOD;
    R8_HSPI_AUX &= ~(RB_HSPI_ACK_TX_MOD | RB_HSPI_ACK_CNT_SEL);
    R8_HSPI_CTRL &= ~(RB_HSPI_ALL_CLR | RB_HSPI_TRX_RST);

    R8_HSPI_INT_FLAG = 0x0f;
    R8_HSPI_INT_EN = RB_HSPI_IE_R_DONE | RB_HSPI_IE_FIFO_OV;
    R32_HSPI_UDF0 = 0;
    R32_HSPI_UDF1 = 0;
    R32_HSPI_RX_ADDR0 = (UINT32)endp1RTbuff;
    R16_HSPI_DMA_LEN0 = STREAM_BLOCK_BYTES - 1;
    R16_HSPI_DMA_LEN1 = STREAM_BLOCK_BYTES - 1;
    R8_HSPI_CTRL |= RB_HSPI_ENABLE | RB_HSPI_DMA_EN;
    PFIC_EnableIRQ(HSPI_IRQn);
}

static void Usb3Init(void)
{
    R32_USB_CONTROL = 0;
    PFIC_EnableIRQ(USBSS_IRQn);
    PFIC_EnableIRQ(LINK_IRQn);
    PFIC_EnableIRQ(TMR0_IRQn);
    R8_TMR0_INTER_EN = RB_TMR_IE_CYC_END;
    TMR0_TimerInit(67000000);
    USB30D_init(ENABLE);
    USBSS->UEP1_TX_DMA = (UINT32)endp1RTbuff;
}

static UINT8 ReceiveHspiBlock(void)
{
    HspiRxDone = 0;
    HspiRxError = 0;
    R32_HSPI_RX_ADDR0 = (UINT32)endp1RTbuff;
    R8_HSPI_INT_FLAG = 0x0f;
    FPGA_TX_ENABLE(1);
    while (!HspiRxDone) { }
    FPGA_TX_ENABLE(0);
    return HspiRxError == 0;
}

static void SendUsbBlock(void)
{
    ENDP1_Tx_Full_Flag = 0;
    USBSS->UEP1_TX_DMA = (UINT32)endp1RTbuff;
    USB30_IN_Set(ENDP_1, ENABLE, ACK, DEF_ENDP1_IN_BURST_LEVEL, 1024);
    USB30_Send_ERDY(ENDP_1 | IN, DEF_ENDP1_IN_BURST_LEVEL);
    while (!ENDP1_Tx_Full_Flag) { }
    UsbBlocksSent++;
}

int main(void)
{
    SystemInit(FREQ_SYS);
    Delay_Init(FREQ_SYS);
    DebugInit(115200);

    GPIOA_ModeCfg(GPIO_Pin_12, GPIO_ModeIN_PD_NSMT);
    GPIOA_ModeCfg(GPIO_Pin_14, GPIO_Highspeed_PP_16mA);
    GPIOA_ModeCfg(GPIO_Pin_15, GPIO_Highspeed_PP_16mA);
    GPIOA_ResetBits(GPIO_Pin_14 | GPIO_Pin_15);

    while (!GPIOA_ReadPortPin(GPIO_Pin_12)) { }
    mDelaymS(100);
    while (!GPIOA_ReadPortPin(GPIO_Pin_12)) { }

    HspiInit();
    mDelaymS(100);
    Usb3Init();

    while (1) {
        if (ReceiveHspiBlock())
            SendUsbBlock();
        else
            HspiBlocksDropped++;
    }
}

void HSPI_IRQHandler(void)
{
    UINT8 flags = R8_HSPI_INT_FLAG;

    if (flags & RB_HSPI_IF_R_DONE) {
        UINT8 status;
        R8_HSPI_INT_FLAG = RB_HSPI_IF_R_DONE;
        status = R8_HSPI_RTX_STATUS;
        HspiRxError = (status & (RB_HSPI_CRC_ERR | RB_HSPI_NUM_MIS)) != 0;
        if (!HspiRxError)
            HspiBlocksReceived++;
        HspiRxDone = 1;
    }

    if (flags & RB_HSPI_IF_FIFO_OV) {
        R8_HSPI_INT_FLAG = RB_HSPI_IF_FIFO_OV;
        HspiRxError = 1;
        HspiRxDone = 1;
    }
}

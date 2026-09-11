using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

internal static class Usb3LoopbackTest
{
    private const uint DeviceIndex = 0;
    private const uint OutEndpoint = 0x02;
    // CH375ReadEndP uses the pipe number here; pipe 1 maps to USB endpoint 0x81.
    private const uint InEndpoint = 1;
    private const int DefaultTransferSize = 4096;

    [DllImport("CH375DLL.dll", CallingConvention = CallingConvention.StdCall)]
    private static extern IntPtr CH375OpenDevice(uint index);

    [DllImport("CH375DLL.dll", CallingConvention = CallingConvention.StdCall)]
    private static extern void CH375CloseDevice(uint index);

    [DllImport("CH375DLL.dll", CallingConvention = CallingConvention.StdCall)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CH375WriteData(
        uint index, byte[] buffer, ref uint length);

    [DllImport("CH375DLL.dll", CallingConvention = CallingConvention.StdCall)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CH375ReadData(
        uint index, byte[] buffer, ref uint length);

    [DllImport("CH375DLL.dll", CallingConvention = CallingConvention.StdCall)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CH375WriteEndP(
        uint index, uint endpoint, byte[] buffer, ref uint length);

    [DllImport("CH375DLL.dll", CallingConvention = CallingConvention.StdCall)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CH375ReadEndP(
        uint index, uint endpoint, byte[] buffer, ref uint length);

    [DllImport("CH375DLL.dll", CallingConvention = CallingConvention.StdCall)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CH375SetTimeout(
        uint index, uint writeTimeoutMilliseconds, uint readTimeoutMilliseconds);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string moduleName);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetModuleFileName(
        IntPtr module, StringBuilder fileName, int size);

    private static int Main(string[] args)
    {
        int iterations = 1;
        int transferSize = DefaultTransferSize;
        bool useEndpointApi = false;
        bool writeOnly = false;
        bool readOnly = false;
        bool streamMode = false;

        for (int argIndex = 0; argIndex < args.Length; argIndex++)
        {
            string arg = args[argIndex];
            int parsed;
            if (argIndex == 0 && int.TryParse(arg, out parsed) && parsed > 0)
            {
                iterations = parsed;
            }
            else if (arg == "--api" && argIndex + 1 < args.Length)
            {
                string api = args[++argIndex].ToLowerInvariant();
                if (api == "standard")
                    useEndpointApi = false;
                else if (api == "endpoint")
                    useEndpointApi = true;
                else
                    return Usage("--api 只接受 standard 或 endpoint。");
            }
            else if (arg == "--size" && argIndex + 1 < args.Length &&
                     int.TryParse(args[++argIndex], out parsed) &&
                     (parsed == 1024 || parsed == 4096))
            {
                transferSize = parsed;
            }
            else if (arg == "--write-only")
            {
                writeOnly = true;
            }
            else if (arg == "--read-only")
            {
                readOnly = true;
            }
            else if (arg == "--stream")
            {
                streamMode = true;
                readOnly = true;
                useEndpointApi = true;
                transferSize = DefaultTransferSize;
            }
            else
            {
                return Usage("无法识别参数：" + arg);
            }
        }

        if (writeOnly && readOnly)
            return Usage("--write-only 和 --read-only 不能同时使用。");

        Console.WriteLine(streamMode
            ? "ACX750-CH569 USB3.0 融合点流式接收测试"
            : "ACX750-CH569 USB3.0 最小回环测试");
        string route = streamMode
            ? "USB EP 0x81 IN（每块67个FUSED_POINT）"
            : readOnly
            ? "USB EP 0x81 IN（只读上一笔诊断）"
            : writeOnly
                ? "USB EP 0x02 OUT（只写诊断）"
                : "USB EP 0x02 OUT -> FPGA -> USB EP 0x81 IN";
        Console.WriteLine("设备 0，{0} API，{1}，每次 {2} 字节",
            useEndpointApi ? "端点" : "标准批量", route, transferSize);

        PrintCandidateDllInfo();

        IntPtr handle;
        try
        {
            handle = CH375OpenDevice(DeviceIndex);
        }
        catch (DllNotFoundException)
        {
            Console.Error.WriteLine("失败：程序目录中找不到 CH375DLL.dll。");
            return 3;
        }
        catch (BadImageFormatException)
        {
            Console.Error.WriteLine("失败：EXE 与 CH375DLL.dll 位数不匹配；两者都必须为 x86。");
            return 4;
        }
        catch (EntryPointNotFoundException exception)
        {
            Console.Error.WriteLine("失败：CH375DLL.dll 缺少入口点：{0}", exception.Message);
            return 6;
        }

        PrintLoadedDllInfo();

        if (handle == IntPtr.Zero || handle == new IntPtr(-1))
        {
            Console.Error.WriteLine("失败：无法打开设备 0。请关闭官方 USB3.0Demo.exe，并检查驱动和连接。");
            return 5;
        }

        Console.WriteLine("设备打开成功，句柄=0x{0:X}", handle.ToInt64());
        try
        {
            if (!CH375SetTimeout(DeviceIndex, 3000, 3000))
                Console.WriteLine("警告：设置 3 秒读写超时失败，将使用驱动默认值。");

            var tx = new byte[transferSize];
            var rx = new byte[transferSize];
            long totalBytes = 0;
            bool sawDiagnosticPass = false;
            int expectedStreamSequence = -1;
            var totalTimer = Stopwatch.StartNew();

            for (int iteration = 0; iteration < iterations; iteration++)
            {
                for (int i = 0; i < tx.Length; i++)
                    tx[i] = (byte)((i + iteration) & 0xFF);
                Array.Clear(rx, 0, rx.Length);

                var timer = Stopwatch.StartNew();
                if (!readOnly)
                {
                    uint writeLength = (uint)transferSize;
                    bool writeOk = useEndpointApi
                        ? CH375WriteEndP(DeviceIndex, OutEndpoint, tx, ref writeLength)
                        : CH375WriteData(DeviceIndex, tx, ref writeLength);
                    long writeMilliseconds = timer.ElapsedMilliseconds;
                    Console.WriteLine(
                        "[{0}/{1}] WRITE api={2} ok={3} actual={4}/{5} elapsed={6} ms",
                        iteration + 1, iterations,
                        useEndpointApi ? "WriteEndP(EP2)" : "WriteData",
                        writeOk, writeLength, transferSize, writeMilliseconds);
                    if (!writeOk)
                    {
                        Console.Error.WriteLine("第 {0} 次失败：EP2 写入调用失败。", iteration + 1);
                        return 10;
                    }
                    if (writeLength != transferSize)
                    {
                        Console.Error.WriteLine("第 {0} 次失败：EP2 仅写入 {1}/{2} 字节。",
                            iteration + 1, writeLength, transferSize);
                        return 11;
                    }
                }

                if (writeOnly)
                {
                    totalBytes += transferSize;
                    Console.WriteLine("USB_EP2_WRITE_PASS：实际写入 {0}/{0} 字节。", transferSize);
                    continue;
                }

                int received = 0;
                var readTimer = Stopwatch.StartNew();
                while (received < transferSize && readTimer.ElapsedMilliseconds < 3000)
                {
                    var chunk = new byte[transferSize - received];
                    uint chunkLength = (uint)chunk.Length;
                    bool readOk = useEndpointApi
                        ? CH375ReadEndP(DeviceIndex, InEndpoint, chunk, ref chunkLength)
                        : CH375ReadData(DeviceIndex, chunk, ref chunkLength);
                    if (!readOk)
                    {
                        Console.Error.WriteLine("第 {0} 次失败：EP1 读取调用失败。", iteration + 1);
                        return 12;
                    }

                    if (chunkLength == 0)
                    {
                        Thread.Sleep(10);
                        continue;
                    }

                    Buffer.BlockCopy(chunk, 0, rx, received, (int)chunkLength);
                    received += (int)chunkLength;
                }
                timer.Stop();

                Console.WriteLine(
                    "[{0}/{1}] READ api={2} actual={3}/{4} elapsed={5} ms",
                    iteration + 1, iterations,
                    useEndpointApi ? "ReadEndP(pipe1)" : "ReadData",
                    received, transferSize, readTimer.ElapsedMilliseconds);

                if (received != transferSize)
                {
                    Console.Error.WriteLine("第 {0} 次失败：EP1 仅读回 {1}/{2} 字节。",
                        iteration + 1, received, transferSize);
                    return 13;
                }

                if (streamMode)
                {
                    int receivedSequence;
                    if (!ValidateFusedPointStreamBlock(rx, expectedStreamSequence,
                        out receivedSequence))
                        return 16;
                    expectedStreamSequence = (receivedSequence + 1) & 0xFFFF;
                    totalBytes += transferSize;
                    Console.WriteLine("[{0}/{1}] USB3_STREAM_BLOCK_PASS，数据块索引 {2}。",
                        iteration + 1, iterations, iteration);
                    continue;
                }

                bool hasDiagnosticFooter = PrintHspiDiagnosticFooter(rx);
                int compareLength = hasDiagnosticFooter ? DefaultTransferSize - 16 : transferSize;

                for (int i = 0; i < compareLength; i++)
                {
                    if (rx[i] != tx[i])
                    {
                        Console.Error.WriteLine(
                            "第 {0} 次校验失败：偏移 0x{1:X4}，发送 0x{2:X2}，收到 0x{3:X2}。",
                            iteration + 1, i, tx[i], rx[i]);
                        return 14;
                    }
                }

                if (hasDiagnosticFooter)
                {
                    bool diagnosticPass = rx[4084] == 0 && rx[4090] == 0x05;
                    if (!diagnosticPass)
                    {
                        Console.Error.WriteLine(
                            "HSPI_DIAG_FAIL：第 {0} 次载荷前 {1} 字节一致，但 HSPI CRC、序号或完成阶段异常。",
                            iteration + 1, compareLength);
                        return 15;
                    }

                    sawDiagnosticPass = true;
                    Console.WriteLine("[{0}/{1}] HSPI_DIAG_PAYLOAD_PASS，前 {2} 字节与发送数据一致。",
                        iteration + 1, iterations, compareLength);
                }

                totalBytes += transferSize * (readOnly ? 1L : 2L);
                Console.WriteLine(
                    readOnly
                        ? "[{0}/{1}] READ_ONLY_PASS，读 {2} 字节并与上一笔测试向量一致，{3:F2} ms"
                        : "[{0}/{1}] PASS，写 {2} + 读 {2} 字节，{3:F2} ms",
                    iteration + 1, iterations, transferSize, timer.Elapsed.TotalMilliseconds);
            }

            totalTimer.Stop();
            double mibPerSecond = totalBytes / 1048576.0 / totalTimer.Elapsed.TotalSeconds;
            if (writeOnly)
                Console.WriteLine("只写诊断完成；再次执行回环前请短按 USB_RST。平均写入吞吐 {0:F2} MiB/s", mibPerSecond);
            else if (streamMode)
                Console.WriteLine("USB3_FUSED_POINT_STREAM_PASS：{0} 个数据块全部通过，平均读取吞吐 {1:F2} MiB/s",
                    iterations, mibPerSecond);
            else if (readOnly)
                Console.WriteLine("USB_EP1_READ_PASS：{0} 次只读校验全部通过，平均读取吞吐 {1:F2} MiB/s",
                    iterations, mibPerSecond);
            else if (sawDiagnosticPass)
                Console.WriteLine("HSPI_DIAG_PASS：{0} 次诊断回环通过。", iterations);
            else
                Console.WriteLine("USB3_LOOPBACK_PASS：{0} 次全部通过，平均双向吞吐 {1:F2} MiB/s",
                    iterations, mibPerSecond);
            return 0;
        }
        finally
        {
            CH375CloseDevice(DeviceIndex);
        }
    }

    private static bool ValidateFusedPointStreamBlock(
        byte[] data, int expectedSequence, out int receivedSequence)
    {
        receivedSequence = -1;
        const int payloadLength = 48;
        const int frameLength = 13 + payloadLength;
        const int framesPerBlock = 67;
        int firstSequence = -1;
        uint firstImageId = 0;
        uint lastImageId = 0;
        ushort firstPointId = 0;
        ushort lastPointId = 0;

        if (data.Length != DefaultTransferSize)
        {
            Console.Error.WriteLine("USB3_STREAM_FAIL：数据块长度不是4096字节。");
            return false;
        }

        for (int frameIndex = 0; frameIndex < framesPerBlock; frameIndex++)
        {
            int offset = frameIndex * frameLength;
            if (data[offset] != 0xA5 || data[offset + 1] != 0x5A ||
                data[offset + 2] != 0x01 || data[offset + 3] != 0x00 ||
                data[offset + 4] != 0x01 || data[offset + 5] != 0x62 ||
                data[offset + 6] != 0x40 || data[offset + 9] != payloadLength ||
                data[offset + 10] != 0x00)
            {
                Console.Error.WriteLine(
                    "USB3_STREAM_FAIL：块内第 {0}/67 帧的帧头或类型错误，偏移0x{1:X4}。",
                    frameIndex + 1, offset);
                return false;
            }

            int sequence = data[offset + 7] | (data[offset + 8] << 8);
            if (frameIndex == 0)
                firstSequence = sequence;
            if (expectedSequence >= 0 && sequence != (expectedSequence & 0xFFFF))
            {
                Console.Error.WriteLine(
                    "USB3_STREAM_FAIL：块内第 {0}/67 帧期望序号 {1}，收到 {2}。",
                    frameIndex + 1, expectedSequence & 0xFFFF, sequence);
                return false;
            }

            ushort crc = 0xFFFF;
            for (int i = 2; i < 11 + payloadLength; i++)
                crc = Crc16CcittFalse(crc, data[offset + i]);
            int receivedCrc = data[offset + 11 + payloadLength] |
                              (data[offset + 12 + payloadLength] << 8);
            if (receivedCrc != crc)
            {
                Console.Error.WriteLine(
                    "USB3_STREAM_FAIL：块内第 {0}/67 帧CRC16期望0x{1:X4}，收到0x{2:X4}。",
                    frameIndex + 1, crc, receivedCrc);
                return false;
            }

            uint imageId = BitConverter.ToUInt32(data, offset + 19);
            ushort pointId = BitConverter.ToUInt16(data, offset + 25);
            if (frameIndex == 0)
            {
                firstImageId = imageId;
                firstPointId = pointId;
            }
            lastImageId = imageId;
            lastPointId = pointId;
            receivedSequence = sequence;
            expectedSequence = (sequence + 1) & 0xFFFF;
        }

        for (int i = framesPerBlock * frameLength; i < data.Length; i++)
        {
            if (data[i] != 0)
            {
                Console.Error.WriteLine("USB3_STREAM_FAIL：补零区偏移0x{0:X4}为0x{1:X2}。",
                    i, data[i]);
                return false;
            }
        }

        Console.WriteLine(
            "FUSED_POINT_BATCH frames=67 sequence={0}..{1} image_id=0x{2:X8}..0x{3:X8} point_id={4}..{5}",
            firstSequence, receivedSequence, firstImageId, lastImageId,
            firstPointId, lastPointId);
        return true;
    }

    private static ushort Crc16CcittFalse(ushort crc, byte data)
    {
        crc ^= (ushort)(data << 8);
        for (int bit = 0; bit < 8; bit++)
            crc = (ushort)(((crc & 0x8000) != 0) ? ((crc << 1) ^ 0x1021) : (crc << 1));
        return crc;
    }

    private static bool PrintHspiDiagnosticFooter(byte[] data)
    {
        const int offset = 4080;
        if (data.Length < offset + 16 ||
            data[offset] != (byte)'H' || data[offset + 1] != (byte)'S' ||
            data[offset + 2] != (byte)'P' || data[offset + 3] != (byte)'I')
            return false;

        int status = data[offset + 4];
        int flags = data[offset + 5];
        int rxSequence = data[offset + 6] & 0x0F;
        int txSequence = data[offset + 7] & 0x0F;
        int rxLength = data[offset + 8] | (data[offset + 9] << 8);
        int stage = data[offset + 10];
        uint udf = (uint)(data[offset + 12] |
            (data[offset + 13] << 8) |
            (data[offset + 14] << 16) |
            (data[offset + 15] << 24));

        Console.WriteLine(
            "HSPI_DIAG status=0x{0:X2} ({1}{2}) int_flags=0x{3:X2} rx_seq={4} tx_seq={5} rx_len={6} stage=0x{7:X2} udf=0x{8:X8}",
            status,
            (status & 0x02) != 0 ? "CRC_ERR " : "",
            (status & 0x04) != 0 ? "NUM_MIS" : "OK",
            flags, rxSequence, txSequence, rxLength, stage, udf);
        return true;
    }

    private static int Usage(string error)
    {
        Console.Error.WriteLine(error);
        Console.Error.WriteLine(
            "用法: Usb3LoopbackTest.exe [循环次数] [--api standard|endpoint] " +
            "[--size 1024|4096] [--write-only|--read-only|--stream]");
        return 2;
    }

    private static void PrintCandidateDllInfo()
    {
        string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "CH375DLL.dll");
        if (!File.Exists(path))
            return;

        FileVersionInfo version = FileVersionInfo.GetVersionInfo(path);
        Console.WriteLine("候选 DLL：{0}", path);
        Console.WriteLine("候选 DLL 版本：{0}", version.FileVersion ?? "未知");
    }

    private static void PrintLoadedDllInfo()
    {
        try
        {
            IntPtr module = GetModuleHandle("CH375DLL.dll");
            if (module == IntPtr.Zero)
            {
                Console.WriteLine("警告：CH375DLL.dll 已调用，但无法取得模块句柄。");
                return;
            }

            var path = new StringBuilder(1024);
            if (GetModuleFileName(module, path, path.Capacity) == 0)
            {
                Console.WriteLine("警告：无法取得 CH375DLL.dll 的实际加载路径。");
                return;
            }

            FileVersionInfo version = FileVersionInfo.GetVersionInfo(path.ToString());
            Console.WriteLine("实际加载 DLL：{0}", path);
            Console.WriteLine("实际加载 DLL 版本：{0}", version.FileVersion ?? "未知");
        }
        catch (Exception exception)
        {
            Console.WriteLine("警告：无法读取实际 DLL 信息：{0}", exception.Message);
        }
    }
}

# FPGA data

`ch4_hitran_5000ppm.mem` 是从用户已验证的 DILA 工程导入的 12800 点、16 位波形，详细物理参数和源文件 SHA-256 见同名 JSON。数据来自 HITRANonline/HAPI，5000 ppm、296 K、1 atm、1 m 光程，25.6 MSPS、2 kHz 扫描、200 kHz 调制。

使用 `Tools/spectroscopy/import_verified_waveform.py` 可以从旧工程重新核验和导入；脚本只读取旧工程，所有输出留在本项目目录。

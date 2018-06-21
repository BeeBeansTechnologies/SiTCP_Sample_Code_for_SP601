Read this in other languages: [English](README.md), [日本語](README.ja.md)

# SiTCP Sample Code for SP601

This is the SiTCP sample source code for SP601 communication confirmation.

In this code use the module that converts the interface of AT93C46, used by SiTCP, to EEPROM (M24C08) of SP601.

For the parameter SYSCLK_FREQ_IN_MHz, please input the clock frequency as an integer in MHz.


## What is SiTCP

Simple TCP/IP implemented on an FPGA (Field Programmable Gate Array) for the purpose of transferring large amounts of data in physics experiments.

* For details, please refer to [SiTCP Library page](https://www.bbtech.co.jp/en/products/sitcp-library/).
* For other related projects, please refer to [here](https://github.com/BeeBeansTechnologies).

![SiTCP](sitcp.png)

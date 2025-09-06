# Alpha Video Player with Metal4

A sample iOS/macOS application demonstrating **alpha-enabled video playback** using **Metal4**.  
This project is designed as a lightweight reference for developers who want to explore video rendering with YCbCr + Alpha planes on Apple platforms.

This sample project was showcased in the KWDC25 presentation.
https://speakerdeck.com/rei315/no-shaders-no-worries-lets-talk-about-metal-render-pipeline

## Development Environment

- macOS 26 Beta

## Test Environment

- iPadOS 26 Beta  
- macOS 26 Beta  



## ⚠️ Notes

This application was developed and tested on **Beta 26 environments**.  
Depending on your macOS/iOS version, **the behavior may vary or not work properly**.



## Application Overview

- Alpha-enabled video playback  
- Powered by **Metal4** for GPU-accelerated rendering  
- Demonstrates **YCbCr + Alpha plane composition**  



## Limitations of This Sample Project

This project is intended as a **sample project**. Therefore, the following are **not included**:

- Refactoring  
- Full-featured pipeline (only the minimal configuration required to demonstrate the concept is implemented)  
- General video playback support  



## Getting Started

```bash
# Clone the repository
git clone https://github.com/rei315/KWDC25MetalPlayground.git
cd KWDC25MetalPlayground

# Open in Xcode (requires Xcode 26+ on macOS 26 Beta)
xed .

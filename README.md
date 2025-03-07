# TwapsClient

A macOS app for loading and displaying Twaps (The Web for Apps).

## Overview

TwapsClient is part of the Twaps ecosystem, which brings web-like dynamics to native macOS applications. This client component is responsible for:

- Loading Twaps from a TwapsServer
- Compiling Twaps into dynamic libraries
- Displaying Twaps in a native macOS interface

## 🧪 Experimental Project

**Note:** This is an experimental project created to explore the concept of dynamic native UI modules. It is not intended for production use at this stage. The code is shared to inspire discussion and collaboration around the idea of bringing web-like dynamics to native app development.

## Features

- Simple URL-based Twap loading
- Dynamic compilation of Twaps
- Native SwiftUI interface

## Getting Started

### Prerequisites

- macOS 13.0+ (Ventura or later)
- Swift 6.0+
- Xcode 15.0+

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Noah-Moller/TwapsClient.git
   cd TwapsClient
   ```

2. Open the project in Xcode:
   ```bash
   open TwapsClient.xcodeproj
   ```

3. Build and run the app.

## Usage

1. Start the TwapsServer:
   ```bash
   cd /path/to/TwapsServer
   swift run
   ```

2. Push a Twap to the server:
   ```bash
   cd /path/to/TwapsCLI
   swift run TwapsCLI push Examples/SimpleTwap.swift --url simple.twap
   ```

3. Open the TwapsClient app and enter the URL of your Twap (e.g., `simple.twap`).

4. Click "Go" to load and display the Twap.

## Related Projects

- [TwapsCLI](https://github.com/Noah-Moller/TwapsCLI): A command-line tool for building and publishing Twaps
- [TwapsServer](https://github.com/Noah-Moller/TwapsServer): A simple server for hosting and distributing Twaps

## License

This project is licensed under the MIT License - see the LICENSE file for details.

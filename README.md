
# MLCChat iOS

MLCChat iOS is a native iOS application that demonstrates the capabilities of machine learning compilation using [Apache TVM](https://tvm.apache.org/) and [MLC-AI](https://mlc.ai/). This application showcases how to efficiently run large language models on iOS devices using the power of machine learning compilation.

## Overview

This application is built on top of the MLC-AI iOS infrastructure, providing a chatbot interface that can run language models directly on your iOS device. It leverages the machine learning compilation techniques from Apache TVM and MLC-AI to optimize model performance for mobile devices.

## In-App Footage

### History

<img src="https://github.com/user-attachments/assets/e486973f-9464-4f7e-b561-410301a192cc" width="350" height="800">

### Model Selection

<img src="https://github.com/user-attachments/assets/447d8c87-63f9-46f8-bc03-8226ca8f3176" width="350" height="800">

### R1 Think

<img src="https://github.com/user-attachments/assets/031a8ea4-6f08-44e7-8468-71c49a2c9342" width="350" height="800">

### Video


https://github.com/user-attachments/assets/43ca95f2-58a6-4739-bf0f-399a737f2f27



## Features

- Native iOS SwiftUI implementation
- Efficient on-device language model inference
- Support for various chat models
- Image processing capabilities
- Chat history management
- Model selection interface
- Optimized performance using MLC-AI compilation

## Technical Stack

- SwiftUI for the user interface
- MLC-LLM for model deployment and inference
- Apache TVM for machine learning compilation
- Native iOS frameworks for image processing
- Local storage for chat history

## Dependencies

The project relies on several key technologies:

- [Apache TVM](https://tvm.apache.org/) - A deep learning compiler framework
- [MLC-AI](https://mlc.ai/) - Machine Learning Compilation framework
- iOS 15.0+
- Swift 5.0+
- Xcode 14.0+

## Building from Source

1. Clone the repository
2. Install the required dependencies
3. Configure the MLC package using `mlc-package-config.json`
4. Build the project using Xcode

For more details check [mlc-ai iOS app page](https://llm.mlc.ai/docs/deploy/ios.html) website.

## Project Structure

```
MLCChat/
├── Models/         # Data models and configurations
├── States/         # Application state management
├── Views/          # SwiftUI views
└── Common/         # Shared utilities and constants
```

## Contributing

Contributions are welcome! Please feel free to submit pull requests.

## License

Apache 2.0

## Acknowledgments

- [Apache TVM Project](https://tvm.apache.org/)
- [MLC-AI Project](https://mlc.ai/)
- All contributors to the MLCChat iOS project


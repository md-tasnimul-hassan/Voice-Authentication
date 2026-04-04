# Voice Biometrics Authentication System 🎙️🔐

![MATLAB](https://img.shields.io/badge/MATLAB-R2021a%2B-blue.svg)
![DSP](https://img.shields.io/badge/Domain-Digital_Signal_Processing-orange.svg)
![ML](https://img.shields.io/badge/Machine_Learning-K--Means-green.svg)
![Institution](https://img.shields.io/badge/Institution-BUET-red.svg)

A robust, text-dependent voice authentication system built in MATLAB. This project captures raw audio, extracts acoustic features using Mel-Frequency Cepstral Coefficients (MFCC), and authenticates users via Vector Quantization (VQ) using the K-Means clustering algorithm.

Includes both a lightweight Command Line Interface (CLI) and a fully featured Object-Oriented Graphical User Interface (GUI).

## 🚀 Features
* **Live Audio Processing:** Record audio directly within the app or load existing `.wav` files.
* **DSP Pipeline:** Automated DC offset removal, pre-emphasis filtering, amplitude normalization, and dynamic silence truncation.
* **Feature Extraction:** Extracts 13-dimensional MFCCs using Hamming windows to model the human vocal tract.
* **Machine Learning Model:** Utilizes K-Means clustering to generate 16-centroid Vector Quantization codebooks per user, reducing data footprint while retaining unique vocal characteristics.
* **Interactive GUI:** Built with MATLAB App Designer, featuring real-time waveform plotting and MFCC visual analysis (spectrogram-style heatmaps).

## 📸 Screenshots
![Enrollment Tab](assets/Screenshot%202026-04-02%20071324.png)
![Verification Tab](assets/Screenshot%202026-04-02%20064348.png)

## 🧠 How It Works (The Pipeline)
1. **Pre-processing:** Raw audio is converted to mono. A high-pass filter (`[1 -0.97]`) is applied to amplify high frequencies (pre-emphasis). Silence at the beginning and end of the audio is removed.
2. **Feature Extraction:** The audio is divided into 25ms overlapping frames. FFT and Mel-filter banks are applied to extract 13 MFCCs per frame.
3. **Enrollment (Training):** The MFCC vectors are clustered into 16 groups using K-Means. The cluster centers (centroids) form the user's "Codebook".
4. **Verification (Testing):** The MFCCs of a login attempt are compared against saved Codebooks using Euclidean Distance (`pdist2`). If the average minimum distortion falls below a tuned threshold (1.5), access is granted.

## 🛠️ Installation & Usage

### Prerequisites
* MATLAB (R2021a or newer recommended)
* Audio Toolbox
* Signal Processing Toolbox
* Statistics and Machine Learning Toolbox

### Running the GUI App
1. Clone the repository:
   ```bash
   git clone https://github.com/YourUsername/Voice-Authentication-System.git

# Mentora AI

Mentora AI is a personalized AI-powered tutoring app that adapts to students' unique learning styles. It provides features like quiz generation, summaries, flashcards, and interactive NLP-based conversations to help learners stay on track with their goals.

## 🚀 Tech Stack

- **Programming Language:** Dart  
- **Framework:** Flutter  
- **Backend Services:** Firebase  
  - Firebase Authentication  
  - Cloud Firestore  
  - Firebase Storage

## ✨ Features

- **OTP-based Email Signup and Authentication** using Firebase
- **Multi-step Onboarding Flow** (name, birthdate, learning goals, subjects)
- **Personalized AI Tutor Chat** powered by NLP for interactive learning
- **AI-generated Quizzes, Flashcards, and Summaries** from uploaded syllabus
- **Progress Tracking Dashboard** with Firestore integration
- **User Profile and Data Management** stored securely in Firebase

## 🛠 Getting Started

Follow these steps to set up and run the Mentora AI app on your local machine.

### Prerequisites

- Android Studio (or any Flutter-supported IDE)
- Flutter SDK installed
- A Firebase project set up and configured

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/mentora-ai.git
   cd mentora-ai
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Add your `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) into the respective platform directories.
   - Ensure Firebase Authentication, Firestore, and Storage are enabled.

4. **Run the app**
   ```bash
   flutter run
   ```

Mentora AI supports both Android and iOS devices.

## 🎨 UI/UX Prototype

Explore the full UI design and user flow on Figma:

👉 [View Figma Prototype]([https://www.figma.com/file/your-prototype-link](https://www.figma.com/proto/EsZvsWHpQHqUQ6cniGOp6G/MentoraAI?node-id=4-4&p=f&t=5jClZRhocnvqhzjz-1&scaling=scale-down&content-scaling=fixed&page-id=0%3A1&starting-point-node-id=4%3A4))

## 📌 Project Status

This project is currently under development. The core features are implemented using Flutter and Firebase.

## 🚧 Future Plans

- Integration with **OpenAI's GPT-4 API** for advanced tutoring interactions
- Add **leaderboards** for gamified learning
- Implement **multilingual support** for broader accessibility
- Support for **multiple AI models** for task-specific performance

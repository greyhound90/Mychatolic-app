# MyCatholic App - Developer Notes

**Date:** December 20, 2025
**Version:** 1.0 (MVP)

## 1. Project Status
The application is **Feature Complete** according to the Software Design Document (SDD).

### Completed Modules:
- **Authentication**: 
  - Complete Login & Registration flow using `Supabase Auth`.
  - Automatic profile creation via Database Triggers.
- **Trust System (Verification)**:
  - `UploadDocumentPage`: Uploads baptism/chrism certificates to `verification_docs` storage.
  - Profile Sync: Updates `verification_doc_url` and sets status to `pending`.
- **Tele-Ministry (Consilium)**:
  - Real-time chat interface connecting Umat and Partners.
  - Implements `consilium_requests` (session management) and `consilium_messages` (real-time chat).
- **Partner Mode (Mitra Pastoral)**:
  - `PartnerRegistrationPage`: Allows user to apply as Imam/Religious.
  - Updates profile role to `mitra_pending` for Admin review.
- **UI/UX Refactor**:
  - Implemented **Telegram-Inspired Design** (Blue `#0088CC`).
  - Native **Dark Mode** support.

## 2. Tech Stack Details
- **Framework**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL, Auth, Storage, Realtime)
- **Key Packages**:
  - `supabase_flutter`: Core backend integration.
  - `google_fonts`: Typography (Outfit font).
  - `image_picker`: Camera/Gallery access.
  - `timeago`: Date formatting.
- **Navigation Logic**:
  - Uses `Navigator.push` / `MaterialPageRoute` for stack navigation.
  - `HomePage` serves as the main tab controller (IndexedStack).
  - `SplashPage` handles initial auth state checking.

## 3. Folder Structure Overview
The project follows a feature-based organization inside `lib/`:

- **lib/**
  - **core/**: Core utilities.
    - `theme.dart`: Application Theme (Light/Dark defs).
  - **pages/**: UI Screens.
    - `consilium/`: Tele-ministry specific pages (`chat_screen.dart`, `consilium_page.dart`).
    - `activity/`: Notification/Activity feeds.
    - `login_page.dart`, `register_page.dart`: Auth screens.
    - `profile_page.dart`: User profile & settings entry.
    - `verification_page.dart` & `partner_registration_page.dart`: Onboarding flows.
  - **main.dart**: Entry point & App Configuration.

## 4. Manual Testing Guide
Follow this checklist to verify the core flows:

### A. Authentication
1.  **Register**: Create a new account. Verify you land on `HomePage`.
2.  **Database**: Check Supabase `profiles` table to see the new record.

### B. User Verification (Trust System)
1.  **Navigate**: Profile -> "Verifikasi Akun".
2.  **Action**: Upload a dummy image for "Surat Baptis".
3.  **Result**: 
    - UI shows Success Dialog.
    - Profile badge updates to "MENUNGGU VERIFIKASI".
    - Database `profiles` row has `verification_doc_url` filled and `verification_status` = 'pending'.

### C. Consilium (Chat)
1.  **Navigate**: Tab "Consilium" (Handshake Icon) -> "Ajukan Permintaan".
2.  **Action**: Select "Pastor", enter topic "Tes Konseling".
3.  **Chat**: Open the created session card. Type a message.
4.  **Result**: Message appears immediately (StreamBuilder). Database `consilium_messages` has the record.

### D. Partner Registration
1.  **Navigate**: Profile -> "Daftar sebagai Mitra Pastoral" (Bottom link).
2.  **Action**: Select "Imam", upload dummy Celebret.
3.  **Result**: 
    - Success Dialog.
    - Database `profiles.role` updates to `mitra_pending`.

---
*End of Notes*

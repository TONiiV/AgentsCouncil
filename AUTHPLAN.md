# Authentication & User Management Plan

## 1. Architecture Strategy: Supabase-Centric
We will adopt a **Supabase-Centric** architecture where the Flutter frontend communicates directly with Supabase for authentication and data persistence. The FastAPI backend will remain focused on AI orchestration.

*   **Frontend (Flutter):** Handles direct authentication (Auth), data reading/writing (PostgREST), and real-time subscriptions.
*   **Backend (FastAPI):** Receives the user's Supabase JWT in request headers to verify identity when performing server-side AI operations.
*   **Supabase:** Acts as the source of truth for Users, Auth, and Debate storage.

## 2. Authentication Flow

### Providers
*   **Google & GitHub:** Enabled via Supabase Auth.
*   **Method:** Native OAuth flows where possible (using `google_sign_in` etc. alongside `supabase_flutter`), with a fallback to `signInWithOAuth` (Webview/CustomTabs) for deep-link based authentication on platforms where native SDKs are not preferred or available.

### User Experience
1.  **Login Screen:** A dedicated route (`/login`) presented on app launch if no valid session exists.
    *   UI: "Sign in with Google" and "Sign in with GitHub" buttons.
    *   State: Loading indicators during OAuth redirects.
    *   Error Handling: Toast/Snackbar notifications for failed sign-ins or network issues.
2.  **Session Management:**
    *   Use `supabase_flutter` for automatic session persistence and token refreshing.
    *   App wrapper listens to `Supabase.instance.client.auth.onAuthStateChange` to redirect between Login and Home screens dynamically.
3.  **Guest Access:** (To be determined - blocking by default until decided otherwise).

## 3. Data Modeling

### Storage Approach: Single Record
To simplify the initial iteration, we will store debate contexts and council configurations in a **Single Record** format.

*   **Table:** `debates`
*   **Columns:**
    *   `id`: UUID (Primary Key)
    *   `user_id`: UUID (Foreign Key to `auth.users`)
    *   `title`: String (Debate topic)
    *   `created_at`: Timestamp
    *   `updated_at`: Timestamp
    *   `content`: JSONB (Contains the full debate history, council setup, agents involved, and current state)

This schema allows flexible evolution of the debate structure without constant migration of relational tables.

## 4. Implementation Steps

### Phase 1: Supabase Setup
1.  Create a new Supabase Project.
2.  Configure Auth Providers (Google, GitHub) with Client IDs/Secrets.
3.  Set up the `debates` table with Row Level Security (RLS) policies:
    *   `SELECT`: Users can see their own debates.
    *   `INSERT/UPDATE`: Users can create/edit their own debates.

### Phase 2: Flutter Integration
1.  Add dependencies: `supabase_flutter`, `flutter_dotenv` (if needed for runtime config), and deep linking configuration (`app_links`).
2.  Initialize Supabase client in `main.dart`.
3.  Implement `AuthService` to handle sign-in, sign-out, and session retrieval.
4.  Build `LoginScreen` UI.
5.  Implement `AuthGuard` or `RootWidget` to handle routing based on auth state.

### Phase 4: Delivery & Verification
1.  **Run Tests:** Execute all project tests to ensure stability (`flutter test`, `pytest`).
2.  **Create PR:** Create a Pull Request with the implementation changes.
3.  **Check PR:** Verify the PR status and CI checks using GitHub tools.

## 5. Success Criteria (Definition of Done)

### Functional Requirements
*   [ ] **Authentication:**
    *   User can sign in with Google on macOS and Mobile.
    *   User can sign in with GitHub on macOS and Mobile.
    *   User session persists across app restarts.
    *   User can sign out.
*   [ ] **User Interface:**
    *   Dedicated Login Screen matches the app's visual style.
    *   Auth state changes automatically redirect the user (Login <-> Home).
    *   Error messages are displayed for failed login attempts.
*   [ ] **Data Persistence:**
    *   User can create a new debate, and it is saved to Supabase.
    *   User can view a list of their saved debates.
    *   Data is securely isolated (User A cannot see User B's debates).
*   [ ] **Code Quality:**
    *   Flutter code uses a clear service pattern for Auth and Database interactions.
    *   No hardcoded API keys in the repository (use environment variables/config).
    *   Project builds and runs without errors on macOS.
*   [ ] **Delivery:**
    *   All tests pass (`flutter test`, `pytest`).
    *   Pull Request created and checked.

### Verification Steps
1.  **Automated Tests:** Run `flutter test` and `pytest` to confirm functionality and no regressions.
2.  **PR Check:** Create the PR using `gh pr create` and verify it using the GitHub MCP tool.


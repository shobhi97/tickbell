/// Set once in `main()` after attempting `Firebase.initializeApp()`. Every
/// other push-related call site checks this first and no-ops if false, so
/// the app runs fine — auth, groups, chat, and the realtime bell all work
/// — even with zero Firebase project set up yet.
bool firebasePushAvailable = false;

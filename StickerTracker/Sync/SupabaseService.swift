import Foundation
import Supabase

/// Shared Supabase client. Both values below are public by design: they ship
/// in the app binary, and the anon key grants nothing on its own — all access
/// control lives in RLS policies and RPCs on the server.
enum SupabaseService {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://fitqxamruuehpxupuvwy.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZpdHF4YW1ydXVlaHB4dXB1dnd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1MjE1NjksImV4cCI6MjA5OTA5NzU2OX0.558H_d5rnpPNM5QLt62JCbUGoyiJnZbZsQsL1NbcDfo"
    )
}

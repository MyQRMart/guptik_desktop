/// Public (non-secret) identifiers of the GupTik account backend. The anon key ships in every
/// app build; it is only used by node gateways to ask Supabase "is this user token valid?".
/// Nodes never hold a signing secret.
const String kAccountSupabaseUrl = 'https://aqmcriergkczfkkdgkzc.supabase.co';
const String kAccountSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFxbWNyaWVyZ2tjemZra2Rna3pjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1MzU1NTUsImV4cCI6MjA5ODExMTU1NX0.GTFeWOWlfPBpQabdhwNhR0TGFg3oLzf4AOGkBbs2lP0';
const String kAccountGuptikUrl = 'https://guptik.com';
